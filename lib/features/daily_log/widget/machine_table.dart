import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Both lasers' cumulative-counter history, newest first.
class MachineTable extends StatelessWidget {
  const MachineTable({super.key, required this.summary, required this.onTap, this.selected});

  final MonthSummary summary;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = summary.days.where((d) => d.day?.total != null || d.day?.total2 != null).toList().reversed.toList();
    final latest1 = rows.where((d) => d.day?.total != null).firstOrNull;
    final latest2 = rows.where((d) => d.day?.total2 != null).firstOrNull;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (latest1 != null || latest2 != null)
        Panel(
          child: Wrap(spacing: 24.r, runSpacing: 12.r, children: [
            if (latest1 != null) _Stat('Laser 1 latest', fmt(latest1.day!.total), caption: fmtDay(latest1.key)),
            if (latest2 != null) _Stat('Laser 2 latest', fmt(latest2.day!.total2), caption: fmtDay(latest2.key)),
            for (final machine in LaserMachine.values)
              if (summary.machinePrintedFor(machine) case final moved?) ...[
                _Stat('${machine.label} moved', fmt(moved), caption: 'this month'),
                _Stat(
                  '${machine.label} not logged',
                  fmt(summary.unaccountedFor(machine)),
                  caption: summary.unaccountedFor(machine) == 0 ? 'matches daily output' : 'counter − output',
                  color: summary.unaccountedFor(machine) == 0 ? C.success : C.warning,
                ),
              ],
          ]),
        ),
      Panel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 700.r;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Row(header: true, wide: wide, cells: [
              for (final h in ['DATE', 'LASER 1 TOTAL', 'LASER 2 TOTAL', if (wide) 'LASER 1 OUTPUT', if (wide) 'LASER 2 OUTPUT', 'CHECK'])
                Text(h, textAlign: h == 'DATE' ? TextAlign.left : TextAlign.right, style: mono(11, weight: FontWeight.w700, spacing: 0.8, color: C.onVariant)),
            ]),
            if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Text('No machine readings this month. Tap Log readings to enter both counters.', style: sans(15, color: C.onVariant)),
              ),
            for (final d in rows) _row(d, wide),
          ]);
        }),
      ),
    ]);
  }

  Widget _row(MonthDay d, bool wide) {
    final day = d.day!;
    final warnings = [d.gap, d.gap2].whereType<int>().where((g) => g != 0).toList();
    final hasMatch = d.gap == 0 || d.gap2 == 0;
    final reset = day.totalReset || day.totalReset2;
    final Widget check = warnings.isNotEmpty
        ? Tooltip(message: 'Counter does not match previous reading + machine output', child: _num('⚠ ${warnings.map(fmtSigned).join(' / ')}', color: C.warning))
        : hasMatch
            ? Align(alignment: Alignment.centerRight, child: Icon(Icons.check, size: 18.r, color: C.success))
            : _num(reset ? 'reset' : 'first', color: C.outline);
    return _Row(
      wide: wide,
      selected: d.key == selected,
      onTap: () => onTap(d.key),
      cells: [
        Text(fmtDay(d.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w600)),
        _num(fmt(day.total), weight: FontWeight.w700),
        _num(fmt(day.total2), weight: FontWeight.w700),
        if (wide) _num(fmt(day.laser1Output), color: C.onVariant),
        if (wide) _num(fmt(day.laser2Output), color: C.onVariant),
        check,
      ],
    );
  }
}

Text _num(String text, {Color? color, FontWeight weight = FontWeight.w500}) =>
    Text(text, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(14, weight: weight, color: color));

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.caption, this.color});
  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        MicroLabel(label),
        SizedBox(height: 4.r),
        Text(value, style: mono(22, weight: FontWeight.w700, color: color)),
        if (caption != null) Text(caption!, style: sans(12, color: C.onVariant)),
      ]);
}

class _Row extends StatelessWidget {
  const _Row({required this.cells, required this.wide, this.header = false, this.selected = false, this.onTap});
  final List<Widget> cells;
  final bool wide;
  final bool header;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final flex = wide ? [4, 5, 5, 4, 4, 3] : [4, 5, 5, 3];
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 11.r),
      decoration: BoxDecoration(
        color: selected ? C.high : (header ? C.low : null),
        border: Border(
          bottom: header ? BorderSide.none : const BorderSide(color: C.low),
          left: selected ? BorderSide(color: C.primary, width: 3.r) : BorderSide.none,
        ),
      ),
      child: Row(children: [
        for (final (i, cell) in cells.indexed) ...[
          if (i > 0) SizedBox(width: 10.r),
          Expanded(flex: flex[i], child: cell),
        ],
      ]),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
