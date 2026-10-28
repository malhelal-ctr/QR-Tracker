import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data/models.dart';
import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';
import '../../../core/widgets/history_header.dart';
import '../../../core/widgets/period_chips.dart';
import '../../../core/widgets/stepper_field.dart';
import '../cubit/daily_log_cubit.dart';
import '../model/daily_log_state.dart';
import '../widget/editing_banner.dart';
import '../widget/history_row.dart';
import '../widget/history_summary.dart';
import '../widget/log_tabs.dart';
import '../widget/printer_form.dart';
import '../widget/printer_row.dart';
import '../../scan/screen/scan_code_page.dart';
import '../../scan/widget/scan_log_dialog.dart';
import '../widget/suggestion_row.dart';

class DailyLogScreen extends StatelessWidget {
  const DailyLogScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(create: (context) => DailyLogCubit(context.read<TrackerRepository>()), child: const _DailyLogView());
}

/// Holds the text controllers; values come from and go to [DailyLogCubit].
class _DailyLogView extends StatefulWidget {
  const _DailyLogView();

  @override
  State<_DailyLogView> createState() => _DailyLogViewState();
}

class _DailyLogViewState extends State<_DailyLogView> {
  final _counter = TextEditingController();
  final _target = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fill(context.read<DailyLogCubit>().state);
  }

  @override
  void dispose() {
    _counter.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  void _fill(DailyLogState s) {
    _counter.text = s.counter?.toString() ?? '';
    _target.text = s.target?.toString() ?? '';
    _note.text = s.note;
  }

  Future<DateTime?> _pickDate(DateTime initial) =>
      showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));

  /// Marks the top of the form, to scroll back to it when a history entry is opened.
  final _formTop = GlobalKey();

  /// Loads a history entry into the form and brings the form into view (phones scroll up to it).
  void _editDay(Day day) {
    context.read<DailyLogCubit>().editDay(day);
    final top = _formTop.currentContext;
    if (top != null) Scrollable.ensureVisible(top, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  /// Log by scan: scan the code being printed, check / edit the counter in the popup, then confirm or cancel.
  /// "Scan again" in the popup goes back to the scanner.
  Future<void> _logByScan() async {
    final cubit = context.read<DailyLogCubit>();
    while (true) {
      if (!mounted) return;
      final code = await ScanCodePage.open(
        context,
        title: 'Log by scan',
        hint: 'Scan the code the machine is printing now. The counter for ${fmtDate(cubit.state.date)} is worked out from it.',
      );
      if (code == null || !mounted) return;
      final choice = await showScanLogDialog(context, cubit.draftFromScan(code, cubit.state.date), draftFor: (d) => cubit.draftFromScan(code, d));
      if (!mounted) return;
      switch (choice) {
        case ScanLogConfirm(:final draft, :final counter):
          await cubit.saveScanLog(draft, counter);
          if (mounted) showSnack(context, '${fmtDate(draft.date)} logged: ${fmt(counter)} printed');
          return;
        case ScanLogRescan():
          continue;
        case null:
          return;
      }
    }
  }

  Future<void> _save() async {
    final cubit = context.read<DailyLogCubit>();
    final editing = cubit.state.editing;
    await cubit.save(counter: _counter.text, target: _target.text, note: _note.text);
    if (mounted) {
      FocusScope.of(context).unfocus();
      showSnack(context, editing == null ? 'Daily log saved' : '${fmtDay(editing.date)} updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DailyLogCubit>();

    return BlocListener<DailyLogCubit, DailyLogState>(
      listenWhen: (a, b) => a.formVersion != b.formVersion,
      listener: (_, s) => _fill(s),
      child: Scaffold(
        appBar: const TrackerAppBar('Daily log'),
        body: BlocBuilder<DailyLogCubit, DailyLogState>(
          builder: (context, state) => Column(
            children: [
              _TabsBar(
                child: LogTabs(tab: state.tab, historyCount: state.history.length, onChanged: cubit.selectTab),
              ),
              Expanded(
                child: switch (state.tab) {
                  LogTab.log => _logTab(cubit, state),
                  LogTab.history => _historyTab(cubit, state),
                  LogTab.printer => _printerTab(cubit, state),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyRow(DailyLogCubit cubit, DailyLogState state, Day day) => HistoryRow(
    day: day,
    target: state.targetFor(day),
    selected: state.editing?.id == day.id,
    onTap: () => _editDay(day),
    confirmDelete: () => confirm(context, 'Delete this day?', fmtDay(day.date), 'Delete'),
    onDelete: () => cubit.deleteDay(day.id),
  );

  Widget _targetNote(List<Day> days) => days.any((d) => d.target != null)
      ? Padding(
          padding: EdgeInsets.only(top: 6.r),
          child: Text('Target* = set for that day only; others use the daily target. Tap a day to change it.', style: sans(13, color: C.onVariant)),
        )
      : const SizedBox.shrink();

  /// Log tab: the morning entry form, and the most recent days under it (beside it on a wide tablet).
  Widget _logTab(DailyLogCubit cubit, DailyLogState state) {
    final recent = state.recent;
    final more = state.history.length - recent.length;
    return TwoPane(
      stackGap: 24.r,
      left: [
        SizedBox(key: _formTop),
        if (state.editing case final e?) EditingBanner(date: e.date, onNewEntry: cubit.newEntry),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Machine counter',
                icon: Icons.precision_manufacturing_outlined,
                trailing: state.editing == null ? const Pill('MORNING LOG', kind: PillKind.success) : const Pill('EDITING', kind: PillKind.info),
              ),
              DateRow(
                label: 'Production day',
                date: state.date,
                onTap: () async {
                  final d = await _pickDate(state.date);
                  if (d != null) cubit.setDate(d);
                },
              ),
              SizedBox(height: 16.r),
              const FieldLabel('Counter reading (before reset)'),
              StepperField(controller: _counter, color: C.primary),
              SizedBox(height: 10.r),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18.r, color: C.onVariant),
                  SizedBox(width: 8.r),
                  Expanded(
                    child: Text('Codes printed that day, read from the machine counter before you reset it.', style: sans(14, color: C.onVariant)),
                  ),
                ],
              ),
              if (state.editing == null) ...[
                SizedBox(height: 12.r),
                BigButton(label: 'Log by scan', icon: Icons.qr_code_scanner, style: BigButtonStyle.tonal, height: 48.r, onPressed: _logByScan),
              ],
              SizedBox(height: 16.r),
              const FieldLabel('Note (optional)'),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'e.g. Line maintenance at 14:00'),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.editing?.date case final date?) ...[
                SectionTitle('Target for ${fmtDay(date)}', icon: Icons.track_changes),
                Text(
                  state.defaultTarget == null ? 'Leave empty if this day has no target.' : 'Leave empty to use the daily target (${fmt(state.defaultTarget)}).',
                  style: sans(14, color: C.onVariant),
                ),
              ] else ...[
                const SectionTitle(
                  'Daily target',
                  icon: Icons.track_changes,
                  trailing: Pill('EVERY DAY', kind: PillKind.success),
                ),
                Text(
                  'Used for every day. Change it only when the plan changes — a single day can get its own target from History.',
                  style: sans(14, color: C.onVariant),
                ),
              ],
              SizedBox(height: 16.r),
              FieldLabel(state.editing == null ? 'Codes per day' : 'Codes for this day'),
              StepperField(controller: _target, color: C.success),
              if (state.suggested case final suggested?) ...[
                SizedBox(height: 12.r),
                SuggestionRow(suggested: suggested, onUse: () => _target.text = '$suggested'),
              ],
            ],
          ),
        ),
        BigButton(label: state.editing == null ? 'Save daily log' : 'Save changes', icon: Icons.check_circle_outline, onPressed: _save),
      ],
      right: [
        HistoryHeader(count: recent.length, title: 'Past logs'),
        _targetNote(recent),
        SizedBox(height: 12.r),
        if (recent.isEmpty)
          Panel(
            child: Text('Nothing logged yet.', style: sans(15, color: C.onVariant)),
          ),
        for (final day in recent) _historyRow(cubit, state, day),
        if (more > 0)
          BigButton(
            label: 'See all in History',
            icon: Icons.history,
            trailing: Icons.arrow_forward,
            style: BigButtonStyle.tonal,
            height: 48.r,
            onPressed: () => cubit.selectTab(LogTab.history),
          ),
        SizedBox(height: 8.r),
      ],
    );
  }

  /// Printer tab: enter the printer's counter; the readings below show what each one printed.
  /// Each day's printed amount fills that day's Daily log counter.
  Widget _printerTab(DailyLogCubit cubit, DailyLogState state) {
    final steps = state.printer.reversed.toList();
    return TwoPane(
      stackGap: 24.r,
      left: [
        PrinterForm(last: state.printer.lastOrNull?.reading, onSave: cubit.savePrinterReading),
        SizedBox(height: 12.r),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18.r, color: C.onVariant),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(
              'Printed = this reading − the previous one. It fills the Daily log counter for the production day, so it doesn’t need typing there.',
              style: sans(13, color: C.onVariant),
            ),
          ),
        ]),
      ],
      right: [
        HistoryHeader(count: steps.length, title: 'Readings'),
        SizedBox(height: 12.r),
        if (steps.isEmpty) Panel(child: Text('No printer readings yet.', style: sans(15, color: C.onVariant))),
        for (final step in steps)
          PrinterRow(
            step: step,
            confirmDelete: () => confirm(context, 'Delete this reading?', '${fmtDay(step.reading.date)} · ${fmt(step.reading.value)}', 'Delete'),
            onDelete: () => cubit.deletePrinterReading(step.reading.id),
          ),
        SizedBox(height: 8.r),
      ],
    );
  }

  /// History tab: date filter and totals, then every logged day in the range.
  Widget _historyTab(DailyLogCubit cubit, DailyLogState state) {
    final days = state.filtered;
    return TwoPane(
      stackGap: 24.r,
      left: [
        PeriodChips(preset: state.preset, from: state.from, to: state.to, onPreset: cubit.selectPreset, onRange: cubit.selectRange),
        SizedBox(height: 16.r),
        HistorySummary(state: state),
      ],
      right: [
        HistoryHeader(count: days.length),
        _targetNote(days),
        SizedBox(height: 12.r),
        if (days.isEmpty)
          Panel(
            child: Text(
              state.history.isEmpty ? 'Nothing logged yet.' : 'Nothing logged from ${fmtDate(state.from)} to ${fmtDate(state.to)}.',
              style: sans(15, color: C.onVariant),
            ),
          ),
        for (final day in days) _historyRow(cubit, state, day),
        SizedBox(height: 8.r),
      ],
    );
  }
}

/// Keeps the tab switch above the scrolling content, lined up with the page gutters.
class _TabsBar extends StatelessWidget {
  const _TabsBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16.r, isTablet ? 24.r : 16.r, 16.r, 0),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600.r),
        child: child,
      ),
    ),
  );
}
