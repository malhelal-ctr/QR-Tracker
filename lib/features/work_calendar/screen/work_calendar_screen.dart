import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/data/tracker_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/adaptive_layout.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/date_row.dart';
import '../../../core/widgets/field_label.dart';

/// One holiday: consecutive dates with the same name, shown and deleted together.
typedef HolidayGroup = ({String name, String from, String to, List<String> dates});

/// Holidays grouped into runs of consecutive dates with the same name, earliest first.
List<HolidayGroup> groupHolidays(Map<String, String> holidays) {
  final dates = holidays.keys.toList()..sort();
  final groups = <HolidayGroup>[];
  for (final d in dates) {
    final name = holidays[d]!;
    final last = groups.lastOrNull;
    final next = last == null ? null : ymd(DateTime.parse(last.to).add(const Duration(days: 1)));
    if (last != null && last.name == name && next == d) {
      groups[groups.length - 1] = (name: name, from: last.from, to: d, dates: [...last.dates, d]);
    } else {
      groups.add((name: name, from: d, to: d, dates: [d]));
    }
  }
  return groups;
}

/// Settings for working days: the weekend (off every week) and holidays. Days off have no target
/// and aren't counted as missing in the Daily log.
class WorkCalendarScreen extends StatelessWidget {
  const WorkCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TrackerRepository>();
    return Scaffold(
      appBar: const TrackerAppBar('Weekend & holidays'),
      body: StreamBuilder<void>(
        stream: repository.changes,
        builder: (context, _) => _WorkCalendarView(repository: repository),
      ),
    );
  }
}

class _WorkCalendarView extends StatelessWidget {
  const _WorkCalendarView({required this.repository});

  final TrackerRepository repository;

