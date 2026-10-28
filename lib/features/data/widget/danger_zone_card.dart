import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

class DangerZoneCard extends StatelessWidget {
  const DangerZoneCard({super.key, required this.onErase});

  final VoidCallback onErase;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconTile(Icons.delete_forever_outlined, color: C.dangerContainer, iconColor: C.onDangerContainer, size: 52.r),
            SizedBox(width: 14.r),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Erase all data', style: sans(21, weight: FontWeight.w700, color: C.danger)),
                  SizedBox(height: 2.r),
                  Text('Deletes the QR list, scans, daily log and stock from this phone.', style: sans(14, color: C.onVariant)),
                ],
              ),
            ),
          ]),
          SizedBox(height: 16.r),
          BigButton(label: 'Erase all data', icon: Icons.delete_sweep_outlined, style: BigButtonStyle.danger, onPressed: onErase),
        ]),
      );
}
