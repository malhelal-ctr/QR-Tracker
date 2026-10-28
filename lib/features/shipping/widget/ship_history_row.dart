import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// One day: printed (from the daily log) vs shipped, with the difference. Tap to edit, swipe left to delete.
class ShipHistoryRow extends StatelessWidget {
  const ShipHistoryRow({
    super.key,
    required this.day,
    required this.onTap,
    required this.confirmDelete,
    required this.onDelete,
    this.selected = false,
  });

  final Day day;
  final bool selected;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final diff = (day.counter ?? 0) - (day.shipped ?? 0);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Dismissible(
          key: ValueKey('ship-${day.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => confirmDelete(),
          onDismissed: (_) => onDelete(),
          background: Container(
            color: C.dangerContainer,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24.r),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.delete_outline, color: C.onDangerContainer),
              Text('DELETE', style: mono(12, weight: FontWeight.w700, color: C.onDangerContainer)),
            ]),
          ),
          child: Material(
            color: selected ? C.high : C.container,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: selected ? BorderSide(color: C.success, width: 2.r) : BorderSide.none,
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fmtDay(day.date), style: sans(18, weight: FontWeight.w600)),
                      SizedBox(height: 4.r),
                      Text('Printed ${fmt(day.counter)} · Shipped ${fmt(day.shipped)}', style: mono(14, color: C.onVariant)),
                    ]),
                  ),
                  Pill(fmtSigned(diff), kind: diff >= 0 ? PillKind.info : PillKind.danger, solid: diff < 0),
                  SizedBox(width: 8.r),
                  Icon(Icons.edit_outlined, size: 18.r, color: C.onVariant),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
