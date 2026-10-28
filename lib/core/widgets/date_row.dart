import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/responsive.dart';
import 'app_widgets.dart';

/// Tappable date picker row: icon tile, micro label and the formatted date.
class DateRow extends StatelessWidget {
  const DateRow({super.key, required this.label, required this.date, required this.onTap, this.iconColor = C.primary, this.badge});

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final Color iconColor;
  final String? badge;

  @override
  Widget build(BuildContext context) => Material(
        color: C.low,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: Row(children: [
              IconTile(Icons.calendar_today_outlined, size: 40.r, iconColor: iconColor),
              SizedBox(width: 12.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MicroLabel(label),
                    SizedBox(height: 2.r),
                    Text(fmtDate(date), style: sans(19, weight: FontWeight.w600)),
                  ],
                ),
              ),
              if (badge != null) Pill(badge!) else const Icon(Icons.chevron_right, color: C.onVariant),
            ]),
          ),
        ),
      );
}
