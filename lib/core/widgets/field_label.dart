import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 8.r),
        child: Text(text.toUpperCase(), style: sans(13, weight: FontWeight.w700, spacing: 0.8, color: C.onVariant)),
      );
}
