import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Switches the Scan page between checking codes (off) and Log by scan (on).
class LogModeToggle extends StatelessWidget {
  const LogModeToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 16.r),
        child: Panel(
          color: value ? C.primaryContainer.withValues(alpha: 0.35) : null,
          padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 12.r),
          child: Row(children: [
            IconTile(Icons.edit_calendar_outlined, size: 44.r),
            SizedBox(width: 12.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log by scan', style: sans(16, weight: FontWeight.w600)),
                  Text(
                    value ? 'On: each scan opens the counter to log for the day' : 'Off: scans only check codes (any order)',
                    style: sans(13, color: C.onVariant),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ]),
        ),
      );
}
