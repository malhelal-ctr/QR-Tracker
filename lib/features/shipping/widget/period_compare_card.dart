import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/data/shipping_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/period.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/period_chips.dart';

const _printedColor = Color(0xFF3B5BDB);

/// Printed vs shipped for a chosen period, with over / under and a daily chart.
class PeriodCompareCard extends StatelessWidget {
  const PeriodCompareCard({super.key, required this.period, required this.preset, required this.onPreset, required this.onRange});

  final ShippingPeriod period;
  final PeriodPreset preset;
  final ValueChanged<PeriodPreset> onPreset;
  final void Function(DateTime from, DateTime to) onRange;

  @override
  Widget build(BuildContext context) {
    final p = period;
    final diff = p.difference;
    final (verdict, color) = switch (diff) {
      > 0 => ('Over by ${fmt(diff)} — printed more than shipped', C.primary),
      < 0 => ('Under by ${fmt(-diff)} — shipped more than printed', C.danger),
      _ => ('Even — printed what was shipped', C.success),
    };

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Printed vs shipped', icon: Icons.compare_arrows, color: C.primary),
          PeriodChips(preset: preset, from: p.from, to: p.to, onPreset: onPreset, onRange: onRange),
          SizedBox(height: 16.r),
          if (p.days.isEmpty)
            Tile(child: Text('Nothing printed or shipped in this period.', style: sans(14, color: C.onVariant)))
          else ...[
            Pair(
              Metric(label: 'Printed', icon: Icons.qr_code_2, value: fmt(p.printed), valueColor: C.primary),
              Metric(label: 'Shipped', icon: Icons.local_shipping_outlined, value: fmt(p.shipped), valueColor: C.success),
            ),
            SizedBox(height: 12.r),
            Tile(
              color: color.withValues(alpha: 0.15),
              child: Row(children: [
                Icon(diff < 0 ? Icons.trending_down : Icons.trending_up, color: color, size: 22.r),
                SizedBox(width: 10.r),
                Expanded(child: Text(verdict, style: sans(15, weight: FontWeight.w600, color: color))),
              ]),
            ),
            if (p.days.length > 1 && p.days.length <= 31) ...[
              SizedBox(height: 16.r),
              SizedBox(height: 110.r, child: CustomPaint(size: Size.infinite, painter: _PairBarsPainter(p.days, gap: 6.r, radius: 2.r))),
              SizedBox(height: 6.r),
              Row(children: [
                Text(fmtDate(p.days.first.date), style: mono(11, color: C.onVariant)),
                const Spacer(),
                _Legend(color: _printedColor, label: 'printed'),
                SizedBox(width: 10.r),
                const _Legend(color: C.success, label: 'shipped'),
                const Spacer(),
                Text(fmtDate(p.days.last.date), style: mono(11, color: C.onVariant)),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10.r, height: 10.r, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2.r))),
        SizedBox(width: 4.r),
        Text(label, style: mono(11, color: C.onVariant)),
      ]);
}

/// Two bars per day: printed (blue) and shipped (green).
class _PairBarsPainter extends CustomPainter {
  _PairBarsPainter(this.days, {required this.gap, required this.radius});

  final List<ShipDay> days;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final top = days.map((d) => math.max(d.printed ?? 0, d.shipped ?? 0)).fold(1, math.max).toDouble();
    final slot = (size.width - gap * (days.length - 1)) / days.length;
    final bar = slot / 2;
    final printed = Paint()..color = _printedColor;
    final shipped = Paint()..color = C.success;

    void draw(double x, int value, Paint paint) {
      final h = size.height * value / top;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, bar, h), topLeft: Radius.circular(radius), topRight: Radius.circular(radius)),
        paint,
      );
    }

    for (var i = 0; i < days.length; i++) {
      final x = i * (slot + gap);
      draw(x, days[i].printed ?? 0, printed);
      draw(x + bar, days[i].shipped ?? 0, shipped);
    }
  }

  @override
  bool shouldRepaint(_PairBarsPainter old) => old.days != days;
}
