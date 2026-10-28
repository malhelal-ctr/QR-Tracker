import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_widgets.dart';

class HistoryHeader extends StatelessWidget {
  const HistoryHeader({super.key, required this.count, this.title = 'History'});

  final int count;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: sans(22, weight: FontWeight.w700)),
        SizedBox(width: 10.r),
        Pill('$count ${count == 1 ? 'RECORD' : 'RECORDS'}'),
        const Spacer(),
        if (count > 0) ...[
          Icon(Icons.swipe_left_outlined, size: 16.r, color: C.onVariant),
          SizedBox(width: 4.r),
          Text('Swipe left to delete', style: mono(12, color: C.onVariant)),
        ],
      ]);
}
