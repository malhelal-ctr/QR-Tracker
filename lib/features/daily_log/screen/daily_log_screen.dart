import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../scan/screen/scan_code_page.dart';
import '../../scan/widget/scan_log_dialog.dart';
import '../../work_calendar/screen/work_calendar_screen.dart';
import '../cubit/daily_log_cubit.dart';
import '../model/daily_log_state.dart';
import '../widget/log_entry_panel.dart';
import '../widget/machine_reading_sheet.dart';
import '../widget/machine_table.dart';
import '../widget/month_bar.dart';
import '../widget/month_calendar.dart';
import '../widget/month_header.dart';
import '../widget/month_table.dart';
import '../widget/month_target_dialog.dart';

/// Daily log by month: the month's plan and every day in it fill the screen; a day is logged or edited
/// in a bottom sheet.
class DailyLogScreen extends StatelessWidget {
  const DailyLogScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (context) => DailyLogCubit(context.read<TrackerRepository>()), child: const _DailyLogView());
}

class _DailyLogView extends StatefulWidget {
  const _DailyLogView();

  @override
  State<_DailyLogView> createState() => _DailyLogViewState();
}

class _DailyLogViewState extends State<_DailyLogView> {
  DailyLogCubit get _cubit => context.read<DailyLogCubit>();

  /// " · lids left 8,000, run out Mon, Nov 16" when lid stock is tracked.
  String _lidNote() {
    final stock = context.read<TrackerRepository>().stock;
    final f = stock.forecast;
    if (!stock.hasData || f == null) return '';
    if (f.onHand <= 0) return ' · out of lids';
    return ' · lids left ${fmt(f.onHand)}${f.runOut == null ? '' : ', run out ${fmtDate(f.runOut!)}'}${f.needsOrder ? ' (order now)' : ''}';
  }

  /// The open sheet is a machine reading, not the day's log.
  bool _machineSheet = false;