  Future<void> _addHoliday(BuildContext context) async {
    final result = await showDialog<({DateTime from, DateTime to, String name})>(context: context, builder: (_) => const _HolidayDialog());
    if (result == null) return;
    await repository.saveHoliday(result.from, result.to, result.name);
    if (context.mounted) showSnack(context, '${result.name.trim().isEmpty ? 'Holiday' : result.name.trim()} added');
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final first = loc.firstDayOfWeekIndex;
    // weekdays in display order as DateTime.weekday values (1 = Monday … 7 = Sunday)
    final order = [for (var i = 0; i < 7; i++) (first + i) % 7 == 0 ? 7 : (first + i) % 7];
    String name(int weekday) => DateFormat.EEEE().format(DateTime(2024, 1, weekday)); // 2024-01-01 is a Monday
    final weekend = repository.weekend;
    final today = ymd(DateTime.now());
    final groups = groupHolidays(repository.holidays);
    final upcoming = groups.where((g) => g.to.compareTo(today) >= 0).toList();
    final past = groups.where((g) => g.to.compareTo(today) < 0).toList().reversed.toList();

    Widget holidayRow(HolidayGroup g, {bool faded = false}) {
      final days = g.dates.length;
      final when = g.from == g.to ? fmtDay(g.from) : '${fmtDay(g.from)} – ${fmtDay(g.to)}';
      return Panel(
        padding: EdgeInsets.fromLTRB(16.r, 8.r, 4.r, 8.r),
        child: Row(children: [
          IconTile(Icons.celebration_outlined, size: 40.r, iconColor: faded ? C.outline : C.warning),
          SizedBox(width: 12.r),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: sans(16, weight: FontWeight.w600, color: faded ? C.onVariant : C.onSurface)),
              Text('$when · $days ${days == 1 ? 'day' : 'days'}', style: mono(13, color: C.onVariant)),
            ]),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: C.danger),
            onPressed: () async {
              if (await confirm(context, 'Delete this holiday?', '${g.name} · $when', 'Delete')) await repository.deleteHolidays(g.dates);
            },
          ),
        ]),
      );
    }

    /// A single day marked off, or a weekend day / holiday marked as a working day; removing it puts
    /// the day back to the weekend and holiday settings.
    Widget exceptionRow(String date, {required bool off}) => Panel(
          padding: EdgeInsets.fromLTRB(16.r, 8.r, 4.r, 8.r),
          child: Row(children: [
            IconTile(off ? Icons.event_busy_outlined : Icons.work_outline, size: 40.r, iconColor: off ? C.outline : C.success),
            SizedBox(width: 12.r),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fmtDay(date), style: sans(16, weight: FontWeight.w600)),
                Text(off ? 'Day off' : 'Working day', style: mono(13, color: C.onVariant)),
              ]),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, color: C.onVariant),
              onPressed: () => repository.clearDayException(date),
            ),
          ]),
        );

    return TwoPane(
      stackGap: 24.r,
      left: [
        const SectionTitle('Weekend', icon: Icons.weekend_outlined, upper: true),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Days off every week', style: sans(16, weight: FontWeight.w600)),
            SizedBox(height: 4.r),
            Text('They have no target and are never counted as missing. Applies to every month.', style: sans(13, color: C.onVariant)),
            SizedBox(height: 12.r),
            Wrap(spacing: 8.r, runSpacing: 8.r, children: [
              for (final w in order)
                FilterChip(
                  label: Text(name(w)),
                  selected: weekend.contains(w),
                  onSelected: (v) => repository.setWeekend(v ? {...weekend, w} : ({...weekend}..remove(w))),
                ),
            ]),
          ]),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18.r, color: C.onVariant),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(
              'To work on a weekend day or holiday, or to take a single day off, long-press that day in the Daily log calendar.',
              style: sans(13, color: C.onVariant),
            ),
          ),
        ]),
        SizedBox(height: 24.r),
        const SectionTitle('Single-day changes', icon: Icons.edit_calendar_outlined, upper: true),
        if (repository.singleDaysOff.isEmpty && repository.extraWorkDays.isEmpty)
          Panel(child: Text('None. Every day follows the weekend and holidays above.', style: sans(15, color: C.onVariant))),
        for (final d in repository.singleDaysOff) exceptionRow(d, off: true),
        for (final d in repository.extraWorkDays) exceptionRow(d, off: false),
      ],
      right: [
        SectionTitle('Holidays', icon: Icons.celebration_outlined, upper: true, trailing: MicroLabel('${groups.length} holidays')),
        BigButton(label: 'Add holiday', icon: Icons.add, onPressed: () => _addHoliday(context)),
        SizedBox(height: 16.r),
        if (groups.isEmpty) Panel(child: Text('No holidays yet.', style: sans(15, color: C.onVariant))),
        for (final g in upcoming) holidayRow(g),
        if (past.isNotEmpty) ...[
          Padding(padding: EdgeInsets.only(top: 8.r, bottom: 8.r), child: const MicroLabel('Past')),
          for (final g in past) holidayRow(g, faded: true),
        ],
      ],
    );
  }
}

/// Name and dates of a new holiday (one day, or several in a row).
class _HolidayDialog extends StatefulWidget {
  const _HolidayDialog();

  @override
  State<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends State<_HolidayDialog> {
  final _name = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, {DateTime? first}) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first ?? DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  @override
  Widget build(BuildContext context) {
    final days = _to.difference(_from).inDays + 1;
    return AlertDialog(
      title: Text('Add holiday', style: sans(20, weight: FontWeight.w700)),
      content: SizedBox(
        width: 400.r,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const FieldLabel('Name'),
            TextField(controller: _name, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Eid al-Fitr')),
            SizedBox(height: 16.r),
            DateRow(
              label: 'From',
              date: _from,
              onTap: () async {
                final d = await _pick(_from);
                if (d == null) return;
                setState(() {
                  _from = d;
                  if (_to.isBefore(d)) _to = d;
                });
              },
            ),
            SizedBox(height: 8.r),
            DateRow(
              label: 'To (same day for one day)',
              date: _to,
              onTap: () async {
                final d = await _pick(_to, first: _from);
                if (d != null) setState(() => _to = d);
              },
            ),
            SizedBox(height: 8.r),
            Text('$days ${days == 1 ? 'day' : 'days'} off', style: mono(13, color: C.onVariant)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, (from: _from, to: _to, name: _name.text)), child: const Text('ADD')),
      ],
    );
  }
}
