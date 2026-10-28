import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/period.dart';
import '../utils/responsive.dart';

/// Period buttons (7 days, This week, This month, All) plus a button showing the range
/// that opens the date-range picker.
class PeriodChips extends StatelessWidget {
  const PeriodChips({super.key, required this.preset, required this.from, required this.to, required this.onPreset, required this.onRange});

  final PeriodPreset preset;
  final DateTime from;
  final DateTime to;
  final ValueChanged<PeriodPreset> onPreset;

  /// Called with the range picked in the date-range picker.
  final void Function(DateTime from, DateTime to) onRange;

  Future<void> _pick(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'Choose period',
    );
    if (range != null) onRange(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8.r, runSpacing: 8.r, children: [
        for (final (p, label) in const [
          (PeriodPreset.last7Days, '7 days'),
          (PeriodPreset.thisWeek, 'This week'),
          (PeriodPreset.thisMonth, 'This month'),
          (PeriodPreset.all, 'All'),
        ])
          _Chip(label: label, selected: preset == p, onTap: () => onPreset(p)),
        _Chip(label: '${_short(from)} – ${_short(to)}', icon: Icons.date_range, selected: preset == PeriodPreset.custom, onTap: () => _pick(context)),
      ]);

  static String _short(DateTime d) => '${_months[d.month - 1]} ${d.day}';
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? C.primaryContainer : C.high,
        borderRadius: BorderRadius.circular(8.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.r),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16.r, color: selected ? Colors.white : C.onVariant), SizedBox(width: 6.r)],
              Text(label, style: sans(13, weight: FontWeight.w600, color: selected ? Colors.white : C.onSurface)),
            ]),
          ),
        ),
      );
}
