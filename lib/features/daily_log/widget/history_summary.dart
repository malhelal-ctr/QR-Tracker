import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/daily_log_state.dart';

/// Totals for the days in the History filter.
class HistorySummary extends StatelessWidget {
  const HistorySummary({super.key, required this.state});

  final DailyLogState state;

  @override
  Widget build(BuildContext context) {
    final s = state.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Pair(
          Metric(
            label: 'Printed',
            icon: Icons.qr_code_2,
            value: fmt(s.printed),
            valueColor: C.primary,
            caption: '${s.logged} ${s.logged == 1 ? 'day' : 'days'} logged',
          ),
          Metric(label: 'Avg per day', icon: Icons.speed, value: fmt(s.avg)),
        ),
        SizedBox(height: 12.r),
        Metric(
          label: 'Goal met',
          icon: Icons.flag_outlined,
          value: s.withTarget == 0 ? '—' : '${s.met} / ${s.withTarget}',
          valueColor: s.withTarget == 0 ? null : (s.met == s.withTarget ? C.success : C.warning),
          caption: s.withTarget == 0 ? 'No targets in this period' : 'Days that reached their target',
        ),
      ],
    );
  }
}
