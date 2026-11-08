import 'package:flutter/material.dart';

import '../../../core/data/month_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// The month as a calendar: each day shows what was printed and how far above / below target.
/// Tap a day to log or edit it; long-press to mark it as a day off (or a working day again).
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key, required this.summary, required this.onTap, required this.onToggleOff, this.selected});

  final MonthSummary summary;
  final String? selected;
  final ValueChanged<String> onTap;
  final void Function(String date, bool off) onToggleOff;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final firstDow = loc.firstDayOfWeekIndex; // 0 = Sunday
    // DateTime.weekday: 1 = Monday … 7 = Sunday → 0 = Sunday … 6 = Saturday
    final lead = (summary.days.first.date.weekday % 7 - firstDow + 7) % 7;
    final headers = [for (var i = 0; i < 7; i++) loc.narrowWeekdays[(firstDow + i) % 7]];
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in summary.days)
        _DayCell(
          day: d,
          today: d.date == summary.today,
          selected: d.key == selected,
          onTap: () => onTap(d.key),
          onLongPress: () => onToggleOff(d.key, !d.off),
        ),
    ];

    return Panel(
      padding: EdgeInsets.all(10.r),
      child: Column(
        children: [
          Row(children: [
            for (final h in headers)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 6.r),
                  child: Text(h, textAlign: TextAlign.center, style: mono(12, weight: FontWeight.w700, color: C.onVariant)),
                ),
              ),
          ]),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth / 7;
            return Wrap(children: [for (final c in cells) SizedBox(width: w, height: (w * 0.85).clamp(68.r, 100.r), child: c)]);
          }),
          SizedBox(height: 8.r),
          Text('Tap a day to log it · long-press to switch it between day off and working day', style: sans(12, color: C.onVariant)),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.today, required this.selected, required this.onTap, required this.onLongPress});

  final MonthDay day;
  final bool today;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final diff = day.diff;
    final warn = (day.gap ?? 0) != 0;
    final future = !day.counted;
    final bg = selected
        ? C.high
        : day.off
            ? C.lowest
            : day.missing
                ? C.dangerContainer.withValues(alpha: 0.18)
                : C.low;

    final (String? status, Color statusColor) = switch (day) {
      _ when day.off && day.printed == null => (day.holiday?.toUpperCase() ?? 'OFF', day.holiday == null ? C.outline : C.warning),
      _ when day.missing => ('MISSING', C.danger),
      _ when diff != null => (fmtSignedCompact(diff), diff >= 0 ? C.success : C.danger),
      _ when future && day.target != null => (fmtCompact(day.target), C.outline),
      _ => (null, C.outline),
    };

    return Padding(
      padding: EdgeInsets.all(2.r),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: EdgeInsets.all(5.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              border: selected
                  ? Border.all(color: C.primary, width: 2.r)
                  : today
                      ? Border.all(color: C.outline, width: 1.r)
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${day.date.day}', style: mono(12, weight: FontWeight.w700, color: today ? C.primary : C.onVariant)),
                  const Spacer(),
                  if (warn) Icon(Icons.warning_amber_rounded, size: 13.r, color: C.warning),
                  if (day.day?.note.isNotEmpty ?? false) Icon(Icons.sticky_note_2_outlined, size: 12.r, color: C.onVariant),
                ]),
                // scales down in a small cell instead of overflowing
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (day.printed != null) Text(fmtCompact(day.printed), style: mono(15, weight: FontWeight.w700, height: 1.15)),
                          if (status != null) Text(status, style: mono(11, weight: FontWeight.w700, color: statusColor, height: 1.15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
