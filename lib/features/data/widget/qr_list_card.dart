import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/product_field.dart';
import '../model/data_state.dart';

class QrListCard extends StatelessWidget {
  const QrListCard({super.key, required this.batch, required this.onEditProduct});

  final MachineListState batch;
  final VoidCallback onEditProduct;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconTile(Icons.description_outlined, size: 52.r),
              SizedBox(width: 14.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.machine.label, style: sans(13, weight: FontWeight.w700, color: C.primary)),
                    Text(batch.fileName.isEmpty ? 'No file imported' : batch.fileName, overflow: TextOverflow.ellipsis, style: mono(18, weight: FontWeight.w700)),
                    SizedBox(height: 2.r),
                    Text(
                      batch.importedAt == null ? 'No active batch' : '${fmt(batch.codeCount)} codes · ${fmt(batch.scanCount)} scans · imported ${fmtTime(batch.importedAt!)}',
                      style: sans(14, color: C.onVariant),
                    ),
                  ],
                ),
              ),
            ]),
            if (batch.hasList) ...[
              SizedBox(height: 12.r),
              ProductTile(product: batch.product, onTap: onEditProduct),
              SizedBox(height: 12.r),
              batch.complete
                  ? const Pill('COMPLETED', kind: PillKind.info, icon: Icons.task_alt)
                  : const Pill('ACTIVE LIST', kind: PillKind.success, icon: Icons.check_circle_outline),
            ],
          ],
        ),
      );
}
