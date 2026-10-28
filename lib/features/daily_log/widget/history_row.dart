import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// One logged day with its +/- against target; tap to edit, swipe left to delete.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.day,
    required this.target,
    required this.onTap,
    required this.confirmDelete,
    required this.onDelete,
    this.selected = false,
  });

  final Day day;

  /// The day's own target, else the default daily target.
  final int? target;

  /// True while this day is loaded into the form for editing.
  final bool selected;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final diff = day.counter != null && target != null ? day.counter! - target! : null;
    final isToday = day.date == ymd(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: 10.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Dismissible(
          key: ValueKey(day.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => confirmDelete(),
          onDismissed: (_) => onDelete(),
          background: Container(
            color: C.dangerContainer,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline, color: C.onDangerContainer),
                Text(
                  'DELETE',
                  style: mono(12, weight: FontWeight.w700, color: C.onDangerContainer),
                ),
              ],
            ),
          ),
          child: Material(
            color: selected ? C.high : C.container,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: selected ? BorderSide(color: C.primary, width: 2.r) : BorderSide.none,
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(fmtDay(day.date), style: sans(18, weight: FontWeight.w600)),
                              if (isToday) ...[
                                SizedBox(width: 8.r),
                                Text(
                                  'TODAY',
                                  style: mono(11, weight: FontWeight.w700, spacing: 1, color: C.onVariant),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4.r),
                          Text(
                            // "*" marks a target set for this day only
                            'Target ${fmt(target)}${day.target != null ? '*' : ''} · Printed ${fmt(day.counter)}${day.fromPrinter ? ' (printer)' : ''}${day.note.isEmpty ? '' : ' · ${day.note}'}',
                            style: mono(14, color: C.onVariant),
                          ),
                        ],
                      ),
                    ),
                    if (diff != null)
                      Pill(fmtSigned(diff), kind: diff >= 0 ? PillKind.success : PillKind.danger, solid: true)
                    else
                      Text('—', style: mono(16, color: C.onVariant)),
                    SizedBox(width: 8.r),
                    Icon(Icons.edit_outlined, size: 18.r, color: C.onVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
