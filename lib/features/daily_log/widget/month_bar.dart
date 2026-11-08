import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../model/daily_log_state.dart';

/// Month switcher (◀ month ▶, tap the name to pick one) and the calendar / list toggle.
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.month,
    required this.view,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onView,
  });

  final DateTime month;
  final LogView view;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onPick;
  final ValueChanged<LogView> onView;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'PICK ANY DAY OF THE MONTH',
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final toggle = SegmentedButton<LogView>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        selectedBackgroundColor: C.high,
        selectedForegroundColor: C.primary,
        foregroundColor: C.onVariant,
        side: const BorderSide(color: C.outlineVariant),
      ),
      segments: [
        ButtonSegment(value: LogView.calendar, icon: Icon(Icons.calendar_view_month, size: 20.r), tooltip: 'Calendar'),
        ButtonSegment(value: LogView.list, icon: Icon(Icons.table_rows_outlined, size: 20.r), tooltip: 'Table'),
        ButtonSegment(value: LogView.machine, icon: Icon(Icons.precision_manufacturing_outlined, size: 20.r), tooltip: 'Machine total history'),
      ],
      selected: {view},
      onSelectionChanged: (s) => onView(s.first),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.r),
      child: Row(
        children: [
          IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left), tooltip: 'Previous month'),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: () => _pick(context),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.r, vertical: 4.r),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(fmtMonth(month), style: sans(22, weight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right), tooltip: 'Next month'),
          if (!isCurrent)
            TextButton(onPressed: () => onPick(now), child: Text('TODAY', style: mono(12, weight: FontWeight.w700, color: C.primary))),
          SizedBox(width: 8.r),
          toggle,
        ],
      ),
    );
  }
}
