import 'package:flutter/material.dart';

import '../../../core/data/stock_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Compact lid stock summary with a link to the Stock tab.
class StockCard extends StatelessWidget {
  const StockCard({super.key, required this.stock, required this.onOpen});

  final StockStats stock;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = stock;
    return Panel(
      color: s.isLow ? C.dangerContainer.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Lid stock',
            icon: Icons.inventory_2_outlined,
            color: s.isLow ? C.danger : C.primary,
            trailing: !s.hasData
                ? null
                : s.isLow
                    ? const Pill('LOW STOCK', kind: PillKind.danger, icon: Icons.warning_amber_rounded)
                    : const Pill('IN STOCK', kind: PillKind.success),
          ),
          if (!s.hasData)
            Text('Not tracked yet. Add a stock count or a delivery to start.', style: sans(14, color: C.onVariant))
          else
            Pair(
              Metric(label: 'On hand', value: fmt(s.onHand), unit: 'lids', valueColor: s.isLow || s.onHand < 0 ? C.danger : null),
              Metric(
                label: 'Days of cover',
                value: s.daysOfCover == null ? '—' : fmt(s.daysOfCover!.clamp(0, 1 << 30)),
                unit: s.daysOfCover == null ? null : 'days',
                caption: s.shortfall > 0 ? 'Short ${fmt(s.shortfall)} for the list' : 'Enough for the list',
                captionColor: s.shortfall > 0 ? C.danger : C.success,
              ),
            ),
          SizedBox(height: 12.r),
          BigButton(
            label: s.hasData ? 'Open stock' : 'Set up stock',
            icon: Icons.inventory_2_outlined,
            style: BigButtonStyle.tonal,
            height: 52.r,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
