import 'package:flutter/material.dart';

import '../../../core/data/printer_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// One printer reading with what it printed since the one before; swipe left to delete.
class PrinterRow extends StatelessWidget {
  const PrinterRow({super.key, required this.step, required this.confirmDelete, required this.onDelete});

  final PrinterStep step;
  final Future<bool> Function() confirmDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = step.reading;
    final detail = [
      'Counter ${fmt(r.value)}',
      if (r.reset) 'after reset',
      'entered ${fmtTime(r.ts)}',
      if (r.note.isNotEmpty) r.note,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: 10.r),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Dismissible(
          key: ValueKey('printer-${r.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => confirmDelete(),
          onDismissed: (_) => onDelete(),
          background: Container(
            color: C.dangerContainer,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 24.r),
            child: const Icon(Icons.delete_outline, color: C.onDangerContainer),
          ),
          child: Container(
            color: C.container,
            padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 14.r),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtDay(r.date), style: sans(18, weight: FontWeight.w600)),
                  SizedBox(height: 4.r),
                  Text(detail, style: mono(13, color: C.onVariant)),
                ]),
              ),
              SizedBox(width: 8.r),
              switch (step) {
                PrinterStep(printed: final p?) => Pill('+${fmt(p)}', kind: PillKind.success, solid: true),
                PrinterStep(gap: PrinterGap.wentDown) => const Pill('COUNTER WENT DOWN', kind: PillKind.danger),
                _ => const Pill('FIRST READING'),
              },
            ]),
          ),
        ),
      ),
    );
  }
}
