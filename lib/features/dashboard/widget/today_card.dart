import 'package:flutter/material.dart';

import '../../../core/data/progress_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.stats, required this.goalMet, required this.onLog});

  final ProgressStats stats;
  final bool goalMet;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final printed = stats.todayPrinted;
    final target = stats.target;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Dot(),
            SizedBox(width: 10.r),
            Expanded(child: Text('Today · ${fmtDate(DateTime.now())}', style: sans(21, weight: FontWeight.w700))),
            if (target == null) const Pill('NO TARGET', kind: PillKind.danger) else if (goalMet) const Pill('GOAL MET', kind: PillKind.success),
          ]),
          SizedBox(height: 14.r),
          Tile(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: MicroLabel('Daily goal')),
                  if (printed != null && target != null && target > 0)
                    Text('${(printed / target * 100).toStringAsFixed(1)}% of goal', style: mono(13, weight: FontWeight.w600, color: C.success)),
                ]),
                SizedBox(height: 10.r),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: printed == null ? '0' : fmt(printed), style: mono(40, weight: FontWeight.w700, height: 1)),
                          TextSpan(text: ' / ${target == null ? 'not set' : fmt(target)}', style: sans(18, color: C.onVariant)),
                        ])),
                      ),
                    ),
                    if (printed != null && target != null && !goalMet) Text('${fmt(target - printed)} to go', style: sans(14, weight: FontWeight.w600)),
                  ],
                ),
                if (target != null && target > 0) ...[
                  SizedBox(height: 12.r),
                  Meter((printed ?? 0) / target, color: C.success, height: 12.r),
                ],
              ],
            ),
          ),
          SizedBox(height: 12.r),
          Tile(
            color: C.high,
            child: Row(children: [
              IconTile(Icons.published_with_changes, size: 40.r, color: C.highest),
              SizedBox(width: 12.r),
              Expanded(
                child: printed == null
                    ? Text('No scans today yet. Scan the machine to see today’s output.', style: sans(14, color: C.onVariant))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${fmt(printed)} printed today', style: sans(16, weight: FontWeight.w700)),
                          Text(
                            switch (stats) {
                              _ when stats.todayFromCounter => 'From the counter logged for today',
                              _ when stats.todayScans < 2 => 'First scan today at ${fmtClock(stats.todaySince!.ts)} — scan again later to see progress',
                              _ => 'Between the lowest and highest code scanned today (first scan ${fmtClock(stats.todaySince!.ts)})',
                            },
                            style: sans(14, color: C.onVariant),
                          ),
                        ],
                      ),
              ),
            ]),
          ),
          SizedBox(height: 12.r),
          BigButton(label: 'Morning log', icon: Icons.assignment_turned_in_outlined, style: BigButtonStyle.tonal, height: 52.r, onPressed: onLog),
        ],
      ),
    );
  }
}