  /// Opens [date] in a bottom sheet (closed again when dismissed): the day's log, or with [machine] the
  /// machine reading. With a sheet already open it just switches to [date].
  Future<void> _open(String date, {bool machine = false}) async {
    final wasOpen = _cubit.state.selected != null;
    _cubit.open(date);
    if (wasOpen) return;
    _machineSheet = machine;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: 640.r),
      builder: (_) => BlocProvider.value(
        value: _cubit,
        child: BlocBuilder<DailyLogCubit, DailyLogState>(
          builder: (sheetContext, state) => state.selected == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16.r, 0, 16.r, 24.r),
                    child: _machineSheet
                        ? _readingSheet(state, onClose: () => Navigator.pop(sheetContext))
                        : _panel(state, onClose: () => Navigator.pop(sheetContext)),
                  ),
                ),
        ),
      ),
    );
    if (mounted) _cubit.closePanel();
  }

  /// "Log day": yesterday's log (the morning log), or today once yesterday is logged.
  void _logDay() {
    final yesterday = DailyLogCubit.defaultDate;
    final logged = _cubit.entryFor(yesterday).log?.counter != null;
    _open(logged ? ymd(DateTime.now()) : yesterday);
  }

  Widget _readingSheet(DailyLogState state, {required VoidCallback onClose}) {
    final date = state.selected!;
    final entry = _cubit.entryFor(date);
    return MachineReadingSheet(
      key: ValueKey('$date|${entry.log?.total}|${entry.log?.totalReset}'),
      entry: entry,
      onClose: onClose,
      onDate: _cubit.open,
      onSave: (total, reset) async {
        await _cubit.saveMachineReading(date, total, reset);
        if (!mounted) return;
        showSnack(context, total == null ? '${fmtDay(date)} reading deleted' : '${fmtDay(date)} machine total ${fmt(total)} saved${reset ? ' (reset)' : ''}');
        onClose();
      },
    );
  }

  Widget _panel(DailyLogState state, {required VoidCallback onClose}) {
    final date = state.selected!;
    final entry = _cubit.entryFor(date);
    final log = entry.log;
    return LogEntryPanel(
      // a scan log or a save from elsewhere refills the fields
      key: ValueKey('$date|${log?.id}|${log?.counter}|${log?.total}'),
      entry: entry,
      products: state.products,
      onClose: onClose,
      onDate: _cubit.open,
      onOffChanged: (off) => _cubit.setDayOff(date, off),
      onScan: () => _logByScan(DateTime.parse(date)),
      onSave: (input) async {
        await _cubit.saveLog(
          date: date,
          counter: input.counter,
          total: input.total,
          totalReset: input.totalReset,
          target: input.target,
          note: input.note,
          product: input.product,
        );
        if (!mounted) return;
        showSnack(context, '${fmtDay(date)} saved${_lidNote()}');
        onClose();
      },
      onDelete: () async {
        await _cubit.deleteLog(date);
        if (!mounted) return;
        showSnack(context, '${fmtDay(date)} log deleted');
        onClose();
      },
    );
  }

  /// Log by scan: scan the code being printed, check / edit the counter in the popup, then confirm or cancel.
  /// "Scan again" in the popup goes back to the scanner. The day then opens in the panel for the machine total.
  Future<void> _logByScan(DateTime date) async {
    final cubit = _cubit;
    while (true) {
      if (!mounted) return;
      final code = await ScanCodePage.open(
        context,
        title: 'Log by scan',
        hint: 'Scan the code the machine is printing now. The counter for ${fmtDate(date)} is worked out from it.',
      );
      if (code == null || !mounted) return;
      final choice = await showScanLogDialog(context, cubit.draftFromScan(code, date), draftFor: (d) => cubit.draftFromScan(code, d));
      if (!mounted) return;
      switch (choice) {
        case ScanLogConfirm(:final draft, :final counter):
          await cubit.saveScanLog(draft, counter);
          if (!mounted) return;
          showSnack(context, '${fmtDate(draft.date)} logged: ${fmt(counter)} printed');
          // open the day so the machine total can be added
          _open(ymd(draft.date));
          return;
        case ScanLogRescan():
          continue;
        case null:
          return;
      }
    }
  }

  Future<void> _editTarget(DailyLogState state) async {
    final plan = await showMonthTargetDialog(context, summary: state.summary);
    if (plan == null || !mounted) return;
    if (plan.openSettings) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WorkCalendarScreen()));
      return;
    }
    await _cubit.setMonthTarget(plan.dailyTarget);
    if (mounted) showSnack(context, 'Plan for ${fmtMonth(state.month)} saved');
  }

  Future<void> _toggleOff(String date, bool off) async {
    await _cubit.setDayOff(date, off);
    if (mounted) showSnack(context, '${fmtDay(date)} ${off ? 'marked as a day off' : 'is a working day'}');
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<DailyLogCubit, DailyLogState>(
        builder: (context, state) {
          final pad = isTablet ? 24.r : 16.r;
          return Scaffold(
            appBar: const TrackerAppBar('Daily log'),
            body: ListView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 112.r),
              children: [
                MonthBar(
                  month: state.month,
                  view: state.view,
                  onPrevious: _cubit.previousMonth,
                  onNext: _cubit.nextMonth,
                  onPick: _cubit.showMonth,
                  onView: _cubit.setView,
                ),
                MonthHeader(summary: state.summary, ownTarget: state.ownTarget, onEditTarget: () => _editTarget(state)),
                switch (state.view) {
                  LogView.calendar => MonthCalendar(summary: state.summary, selected: state.selected, onTap: _open, onToggleOff: _toggleOff),
                  LogView.list => MonthTable(summary: state.summary, selected: state.selected, onTap: _open),
                  LogView.machine => MachineTable(summary: state.summary, selected: state.selected, onTap: (d) => _open(d, machine: true)),
                },
              ],
            ),
            floatingActionButton: state.view == LogView.machine
                ? FloatingActionButton.extended(
                    heroTag: 'log-reading',
                    backgroundColor: C.primaryContainer,
                    foregroundColor: Colors.white,
                    onPressed: () => _open(_cubit.defaultReadingDate, machine: true),
                    icon: const Icon(Icons.precision_manufacturing_outlined),
                    label: Text('LOG READING', style: sans(14, weight: FontWeight.w700, spacing: 0.6, color: Colors.white)),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.extended(
                heroTag: 'log-scan',
                backgroundColor: C.high,
                foregroundColor: C.onSurface,
                onPressed: () => _logByScan(DateTime.parse(DailyLogCubit.defaultDate)),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text('LOG BY SCAN', style: sans(14, weight: FontWeight.w700, spacing: 0.6)),
              ),
              SizedBox(width: 12.r),
              FloatingActionButton.extended(
                heroTag: 'log-day',
                backgroundColor: C.primaryContainer,
                foregroundColor: Colors.white,
                onPressed: _logDay,
                icon: const Icon(Icons.add),
                label: Text('LOG DAY', style: sans(14, weight: FontWeight.w700, spacing: 0.6, color: Colors.white)),
              ),
            ]),
          );
        },
      );
}
