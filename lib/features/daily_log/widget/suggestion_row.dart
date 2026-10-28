import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// "Needed to finish on time: 1,755 [USE]".
class SuggestionRow extends StatelessWidget {
  const SuggestionRow({super.key, required this.suggested, required this.onUse});

  final int suggested;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) => Tile(
    color: C.high,
    padding: EdgeInsets.fromLTRB(12.r, 8.r, 8.r, 8.r),
    child: Row(
      children: [
        Icon(Icons.trending_up, color: C.success, size: 20.r),
        SizedBox(width: 8.r),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: sans(14),
              children: [
                const TextSpan(text: 'Needed to finish on time: '),
                TextSpan(
                  text: fmt(suggested),
                  style: mono(14, weight: FontWeight.w700, color: C.success),
                ),
              ],
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: C.successContainer,
            foregroundColor: C.onSuccessContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
          onPressed: onUse,
          icon: Icon(Icons.bolt, size: 18.r),
          label: Text('USE', style: mono(14, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
