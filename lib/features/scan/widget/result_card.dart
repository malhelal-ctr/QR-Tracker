import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/scan_state.dart';

/// "Machine is at #12,450" card for a code found in the list.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final pos = result.scan.pos!;
    final total = result.total;
    final delta = result.sinceLast;
    final prev = result.previous;

    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 12.r),
            decoration: BoxDecoration(color: C.high, borderRadius: BorderRadius.vertical(top: Radius.circular(12.r))),
            child: Row(children: [
              const Icon(Icons.verified_outlined, color: C.success),
              SizedBox(width: 8.r),
              Expanded(child: Text('MACHINE IS AT', style: sans(17, weight: FontWeight.w700, spacing: 0.8))),
              // the time changes with every scan, so a new read is easy to tell from the last one
              Text(fmtClock(result.scan.ts), style: mono(13, weight: FontWeight.w600, color: C.onVariant)),
              SizedBox(width: 8.r),
              const Pill('IN LIST', kind: PillKind.success, icon: Icons.check),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('#${fmt(pos)}', style: mono(56, weight: FontWeight.w700, color: C.primary, height: 1.1, spacing: -1)),
                ),
                Row(children: [
                  Expanded(child: Text('of ${fmt(total)} codes', style: sans(16, color: C.onVariant))),
                  Text('${fmtPct(pos, total)} done', style: mono(15, weight: FontWeight.w700, color: C.success)),
                ]),
                SizedBox(height: 12.r),
                Meter(pos / total, color: C.success, height: 12.r),
                SizedBox(height: 14.r),
                Pair(
                  Metric(label: 'Remaining', value: fmt(total - pos), color: C.lowest),
                  Metric(
                    label: 'Since highest scan',
                    value: delta == null ? '—' : fmtSigned(delta),
                    valueColor: delta == null ? null : (delta >= 0 ? C.success : C.danger),
                    color: C.lowest,
                  ),
                ),
                if (prev != null) ...[
                  SizedBox(height: 12.r),
                  Row(children: [
                    Icon(Icons.history, size: 18.r, color: C.onVariant),
                    SizedBox(width: 6.r),
                    Expanded(
                      child: Text.rich(TextSpan(style: sans(14, color: C.onVariant), children: [
                        TextSpan(text: 'Highest scan ${fmtTime(prev.ts)} at '),
                        TextSpan(text: '#${fmt(prev.pos)}', style: mono(14, weight: FontWeight.w700, color: C.onSurface)),
                      ])),
                    ),
                  ]),
                ],
                SizedBox(height: 14.r),
                Tile(
                  color: C.lowest,
                  padding: EdgeInsets.all(14.r),
                  child: Column(children: [
                    _CodeRow('Scanned code', result.scan.code, highlight: true),
                    if (result.nextCode case final next?) ...[SizedBox(height: 12.r), _CodeRow('Next to print', next)],
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow(this.label, this.code, {this.highlight = false});

  final String label;
  final String code;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(children: [
        MicroLabel(label),
        SizedBox(width: 12.r),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: highlight ? EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r) : EdgeInsets.zero,
              decoration: highlight ? BoxDecoration(color: C.successContainer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6.r)) : null,
              child: SelectableText(code, style: mono(16, weight: FontWeight.w700, color: highlight ? C.success : C.onSurface)),
            ),
          ),
        ),
      ]);
}
