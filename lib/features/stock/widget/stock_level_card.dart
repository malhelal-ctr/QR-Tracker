import 'package:flutter/material.dart';

import '../../../core/data/stock_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Lids in stock now, how long they last, and whether they cover the rest of the QR list.
class StockLevelCard extends StatelessWidget {
  const StockLevelCard({super.key, required this.stats});

  final StockStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final since = s.lastCount == null ? 'Since the first entry' : 'Since count on ${fmtDay(s.lastCount!.date)}';

    return Panel(
      padding: EdgeInsets.all(20.r),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [s.isLow ? const Color(0xFF4A1020) : const Color(0xFF1C2B5E), C.container, C.container],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Tile(
                color: C.high,
                padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
                child: const MicroLabel('Lids in stock', icon: Icons.inventory_2_outlined),
              ),
              const Spacer(),
              if (!s.hasData)
                const Pill('NOT SET UP')
              else if (s.isLow)
                const Pill('LOW STOCK', kind: PillKind.danger, icon: Icons.warning_amber_rounded)
              else
                const Pill('IN STOCK', kind: PillKind.success, icon: Icons.check_circle_outline),
            ],
          ),
          SizedBox(height: 14.r),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: fmt(s.onHand),
                    style: mono(52, weight: FontWeight.w700, height: 1.05, spacing: -1, color: s.onHand < 0 || s.isLow ? C.danger : C.onSurface),
                  ),
                  TextSpan(
                    text: ' lids',
                    style: sans(18, color: C.onVariant),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 4.r),
          Text(
            'Daily counters you log are subtracted (1 lid per printed code)',
            style: sans(14, color: C.onVariant),
          ),
          SizedBox(height: 16.r),
          Pair(
            Metric(
              label: 'Days of cover',
              icon: Icons.hourglass_bottom,
              value: s.daysOfCover == null ? '—' : fmt(s.daysOfCover!.clamp(0, 1 << 30)),
              unit: s.daysOfCover == null ? null : 'days',
              caption: s.coverUntil == null ? 'Log counters to see this' : 'Until ${fmtDate(s.coverUntil!)}',
              valueColor: s.daysOfCover != null && s.daysOfCover! <= 2 ? C.danger : null,
            ),
            !s.hasData
                ? const Metric(label: 'For the QR list', icon: Icons.fact_check_outlined, value: '—', caption: 'Add stock to compare')
                : Metric(
                    label: 'For the QR list',
                    icon: Icons.fact_check_outlined,
                    value: s.shortfall > 0 ? '−${fmt(s.shortfall)}' : 'Enough',
                    valueColor: s.shortfall > 0 ? C.danger : C.success,
                    caption: s.shortfall > 0 ? 'Lids short to finish' : 'Stock covers the list',
                    captionColor: s.shortfall > 0 ? C.danger : C.success,
                  ),
          ),
          if (s.hasData) ...[
            SizedBox(height: 14.r),
            Tile(
              color: C.lowest,
              child: Row(
                children: [
                  Icon(Icons.swap_vert, size: 18.r, color: C.onVariant),
                  SizedBox(width: 8.r),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: sans(14, color: C.onVariant),
                        children: [
                          TextSpan(text: '$since: '),
                          TextSpan(
                            text: '+${fmt(s.received)}',
                            style: mono(14, weight: FontWeight.w700, color: C.success),
                          ),
                          const TextSpan(text: ' received · '),
                          TextSpan(
                            text: '−${fmt(s.usedSinceCount)}',
                            style: mono(14, weight: FontWeight.w700, color: C.onSurface),
                          ),
                          const TextSpan(text: ' used · '),
                          TextSpan(
                            text: '−${fmt(s.wasted)}',
                            style: mono(14, weight: FontWeight.w700, color: C.danger),
                          ),
                          const TextSpan(text: ' waste'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
