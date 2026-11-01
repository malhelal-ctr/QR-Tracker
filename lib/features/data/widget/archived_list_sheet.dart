import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import 'action_row.dart';

/// Bottom sheet with what an archived list reached, and its files to export.
class ArchivedListSheet extends StatelessWidget {
  const ArchivedListSheet({super.key, required this.list, required this.onExportCodes, required this.onExportScans});

  final ArchivedList list;
  final VoidCallback onExportCodes;
  final VoidCallback onExportScans;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.r, 0.r, 16.r, 16.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MicroLabel('Archived list', icon: Icons.history, color: C.primary),
              SizedBox(height: 8.r),
              Text(list.fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: mono(22, weight: FontWeight.w700)),
              SizedBox(height: 4.r),
              Text(
                '${list.importedAt == null ? '' : 'Imported ${fmtTime(list.importedAt!)} · '}archived ${fmtTime(list.archivedAt)}',
                style: sans(14, color: C.onVariant),
              ),
              SizedBox(height: 12.r),
              Pair(
                Metric(label: 'Reached', value: '#${fmt(list.printed)}', caption: 'of ${fmt(list.total)} codes', color: C.lowest),
                Metric(label: 'Daily log', value: fmt(list.logged), caption: 'printed while in use', color: C.lowest),
              ),
              SizedBox(height: 12.r),
              Panel(
                padding: EdgeInsets.symmetric(vertical: 4.r),
                child: Column(children: [
                  ActionRow(icon: Icons.qr_code_2, title: 'QR list (CSV)', subtitle: '${fmt(list.total)} codes in print order', onTap: onExportCodes),
                  Divider(indent: 16.r, endIndent: 16.r),
                  ActionRow(icon: Icons.table_rows_outlined, title: 'Scans (CSV)', subtitle: '${fmt(list.scans.length)} scans with time and print position', onTap: onExportScans),
                ]),
              ),
            ],
          ),
        ),
      );
}
