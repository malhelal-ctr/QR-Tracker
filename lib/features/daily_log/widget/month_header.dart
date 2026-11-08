import 'package:flutter/material.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// The month at a glance: target, printed, miss so far, what is needed per day from here, and the machine check.
class MonthHeader extends StatelessWidget {
  const MonthHeader({super.key, required this.summary, required this.ownTarget, required this.onEditTarget});

  final MonthSummary summary;

  /// The month has its own daily target (else it is copied from an earlier month).
  final bool ownTarget;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final target = s.monthTarget;
    final miss = s.missSoFar;
    final past = s.isPast;
    final worst = s.worstDay;
    final gap = 10.r;

    Widget line(IconData icon, String text, {Color color = C.onVariant}) => Padding(
      padding: EdgeInsets.only(top: 8.r),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17.r, color: color),
          SizedBox(width: 8.r),
          Expanded(
            child: Text(text, style: sans(14, color: color)),
          ),
        ],
      ),
    );

    final metrics = [
      Metric(
        label: 'Month target',
        value: fmt(target),
        caption: s.dailyTarget == null ? 'No daily target set' : '${fmt(s.dailyTarget)} × ${s.workingDays} working days',
      ),
      Metric(label: 'Printed', value: fmt(s.printed), caption: target == null || target == 0 ? null : '${fmtPct(s.printed, target)} of target'),
      Metric(
        label: past ? 'Month result' : 'Miss so far',
        value: miss == null ? '—' : fmtSigned(miss),
        valueColor: miss == null ? null : (miss >= 0 ? C.success : C.danger),
        caption: 'Target so far ${fmt(s.targetSoFar)}',
      ),
    ];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // the target chip moves under the title when there isn't room beside it
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12.r,
            runSpacing: 4.r,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.track_changes, size: 22.r),
                  SizedBox(width: 8.r),
                  Text(past ? 'Month result' : 'Month plan', style: sans(21, weight: FontWeight.w700)),
                ],
              ),
              Padding(
                padding: EdgeInsets.zero,
                child: ActionChip(
                  avatar: Icon(Icons.edit_outlined, size: 16.r, color: C.primary),
                  label: Text(
                    s.dailyTarget == null ? 'Set daily target' : 'Daily target ${fmt(s.dailyTarget)}${ownTarget ? '' : ' (copied)'}',
                    style: mono(13, weight: FontWeight.w700, color: C.primary),
                  ),
                  backgroundColor: C.high,
                  side: BorderSide.none,
                  onPressed: onEditTarget,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.r),
          LayoutBuilder(
            builder: (context, box) => box.maxWidth < 520.r
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      metrics[0],
                      SizedBox(height: gap),
                      Pair(metrics[1], metrics[2]),
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: metrics[0]),
                        SizedBox(width: gap),
                        Expanded(child: metrics[1]),
                        SizedBox(width: gap),
                        Expanded(child: metrics[2]),
                      ],
                    ),
                  ),
          ),
          if (target != null && target > 0) ...[
            SizedBox(height: 14.r),
            Meter(s.printed / target),
            SizedBox(height: 6.r),
            Row(
              children: [
                Text('${fmtPct(s.printed, target)} printed', style: mono(12, color: C.onVariant)),
                const Spacer(),
                if (!past) Text('expected by today ${fmtPct(s.targetSoFar, target)}', style: mono(12, color: C.onVariant)),
              ],
            ),
          ],
          if (!past && s.neededPerDay != null)
            line(
              Icons.speed,
              'To still hit the month: ${fmt(s.neededPerDay)} per day for the ${s.workingDaysLeft} working days left',
              color: s.dailyTarget != null && s.neededPerDay! > s.dailyTarget! ? C.warning : C.onVariant,
            ),
          if (s.workingDaysSoFar > 0)
            line(
              Icons.event_available,
              [
                'On target ${s.daysOnTarget} / ${s.workingDaysSoFar} days',
                if (s.missingDays > 0) '${s.missingDays} not logged',
                if (worst != null) 'Worst ${fmtDay(worst.key)} (${fmtSigned(worst.diff!)})',
              ].join(' · '),
            ),
          if (s.machinePrinted != null)
            line(
              s.unaccounted == 0 ? Icons.verified_outlined : Icons.precision_manufacturing_outlined,
              'Machine total moved ${fmt(s.machinePrinted)} · logged ${fmt(s.machineLogged)}'
              '${s.unaccounted == 0 ? ' · matches' : ' · ${fmt(s.unaccounted!.abs())} ${s.unaccounted! > 0 ? 'not logged' : 'logged more than the machine'}'}',
              color: s.unaccounted == 0 ? C.success : C.warning,
            ),
          if (s.totalWarnings > 0)
            line(
              Icons.warning_amber_rounded,
              '${s.totalWarnings} ${s.totalWarnings == 1 ? 'day has a machine total' : 'days have machine totals'} that don’t match the day before + printed',
              color: C.warning,
            ),
        ],
      ),
    );
  }
}
