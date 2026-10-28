import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class InvertToggle extends StatelessWidget {
  const InvertToggle({super.key, required this.value, required this.onChanged});

  final bool value;

  /// Null where inverting isn't possible (web browsers): the switch is off and explains why.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final available = onChanged != null;
    return Panel(
      padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 12.r),
      child: Row(children: [
        IconTile(Icons.contrast, size: 44.r),
        SizedBox(width: 12.r),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Light code on dark surface', style: sans(16, weight: FontWeight.w600, color: available ? null : C.onVariant)),
              Text(
                available ? 'Turn on if a laser-marked code won’t scan' : 'Not available in the browser. Use the Android app for light-on-dark codes, or type the code.',
                style: sans(13, color: C.onVariant),
              ),
            ],
          ),
        ),
        Switch(value: available && value, onChanged: onChanged),
      ]),
    );
  }
}
