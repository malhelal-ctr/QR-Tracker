import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/period.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/period_chips.dart';
import '../model/production_summary.dart';

/// Daily log totals for a chosen period: preset chips, a date-range button, totals and a daily bar chart.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.summary, required this.preset, required this.onPreset, required this.onRange});

  final ProductionSummary summary;
  final PeriodPreset preset;
  final ValueChanged<PeriodPreset> onPreset;
  final void Function(DateTime from, DateTime to) onRange;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final best = s.bestDay;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Production summary', icon: Icons.bar_chart, color: C.primary),
          PeriodChips(preset: preset, from: s.from, to: s.to, onPreset: onPreset, onRange: onRange),
          SizedBox(height: 16.r),
          if (s.days.isEmpty)
            Tile(child: Text('No days logged in this period.', style: sans(14, color: C.onVariant)))
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: fmt(s.printed), style: mono(40, weight: FontWeight.w700, height: 1)),
                    TextSpan(text: s.hasTarget ? ' / ${fmt(s.target)}' : ' printed', style: sans(17, color: C.onVariant)),
                  ])),
                ),
              ),
              if (s.hasTarget) Pill(fmtSigned(s.difference), kind: s.difference >= 0 ? PillKind.success : PillKind.danger, solid: true),
            ]),
            SizedBox(height: 4.r),
            Text(s.hasTarget ? 'Printed vs target, ${_long(s.from)} – ${_long(s.to)}' : 'Printed, ${_long(s.from)} – ${_long(s.to)}',
                style: sans(13, color: C.onVariant)),
            SizedBox(height: 14.r),
            Pair(
              Metric(
                label: 'Days logged',
                value: fmt(s.days.length),
                caption: s.daysWithTarget == 0 ? null : '${s.goalMetDays} of ${s.daysWithTarget} met target',
                captionColor: s.goalMetDays == s.daysWithTarget ? C.success : null,
              ),
              Metric(
                label: 'Avg / day',
                value: fmt(s.average),
                caption: best == null ? null : 'Best ${fmtDate(best.date)} · ${fmt(best.printed)}',
              ),
            ),
            if (s.days.length > 1 && s.days.length <= 62) ...[
              SizedBox(height: 16.r),
              _DailyBars(days: s.days),
            ],
          ],
        ],
      ),
    );
  }

  static String _long(DateTime d) => fmtDate(d);
}

/// One bar per logged day (green when the target was met), with a tick at the day's target.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days});

  final List<SummaryDay> days;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 110.r, child: CustomPaint(painter: _BarsPainter(days, gap: days.length > 20 ? 2.r : 5.r, radius: 3.r, tick: 2.r))),
          SizedBox(height: 6.r),
          Row(children: [
            Text(fmtDate(days.first.date), style: mono(11, color: C.onVariant)),
            const Spacer(),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10.r, height: 2.r, color: C.onSurface),
              SizedBox(width: 4.r),
              Text('target', style: mono(11, color: C.onVariant)),
            ]),
            const Spacer(),
            Text(fmtDate(days.last.date), style: mono(11, color: C.onVariant)),
          ]),
        ],
      );
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.days, {required this.gap, required this.radius, required this.tick});

  final List<SummaryDay> days;
  final double gap;
  final double radius;
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final top = days.map((d) => math.max(d.printed, d.target ?? 0)).fold(1, math.max).toDouble();
    final width = (size.width - gap * (days.length - 1)) / days.length;
    final hit = Paint()..color = C.success;
    final miss = Paint()..color = const Color(0xFF3B5BDB);
    final noTarget = Paint()..color = C.outline;
    final target = Paint()
      ..color = C.onSurface
      ..strokeWidth = tick;

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final x = i * (width + gap);
      final h = size.height * d.printed / top;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, size.height - h, width, h), topLeft: Radius.circular(radius), topRight: Radius.circular(radius)),
        d.target == null ? noTarget : (d.goalMet ? hit : miss),
      );
      if (d.target case final t?) {
        final y = size.height - size.height * t / top;
        canvas.drawLine(Offset(x, y), Offset(x + width, y), target);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.days != days;
}
