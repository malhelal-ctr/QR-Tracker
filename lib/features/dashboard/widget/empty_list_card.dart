import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class EmptyListCard extends StatelessWidget {
  const EmptyListCard({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.all(24.r),
        child: Column(
          children: [
            IconTile(Icons.qr_code_2, size: 64.r),
            SizedBox(height: 16.r),
            Text('No QR list yet', style: sans(22, weight: FontWeight.w700)),
            SizedBox(height: 8.r),
            Text(
              'Import the CSV or Excel file with your QR codes (one column, in print order).',
              textAlign: TextAlign.center,
              style: sans(15, color: C.onVariant),
            ),
            SizedBox(height: 20.r),
            BigButton(label: 'Import QR list', icon: Icons.upload_file, onPressed: onImport),
          ],
        ),
      );
}
