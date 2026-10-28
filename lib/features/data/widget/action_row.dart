import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Icon tile + title/subtitle + chevron. [standalone] wraps it in its own panel.
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconBg = C.high,
    this.iconColor = C.primary,
    this.busy = false,
    this.standalone = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconBg;
  final Color iconColor;
  final bool busy;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(children: [
          busy
              ? SizedBox.square(dimension: 48.r, child: Padding(padding: EdgeInsets.all(12.r), child: CircularProgressIndicator(strokeWidth: 2.5.r)))
              : IconTile(icon, color: iconBg, iconColor: iconColor, size: (standalone ? 52 : 44).r),
          SizedBox(width: 14.r),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sans(18, weight: FontWeight.w600)),
                SizedBox(height: 2.r),
                Text(subtitle, style: sans(14, color: C.onVariant)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: C.onVariant),
        ]),
      ),
    );
    return standalone ? Panel(padding: EdgeInsets.zero, child: Material(type: MaterialType.transparency, child: row)) : row;
  }
}
