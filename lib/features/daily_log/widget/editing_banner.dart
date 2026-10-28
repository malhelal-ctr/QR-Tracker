import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Shown above the form while a history entry is loaded into it.
class EditingBanner extends StatelessWidget {
  const EditingBanner({super.key, required this.date, required this.onNewEntry});

  /// yyyy-MM-dd of the day being edited.
  final String date;
  final VoidCallback onNewEntry;

  @override
  Widget build(BuildContext context) => Panel(
    color: C.primaryContainer.withValues(alpha: 0.35),
    padding: EdgeInsets.fromLTRB(16.r, 12.r, 12.r, 12.r),
    child: Row(
      children: [
        Icon(Icons.edit_outlined, color: C.primary, size: 22.r),
        SizedBox(width: 10.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editing ${fmtDay(date)}', style: sans(17, weight: FontWeight.w700)),
              Text('Change the values below and save. Clear a field to remove it.', style: sans(13, color: C.onVariant)),
            ],
          ),
        ),
        SizedBox(width: 8.r),
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: C.high,
            foregroundColor: C.onSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          onPressed: onNewEntry,
          icon: Icon(Icons.add, size: 18.r),
          label: Text('NEW ENTRY', style: mono(12, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
