import 'package:flutter/material.dart';

import '../../../core/data/progress_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.stats, required this.onPace});

  final ProgressStats stats;
  final bool? onPace;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Plan & velocity', icon: Icons.insights, color: C.primary),
          Pair(
            Metric(label: 'Avg / day', value: fmt(s.avg), caption: s.avg == null ? 'Log counters to see this' : 'Last 7 logs'),
            Metric(
              label: 'Est. finish',
              icon: Icons.flag_outlined,
              color: C.primaryContainer.withValues(alpha: 0.35),
              value: s.finish == null ? '—' : fmtDate(s.finish!),
              caption: s.finish == null ? null : 'At your average pace',
            ),
          ),
          SizedBox(height: 12.r),
          Pair(
            Metric(label: 'Days left in period', value: s.daysLeft == null ? '—' : fmt(s.daysLeft!.clamp(0, 1 << 30)), unit: s.daysLeft == null ? null : 'days'),
            Metric(
              label: 'Needed / day',
              value: fmt(s.suggested),
              valueColor: C.success,
              caption: switch (onPace) { true => 'On pace', false => 'Above your average', null => null },
              captionColor: onPace == false ? C.danger : C.success,
            ),
          ),
          if (s.daysLeft == null) ...[
            SizedBox(height: 12.r),
            Text('Set the period end date in Data to get the codes needed per day.', style: sans(13, color: C.onVariant)),
          ],
        ],
      ),
    );
  }
}
