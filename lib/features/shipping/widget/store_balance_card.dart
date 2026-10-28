import 'package:flutter/material.dart';

import '../../../core/data/shipping_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Printed lids waiting in store: start + printed − shipped.
class StoreBalanceCard extends StatelessWidget {
  const StoreBalanceCard({super.key, required this.stats});

  final ShippingStats stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final negative = s.balance < 0;
    final since = s.startDate.isEmpty ? 'Since the first log' : 'Since ${fmtDay(s.startDate)} (start ${fmt(s.startQty)})';

    return Panel(
      padding: EdgeInsets.all(20.r),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [negative ? const Color(0xFF4A1020) : const Color(0xFF1C2B5E), C.container, C.container],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Tile(
              color: C.high,
              padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r),
              child: const MicroLabel('Printed lids in store', icon: Icons.warehouse_outlined),
            ),
            const Spacer(),
            if (negative) const Pill('SHORT', kind: PillKind.danger, icon: Icons.warning_amber_rounded),
          ]),
          SizedBox(height: 14.r),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: fmt(s.balance), style: mono(52, weight: FontWeight.w700, height: 1.05, spacing: -1, color: negative ? C.danger : C.onSurface)),
              TextSpan(text: ' lids', style: sans(18, color: C.onVariant)),
            ])),
          ),
          SizedBox(height: 4.r),
          Text(
            negative ? 'More shipped than printed — check the counts or set the starting balance.' : 'Printed with QR, waiting to be shipped',
            style: sans(14, color: negative ? C.danger : C.onVariant),
          ),
          SizedBox(height: 16.r),
          Pair(
            Metric(
              label: 'Shipped / day',
              icon: Icons.local_shipping_outlined,
              value: fmt(s.avgShipped),
              caption: s.avgShipped == null ? 'Log shipments to see this' : 'Last 7 shipping days',
            ),
            Metric(
              label: 'Store lasts',
              icon: Icons.hourglass_bottom,
              value: s.daysOfBuffer == null ? '—' : fmt(s.daysOfBuffer!.clamp(0, 1 << 30)),
              unit: s.daysOfBuffer == null ? null : 'days',
              caption: s.daysOfBuffer == null ? null : 'At the shipping rate',
              valueColor: s.daysOfBuffer != null && s.daysOfBuffer! <= 1 ? C.danger : null,
            ),
          ),
          SizedBox(height: 14.r),
          Tile(
            color: C.lowest,
            child: Row(children: [
              Icon(Icons.swap_vert, size: 18.r, color: C.onVariant),
              SizedBox(width: 8.r),
              Expanded(
                child: Text.rich(TextSpan(style: sans(14, color: C.onVariant), children: [
                  TextSpan(text: '$since: '),
                  TextSpan(text: '+${fmt(s.printed)}', style: mono(14, weight: FontWeight.w700, color: C.primary)),
                  const TextSpan(text: ' printed · '),
                  TextSpan(text: '−${fmt(s.shipped)}', style: mono(14, weight: FontWeight.w700, color: C.success)),
                  const TextSpan(text: ' shipped'),
                ])),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
