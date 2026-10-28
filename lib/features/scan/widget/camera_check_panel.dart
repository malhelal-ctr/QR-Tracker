import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/camera_probe.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../model/camera_issue.dart';

/// Lists what stops the camera (https, permission, browser support, internet) with the fix for each,
/// plus Allow camera / Check again buttons. Hidden when everything is fine.
class CameraCheckPanel extends StatelessWidget {
  const CameraCheckPanel({super.key, required this.env, required this.controller, required this.onAllow, required this.onRecheck});

  /// Null until the first check finishes.
  final CameraEnv? env;

  /// Null while the camera is being swapped.
  final MobileScannerController? controller;
  final VoidCallback? onAllow;
  final VoidCallback? onRecheck;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _build(null);
    return ValueListenableBuilder<MobileScannerState>(valueListenable: controller, builder: (context, state, _) => _build(state.error?.errorCode));
  }

  Widget _build(MobileScannerErrorCode? error) {
    final issues = cameraIssues(env, error);
    if (issues.isEmpty) return const SizedBox.shrink();
    final blocking = issues.any((i) => i.blocking);
    final accent = blocking ? C.danger : C.warning;

    return Padding(
      padding: EdgeInsets.only(bottom: 16.r),
      child: Panel(
        color: C.high,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(blocking ? Icons.no_photography_outlined : Icons.photo_camera_outlined, color: accent),
              SizedBox(width: 10.r),
              Expanded(child: Text(blocking ? 'Camera can’t scan yet' : 'Before you scan', style: sans(17, weight: FontWeight.w700))),
            ]),
            for (final issue in issues) ...[
              SizedBox(height: 12.r),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: EdgeInsets.only(top: 6.r), child: Dot(color: issue.blocking ? C.danger : C.warning)),
                SizedBox(width: 10.r),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(issue.title, style: sans(15, weight: FontWeight.w600)),
                    SizedBox(height: 2.r),
                    Text(issue.fix, style: sans(14, color: C.onVariant)),
                  ]),
                ),
              ]),
            ],
            SizedBox(height: 16.r),
            Row(children: [
              if (issues.any((i) => i.canAllow)) ...[
                Expanded(child: BigButton(label: 'Allow camera', icon: Icons.videocam_outlined, height: 48.r, onPressed: onAllow)),
                SizedBox(width: 12.r),
              ],
              Expanded(child: BigButton(label: 'Check again', icon: Icons.refresh, style: BigButtonStyle.tonal, height: 48.r, onPressed: onRecheck)),
            ]),
          ],
        ),
      ),
    );
  }
}
