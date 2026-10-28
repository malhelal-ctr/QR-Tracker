import 'camera_probe_io.dart' if (dart.library.js_interop) 'camera_probe_web.dart' as impl;

/// Browser camera permission, as reported by the Permissions API.
enum CameraPermission { granted, prompt, denied, unknown }

/// What the device / browser allows for camera scanning. Always all-clear in the Android app.
class CameraEnv {
  const CameraEnv({
    this.secure = true,
    this.hasCameraApi = true,
    this.nativeDetector = true,
    this.online = true,
    this.permission = CameraPermission.unknown,
    this.web = false,
  });

  /// https:// or localhost; browsers block the camera everywhere else.
  final bool secure;

  /// navigator.mediaDevices exists (missing on insecure pages and very old browsers).
  final bool hasCameraApi;

  /// Browser has a built-in QR reader; without it the reader library is downloaded on first use.
  final bool nativeDetector;
  final bool online;
  final CameraPermission permission;
  final bool web;
}

Future<CameraEnv> probeCamera() => impl.probeCamera();

/// Asks for camera access (browser prompt) and releases the camera right away. True when allowed.
Future<bool> requestCameraAccess() => impl.requestCameraAccess();
