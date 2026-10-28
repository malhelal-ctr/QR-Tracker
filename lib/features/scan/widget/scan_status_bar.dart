import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';

/// Camera status (from the live controller state), scans this session and the torch toggle.
class ScanStatusBar extends StatelessWidget {
  const ScanStatusBar({super.key, required this.controller, required this.scanCount});

  /// Null while the camera is being swapped.
  final MobileScannerController? controller;

  /// Codes recorded since the Scan screen was opened.
  final int scanCount;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return Panel(
      padding: EdgeInsets.fromLTRB(16.r, 8.r, 8.r, 8.r),
      child: controller == null
          ? _row('Starting camera…', C.onVariant, null)
          : ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, state, _) {
                final (label, color) = switch (state) {
                  _ when state.error != null => ('Camera unavailable', C.danger),
                  _ when state.isRunning => ('Scanning continuously', C.success),
                  _ => ('Starting camera…', C.onVariant),
                };
                return _row(label, color, state.torchState == TorchState.unavailable ? null : _torch(controller, state.torchState == TorchState.on));
              },
            ),
    );
  }

  Widget _row(String label, Color color, Widget? torch) => Row(children: [
        Dot(color: color),
        SizedBox(width: 10.r),
        Expanded(child: MicroLabel(label, color: color)),
        if (scanCount > 0) ...[Pill('$scanCount ${scanCount == 1 ? 'SCAN' : 'SCANS'}', kind: PillKind.info), SizedBox(width: 8.r)],
        torch ?? SizedBox(height: 40.r),
      ]);

  Widget _torch(MobileScannerController controller, bool on) => TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: on ? C.successContainer : C.high,
          foregroundColor: on ? C.onSuccessContainer : C.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        ),
        onPressed: controller.toggleTorch,
        icon: Icon(on ? Icons.flashlight_on : Icons.flashlight_off, size: 20.r),
        label: Text(on ? 'TORCH: ON' : 'TORCH: OFF', style: mono(13, weight: FontWeight.w700)),
      );
}
