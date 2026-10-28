import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/data_state.dart';

class QrListCard extends StatelessWidget {
  const QrListCard({super.key, required this.state});

  final DataState state;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconTile(Icons.description_outlined, size: 52.r),
              SizedBox(width: 14.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.fileName.isEmpty ? 'No file imported' : state.fileName, overflow: TextOverflow.ellipsis, style: mono(18, weight: FontWeight.w700)),
                    SizedBox(height: 2.r),
                    Text(
                      state.importedAt == null ? 'Import your list below' : '${fmt(state.codeCount)} codes · imported ${fmtTime(state.importedAt!)}',
                      style: sans(14, color: C.onVariant),
                    ),
                  ],
                ),
              ),
            ]),
            if (state.hasList) ...[
              SizedBox(height: 12.r),
              const Pill('ACTIVE LIST', kind: PillKind.success, icon: Icons.check_circle_outline),
            ],
          ],
        ),
      );
}
