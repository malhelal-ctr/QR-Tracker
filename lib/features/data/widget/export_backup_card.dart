import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import 'action_row.dart';

class ExportBackupCard extends StatelessWidget {
  const ExportBackupCard({super.key, required this.onExportLog, required this.onExportScans, required this.onExportStock, required this.onBackup, required this.onRestore});

  final VoidCallback onExportLog;
  final VoidCallback onExportScans;
  final VoidCallback onExportStock;
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.symmetric(vertical: 4.r),
        child: Column(children: [
          ActionRow(icon: Icons.download, title: 'Daily log (CSV)', subtitle: 'Date, target, printed and difference per day', onTap: onExportLog),
          Divider(indent: 16.r, endIndent: 16.r),
          ActionRow(icon: Icons.table_rows_outlined, title: 'Scan history (CSV)', subtitle: 'Every scan with time and print position', onTap: onExportScans),
          Divider(indent: 16.r, endIndent: 16.r),
          ActionRow(icon: Icons.inventory_2_outlined, title: 'Lid stock (CSV)', subtitle: 'Deliveries, waste and stock counts', onTap: onExportStock),
          Divider(indent: 16.r, endIndent: 16.r),
          ActionRow(icon: Icons.backup_outlined, title: 'Full backup', subtitle: 'QR list, log, scans and stock in one file (JSON)', onTap: onBackup),
          Divider(indent: 16.r, endIndent: 16.r),
          ActionRow(
            icon: Icons.settings_backup_restore,
            iconColor: C.success,
            title: 'Restore backup',
            subtitle: 'Load a backup file — replaces current data',
            onTap: onRestore,
          ),
        ]),
      );
}
