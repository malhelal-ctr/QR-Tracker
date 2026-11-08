import 'package:flutter/material.dart';

import '../../../core/data/lid_forecast.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Label, pill kind and colour for a [LidStatus].
(String, PillKind, Color) lidStatusLook(LidStatus status) => switch (status) {
      LidStatus.ok => ('OK', PillKind.success, C.success),
      LidStatus.low => ('ORDER NOW', PillKind.danger, C.warning),
      LidStatus.critical => ('CRITICAL', PillKind.danger, C.danger),
      LidStatus.out => ('OUT', PillKind.danger, C.danger),
    };

/// "3.3" working days.
String fmtDays(double days) => days >= 10 ? days.toStringAsFixed(0) : days.toStringAsFixed(1);

/// When the lids run out at the average daily printing (skipping days off), the order-by day from the
/// lead time, the best case at the month target, and the lids left day by day.
class RunOutCard extends StatelessWidget {
  const RunOutCard({super.key, required this.forecast});

  final LidForecast forecast;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final status = f.status;
    final look = status == null ? null : lidStatusLook(status);

    Widget line(IconData icon, String text, {Color color = C.onVariant}) => Padding(
          padding: EdgeInsets.only(top: 8.r),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 17.r, color: color),
            SizedBox(width: 8.r),
            Expanded(child: Text(text, style: sans(14, color: color))),
          ]),
        );

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
          'Lids run out',
          icon: Icons.event_busy_outlined,
          trailing: look == null ? null : Pill(look.$1, kind: look.$2, icon: status == LidStatus.ok ? Icons.check_circle_outline : Icons.warning_amber_rounded),
        ),
        if (f.average == null)
          Text('Log printed counts in the Daily log to see when the lids run out.', style: sans(15, color: C.onVariant))
        else ...[
          Text(
            f.onHand <= 0 ? 'Out of lids' : (f.runOut == null ? 'More than a year away' : fmtDate(f.runOut!)),
            style: mono(30, weight: FontWeight.w700, color: look?.$3),
          ),
          SizedBox(height: 4.r),
          Text(
            'At your average ${fmt(f.average)} per working day · ${fmtDays(f.daysLeft!.clamp(0, 9999).toDouble())} working days of lids',
            style: sans(14, color: C.onVariant),
          ),
          if (f.orderBy != null && f.onHand > 0)
            line(
              Icons.shopping_cart_outlined,
              f.needsOrder
                  ? 'Order now: new lids take ${f.leadTime} working ${f.leadTime == 1 ? 'day' : 'days'} to arrive'
                  : 'Order by ${fmtDate(f.orderBy!)} (${f.leadTime} working ${f.leadTime == 1 ? 'day' : 'days'} lead time)',
              color: f.needsOrder ? look!.$3 : C.onVariant,
            ),
          if (f.bestRate != null && f.bestRate! > 0 && f.bestRunOut != null && f.onHand > 0)
            line(Icons.speed, 'Best case at the target ${fmt(f.bestRate)} per day: ${fmtDate(f.bestRunOut!)}'),
          line(Icons.event_note_outlined, 'Weekend and holidays are skipped. Set them in Data › Weekend & holidays.'),
          if (f.timeline.isNotEmpty) ...[
            SizedBox(height: 8.r),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Day by day', style: sans(15, weight: FontWeight.w600)),
                children: [for (final d in f.timeline) _DayRow(day: d, forecast: f)],
              ),
            ),
          ],
        ],
      ]),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.forecast});

  final LidForecastDay day;
  final LidForecast forecast;

  @override
  Widget build(BuildContext context) {
    final isOrderBy = forecast.orderBy == day.date;
    final isRunOut = forecast.runOut == day.date;
    final color = isRunOut ? C.danger : (isOrderBy ? C.warning : null);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 8.r),
      decoration: BoxDecoration(
        color: isRunOut || isOrderBy ? color!.withValues(alpha: 0.12) : null,
        border: const Border(bottom: BorderSide(color: C.low)),
      ),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmtDate(day.date), style: sans(14, weight: FontWeight.w600, color: day.off ? C.outline : null)),
            if (isOrderBy || isRunOut)
              Text(isRunOut ? 'RUNS OUT' : 'ORDER BY', style: mono(10, weight: FontWeight.w700, color: color)),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Text(day.off ? 'off' : '−${fmt(day.use)}', textAlign: TextAlign.right, style: mono(13, color: C.onVariant)),
        ),
        Expanded(
          flex: 4,
          child: Text(fmt(day.left), textAlign: TextAlign.right, style: mono(14, weight: FontWeight.w700, color: day.left <= 0 ? C.danger : null)),
        ),
      ]),
    );
  }
}
