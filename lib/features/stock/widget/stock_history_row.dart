import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// One stock log entry; swipe left to delete.
class StockHistoryRow extends StatelessWidget {
  const StockHistoryRow({super.key, required this.move, required this.confirmDelete, required this.onDelete});

  final StockMove move;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (label, icon, pill, kind) = switch (move.type) {
      StockMoveType.received => ('Delivery received', Icons.local_shipping_outlined, '+${fmt(move.qty)}', PillKind.success),
      StockMoveType.waste => ('Waste', Icons.delete_outline, '−${fmt(move.qty)}', PillKind.danger),
      StockMoveType.count => ('Stock count', Icons.fact_check_outlined, '= ${fmt(move.qty)}', PillKind.info),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 10.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Dismissible(
          key: ValueKey(move.ts),
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
          child: Container(
            color: C.container,
            padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
            child: Row(children: [
              IconTile(icon, size: 40.r, iconColor: switch (kind) { PillKind.success => C.success, PillKind.danger => C.danger, _ => C.primary }),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: sans(17, weight: FontWeight.w600)),
                    SizedBox(height: 2.r),
                    Text('${fmtDay(move.date)}${move.note.isEmpty ? '' : ' · ${move.note}'}', style: mono(13, color: C.onVariant)),
                  ],
                ),
              ),
              Pill(pill, kind: kind, solid: kind != PillKind.info),
            ]),
          ),
        ),
      ),
    );
  }
}
