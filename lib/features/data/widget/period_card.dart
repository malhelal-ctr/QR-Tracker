import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/data_state.dart';

class PeriodCard extends StatelessWidget {
  const PeriodCard({super.key, required this.state, required this.onPick, required this.onClear});

  final DataState state;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final daysLeft = state.daysLeft;
    return Panel(
      child: Column(
        children: [
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12.r),
            child: Row(children: [
              IconTile(Icons.event_outlined, size: 48.r),
              SizedBox(width: 14.r),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MicroLabel('Period end date'),
                    SizedBox(height: 2.r),
                    Text(state.periodEnd.isEmpty ? 'Not set — tap to choose' : fmtDay(state.periodEnd), style: sans(19, weight: FontWeight.w600)),
                  ],
                ),
              ),
              if (state.periodEnd.isNotEmpty)
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: C.high, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))),
                  icon: const Icon(Icons.close, color: C.onSurface),
                  onPressed: onClear,
                ),
            ]),
          ),
          SizedBox(height: 12.r),
          Row(children: [
            Expanded(child: Text('Used to work out how many codes per day are needed to finish on time.', style: sans(14, color: C.onVariant))),
            if (daysLeft != null) ...[
              SizedBox(width: 12.r),
              Pill(daysLeft > 0 ? '${fmt(daysLeft)} DAYS LEFT' : 'PERIOD ENDED', kind: daysLeft > 0 ? PillKind.success : PillKind.danger, icon: Icons.timelapse),
            ],
          ]),
        ],
      ),
    );
  }
}
