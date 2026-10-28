import 'package:flutter/material.dart';

import '../../../core/data/progress_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class PositionCard extends StatelessWidget {
  const PositionCard({super.key, required this.stats, required this.fileName, required this.onScan});

  final ProgressStats stats;
  final String fileName;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Panel(
      padding: EdgeInsets.all(20.r),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1C2B5E), C.container, C.container]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tile(color: C.high, padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 6.r), child: MicroLabel('Print position', icon: Icons.tune)),
          SizedBox(height: 14.r),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: s.last == null ? '—' : '#${fmt(s.printed)}', style: mono(52, weight: FontWeight.w700, height: 1.05, spacing: -1)),
              TextSpan(text: ' / ${fmt(s.total)}', style: mono(22, weight: FontWeight.w600, color: C.success)),
            ])),
          ),
          SizedBox(height: 6.r),
          Row(children: [
            Icon(Icons.description_outlined, size: 18.r, color: C.onVariant),
            SizedBox(width: 6.r),
            Flexible(child: Text(fileName, overflow: TextOverflow.ellipsis, style: mono(15, weight: FontWeight.w600))),
          ]),
          SizedBox(height: 18.r),
          Row(children: [
            const Expanded(child: MicroLabel('Queue completion')),
            Text(fmtPct(s.printed, s.total), style: mono(15, weight: FontWeight.w700, color: C.success)),
          ]),
          SizedBox(height: 8.r),
          Meter(s.total == 0 ? 0 : s.printed / s.total),
          SizedBox(height: 16.r),
          Pair(
            Metric(label: 'Done', icon: Icons.check_circle_outline, value: fmtPct(s.printed, s.total), caption: '${fmt(s.printed)} printed'),
            Metric(label: 'Remaining', icon: Icons.pending_actions, value: fmt(s.remaining), caption: '${fmtPct(s.remaining, s.total)} of list'),
          ),
          SizedBox(height: 14.r),
          Row(children: [
            Icon(Icons.history, size: 18.r, color: C.onVariant),
            SizedBox(width: 6.r),
            Expanded(
              child: Text(
                s.last == null ? 'Not scanned yet' : 'Last scan ${fmtTime(s.last!.ts)}',
                style: mono(14, weight: FontWeight.w500, color: C.onVariant),
              ),
            ),
          ]),
          SizedBox(height: 16.r),
          BigButton(label: 'Scan now', icon: Icons.qr_code_scanner, trailing: Icons.arrow_forward, onPressed: onScan),
        ],
      ),
    );
  }
}
