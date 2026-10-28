import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class NotInListCard extends StatelessWidget {
  const NotInListCard({super.key, required this.code, required this.scannedAt});

  final String code;
  final int scannedAt;

  @override
  Widget build(BuildContext context) => Panel(
        color: C.dangerContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: C.onDangerContainer, size: 30.r),
              SizedBox(width: 10.r),
              Expanded(child: Text('Not in the list', style: sans(22, weight: FontWeight.w700, color: C.onDangerContainer))),
              Text(fmtClock(scannedAt), style: mono(13, weight: FontWeight.w600, color: C.onDangerContainer)),
            ]),
            SizedBox(height: 8.r),
            Text('This code is not in the imported QR list. Check that you imported the right file.', style: sans(15, color: C.onDangerContainer)),
            SizedBox(height: 12.r),
            Tile(
              color: Colors.black.withValues(alpha: 0.25),
              child: SelectableText(code, style: mono(16, weight: FontWeight.w700, color: C.onDangerContainer)),
            ),
          ],
        ),
      );
}
