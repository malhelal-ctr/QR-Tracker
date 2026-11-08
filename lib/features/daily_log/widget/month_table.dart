import 'package:flutter/material.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// The month as a table, newest day first: one compact row per day up to today, and the month's totals.
/// Wide screens show every column; phones show date, printed, +/− and the machine check. Tap a row to edit it.
class MonthTable extends StatelessWidget {
  const MonthTable({super.key, required this.summary, required this.onTap, this.selected});

  final MonthSummary summary;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = summary.days.where((d) => d.counted || d.logged || d.date == summary.today).toList().reversed.toList();
    return Panel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 700.r;
        final cols = wide ? _wideCols : _narrowCols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row(cols: cols, header: true, cells: [for (final c in cols) Text(c.label, textAlign: c.align, style: mono(11, weight: FontWeight.w700, spacing: 0.8, color: C.onVariant))]),
            if (rows.isEmpty)
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Text('Nothing to show for this month yet.', style: sans(15, color: C.onVariant)),
              ),
            for (final d in rows)
              _Row(
                cols: cols,
                selected: d.key == selected,
                onTap: () => onTap(d.key),
                cells: [for (final c in cols) c.cell(d)],
              ),
            _Row(
              cols: cols,
              footer: true,
              cells: [for (final c in cols) c.total?.call(summary) ?? const SizedBox.shrink()],
            ),
          ],
        );
      }),
    );
  }
}

class _Col {
  const _Col(this.label, this.flex, this.cell, {this.align = TextAlign.right, this.total});

  final String label;
  final int flex;
  final TextAlign align;
  final Widget Function(MonthDay d) cell;
  final Widget Function(MonthSummary s)? total;
}

Text _num(String text, {Color? color, FontWeight weight = FontWeight.w500}) =>
    Text(text, textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(14, weight: weight, color: color));

Widget _date(MonthDay d) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmtDay(d.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, weight: FontWeight.w600)),
        if (d.off)
          Text(
            (d.holiday ?? 'Day off').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mono(10, weight: FontWeight.w700, color: d.holiday == null ? C.outline : C.warning),
          ),
      ],
    );

Widget _printed(MonthDay d) => d.printed != null
    ? _num(fmt(d.printed), weight: FontWeight.w700)
    : d.missing
        ? _num('missing', color: C.danger)
        : _num('—', color: C.outline);

Widget _diff(MonthDay d) {
  final diff = d.diff;
  return diff == null ? _num('—', color: C.outline) : _num(fmtSigned(diff), color: diff >= 0 ? C.success : C.danger, weight: FontWeight.w700);
}

Widget _check(MonthDay d) {
  final gap = d.gap;
  if (gap == null) return d.day?.totalReset ?? false ? _num('reset', color: C.outline) : const SizedBox.shrink();
  if (gap == 0) return Align(alignment: Alignment.centerRight, child: Icon(Icons.check, size: 18.r, color: C.success));
  return Tooltip(
    message: 'Machine total is ${fmt(gap.abs())} ${gap > 0 ? 'higher' : 'lower'} than the day before + printed',
    child: _num('⚠ ${fmtSigned(gap)}', color: C.warning),
  );
}

Widget _sumDiff(MonthSummary s) {
  final miss = s.missSoFar;
  return miss == null ? const SizedBox.shrink() : _num(fmtSigned(miss), color: miss >= 0 ? C.success : C.danger, weight: FontWeight.w700);
}

final _narrowCols = [
  _Col('DATE', 5, _date, align: TextAlign.left, total: (_) => Text('MONTH', style: mono(12, weight: FontWeight.w700))),
  _Col('PRINTED', 4, _printed, total: (s) => _num(fmt(s.printed), weight: FontWeight.w700)),
  _Col('+/−', 4, _diff, total: _sumDiff),
  _Col('CHECK', 3, _check),
];

final _wideCols = [
  _Col('DATE', 5, _date, align: TextAlign.left, total: (_) => Text('MONTH', style: mono(12, weight: FontWeight.w700))),
  _Col('PRODUCT', 4, (d) => Text(d.day?.product ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(14, color: C.primary)), align: TextAlign.left),
  _Col('TARGET', 4, (d) => _num(d.target == null ? '—' : '${fmt(d.target)}${d.day?.target != null ? '*' : ''}', color: C.onVariant),
      total: (s) => _num(fmt(s.targetSoFar), color: C.onVariant)),
  _Col('PRINTED', 4, _printed, total: (s) => _num(fmt(s.printed), weight: FontWeight.w700)),
  _Col('+/−', 4, _diff, total: _sumDiff),
  _Col('MONTH SO FAR', 4, (d) {
    final r = d.runningDiff;
    return r == null ? const SizedBox.shrink() : _num(fmtSigned(r), color: r >= 0 ? C.success : C.danger);
  }),
  _Col('MACHINE TOTAL', 5, (d) => _num(fmt(d.day?.total), color: C.onVariant)),
  _Col('CHECK', 3, _check),
  _Col('NOTE', 6, (d) => Text(d.day?.note ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, color: C.onVariant)), align: TextAlign.left),
];

class _Row extends StatelessWidget {
  const _Row({required this.cols, required this.cells, this.header = false, this.footer = false, this.selected = false, this.onTap});

  final List<_Col> cols;
  final List<Widget> cells;
  final bool header;
  final bool footer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: header ? 10.r : 11.r),
      decoration: BoxDecoration(
        color: selected ? C.high : (header || footer ? C.low : null),
        border: Border(
          top: footer ? const BorderSide(color: C.outlineVariant) : BorderSide.none,
          bottom: header || footer ? BorderSide.none : const BorderSide(color: C.low),
          left: selected ? BorderSide(color: C.primary, width: 3.r) : BorderSide.none,
        ),
      ),
      child: Row(children: [
        for (final (i, c) in cols.indexed) ...[
          if (i > 0) SizedBox(width: 10.r),
          Expanded(flex: c.flex, child: cells[i]),
        ],
      ]),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}
