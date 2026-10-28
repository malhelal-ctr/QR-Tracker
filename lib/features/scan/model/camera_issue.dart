import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/camera_probe.dart';

/// Something stopping (or slowing) camera scanning, with how to fix it.
class CameraIssue {
  const CameraIssue(this.title, this.fix, {this.blocking = true, this.canAllow = false});

  final String title;
  final String fix;

  /// False for warnings: the camera may still work.
  final bool blocking;

  /// The "Allow camera" button can fix it.
  final bool canAllow;
}

/// Problems from the browser / device check and from the camera's own start error, most serious first.
List<CameraIssue> cameraIssues(CameraEnv? env, MobileScannerErrorCode? error) {
  final web = env?.web ?? false;
  final issues = <CameraIssue>[];

  if (env != null && !env.secure) {
    issues.add(const CameraIssue(
      'Page is not opened over https',
      'Browsers only allow the camera on https:// pages (or localhost on this PC). Open the app’s https:// address instead.',
    ));
  } else if (env != null && !env.hasCameraApi) {
    issues.add(const CameraIssue('This browser can’t use the camera', 'Open the app in Chrome, Edge, or Safari on iOS 17 or later.'));
  }
  // an insecure page can't reach the camera at all, so its start error says nothing more
  if (issues.isNotEmpty) return issues;

  if (env?.permission == CameraPermission.denied || error == MobileScannerErrorCode.permissionDenied) {
    issues.add(CameraIssue(
      'Camera permission is blocked',
      web
          ? 'Tap the icon left of the address → Site settings (Permissions) → Camera → Allow, then tap Check again.'
          : 'Tap Allow camera. If nothing asks, open phone Settings → Apps → QR Tracker → Permissions → Camera → Allow, then come back.',
      canAllow: true,
    ));
  } else if (error == MobileScannerErrorCode.unsupported) {
    issues.add(const CameraIssue('No camera found', 'This device has no camera the app can use. Type the code below, or use a phone.'));
  } else if (error == MobileScannerErrorCode.genericError) {
    issues.add(const CameraIssue(
      'Camera couldn’t start',
      'Close other apps or browser tabs that use the camera, then tap Check again.',
    ));
  } else if (env?.permission == CameraPermission.prompt) {
    issues.add(const CameraIssue(
      'Camera permission needed',
      'Tap Allow camera and choose Allow when the browser asks.',
      blocking: false,
      canAllow: true,
    ));
  }

  if (env != null && web && !env.nativeDetector && !env.online) {
    issues.add(const CameraIssue(
      'Internet needed for the first scan',
      'This browser downloads its QR reader the first time it scans. Connect to the internet, then tap Check again.',
      blocking: false,
    ));
  }
  return issues;
}
