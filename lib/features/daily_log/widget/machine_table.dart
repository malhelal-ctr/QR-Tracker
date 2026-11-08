import 'package:flutter/material.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// The machine total history of a month, newest first: each reading, how far it moved since the reading
/// before, the printed count logged that day and whether the two agree. Tap a row to edit the day.
class MachineTable extends StatelessWidget {
  const MachineTable({super.key, required this.summary, required this.onTap, this.selected});

  final MonthSummary summary;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = summary.days.where((d) => d.day?.total != null).toList().reversed.toList();
    final first = rows.lastOrNull, last = rows.firstOrNull;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (last != null)
        Panel(
          child: Wrap(spacing: 24.r, runSpacing: 12.r, children: [
            _Stat('Latest total', fmt(last.day!.total), caption: fmtDay(last.key)),
            _Stat('Readings', '${rows.length}', caption: 'this month'),
            if (summary.machinePrinted != null) ...[
              _Stat('Moved this month', fmt(summary.machinePrinted), caption: 'from the last total of the month before'),
              _Stat(
                'Not logged',
                fmt(summary.unaccounted),
                caption: summary.unaccounted == 0 ? 'matches the daily logs' : 'machine − logged',
                color: summary.unaccounted == 0 ? C.success : C.warning,
              ),
            ] else if (first != null && first.previousTotal == null)
              _Stat('First reading', fmt(first.day!.total), caption: 'no earlier total to compare'),
          ]),
        ),
      Panel(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 640.r;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Row(header: true, wide: wide, cells: [
              for (final h in ['DATE', 'MACHINE TOTAL', 'MOVED', if (wide) 'PRINTED (LOG)', 'CHECK', if (wide) 'NOTE'])
                Text(h, textAlign: h == 'DATE' || h == 'NOTE' ? TextAlign.left : TextAlign.right, style: mono(11, weight: FontWeight.w700, spacing: 0.8, color: C.onVariant)),
            ]),
            if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Text('No machine readings this month. Tap Log reading to add the machine’s total counter.', style: sans(15, color: C.onVariant)),
              ),
            for (final d in rows) _row(d, wide),
          ]);
        }),
      ),
    ]);
  }

  Widget _row(MonthDay d, bool wide) {
    final day = d.day!;
    final moved = day.totalReset || d.previousTotal == null ? null : day.total! - d.previousTotal!;
    final gap = d.gap;
    final Widget check = switch (gap) {
      _ when day.totalReset => _num('reset', color: C.outline),
      null => _num(d.previousTotal == null ? 'first' : 'no daily log', color: C.outline),
      0 => Align(alignment: Alignment.centerRight, child: Icon(Icons.check, size: 18.r, color: C.success)),
      final g => _num('⚠ ${fmtSigned(g)}', color: C.warning),
    };
    return _Row(
      wide: wide,
      selected: d.key == selected,
      onTap: () => onTap(d.key),
      cells: [
        Text(fmtDay(d.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w600)),
        _num(fmt(day.total), weight: FontWeight.w700),
        _num(moved == null ? '—' : fmt(moved), color: moved != null && moved < 0 ? C.danger : C.onVariant),
        if (wide) _num(fmt(day.counter), color: C.onVariant),
        check,
        if (wide) Text(day.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: C.onVariant)),
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
    final flex = wide ? [4, 5, 4, 4, 3, 6] : [4, 5, 4, 3];
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
        for (final (i, c) in cells.indexed) ...[
          if (i > 0) SizedBox(width: 10.r),
          Expanded(flex: flex[i], child: c),
        ],
      ]),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
