import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../model/daily_log_state.dart';

/// Switch between the Log tab (morning entry + recent days) and the History tab.
class LogTabs extends StatelessWidget {
  const LogTabs({super.key, required this.tab, required this.historyCount, required this.onChanged});

  final LogTab tab;
  final int historyCount;
  final ValueChanged<LogTab> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: SegmentedButton<LogTab>(
      segments: [
        ButtonSegment(
          value: LogTab.log,
          icon: Icon(Icons.edit_calendar_outlined, size: 18.r),
          label: const Text('Daily log'),
        ),
        ButtonSegment(
          value: LogTab.history,
          icon: Icon(Icons.history, size: 18.r),
          label: Text('History ($historyCount)'),
        ),
        ButtonSegment(
          value: LogTab.printer,
          icon: Icon(Icons.print_outlined, size: 18.r),
          label: const Text('Printer'),
        ),
      ],
      selected: {tab},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: C.lowest,
        selectedBackgroundColor: C.primaryContainer,
        selectedForegroundColor: Colors.white,
        foregroundColor: C.onVariant,
        side: const BorderSide(color: C.outlineVariant),
        textStyle: sans(14, weight: FontWeight.w600),
        minimumSize: Size.fromHeight(48.r),
      ),
    ),
  );
}
