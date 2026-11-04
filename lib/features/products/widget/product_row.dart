import 'package:flutter/material.dart';

import '../../../core/data/product_stats.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// One product with its totals; only a product nothing uses can be deleted.
class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.stats, required this.onRename, required this.onDelete});

  final ProductStats stats;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 10.r),
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(stats.name, style: sans(18, weight: FontWeight.w700))),
                if (stats.active) const Pill('ACTIVE', kind: PillKind.success),
                IconButton(onPressed: onRename, tooltip: 'Rename', icon: const Icon(Icons.edit_outlined, color: C.onVariant)),
                IconButton(
                  onPressed: stats.inUse ? null : onDelete,
                  tooltip: stats.inUse ? 'In use: rename it into another product instead' : 'Delete',
                  icon: Icon(Icons.delete_outline, color: stats.inUse ? C.outlineVariant : C.danger),
                ),
              ]),
              SizedBox(height: 8.r),
              Pair(
                Metric(label: 'Lists', value: fmt(stats.lists), caption: '${fmt(stats.codes)} codes', color: C.lowest),
                Metric(label: 'Printed', value: fmt(stats.printed), caption: '${fmt(stats.days)} days logged', color: C.lowest),
              ),
            ],
          ),
        ),
      );
}
