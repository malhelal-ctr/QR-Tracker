import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'camera_probe.dart';

Future<CameraEnv> probeCamera() async {
  final navigator = web.window.navigator;
  final hasCameraApi = (navigator as JSObject).getProperty<JSAny?>('mediaDevices'.toJS) != null;
  return CameraEnv(
    web: true,
    secure: web.window.isSecureContext,
    hasCameraApi: hasCameraApi,
    nativeDetector: globalContext.has('BarcodeDetector'),
    online: navigator.onLine,
    permission: await _permission(navigator),
  );
}

/// Firefox and older Safari don't support querying the camera permission: unknown there.
Future<CameraPermission> _permission(web.Navigator navigator) async {
  try {
    if ((navigator as JSObject).getProperty<JSAny?>('permissions'.toJS) == null) return CameraPermission.unknown;
    final status = await navigator.permissions.query({'name': 'camera'}.jsify()! as JSObject).toDart;
    return switch (status.state) {
      'granted' => CameraPermission.granted,
      'denied' => CameraPermission.denied,
      'prompt' => CameraPermission.prompt,
      _ => CameraPermission.unknown,
    };
  } catch (_) {
    return CameraPermission.unknown;
  }
}

Future<bool> requestCameraAccess() async {
  try {
    final stream = await web.window.navigator.mediaDevices.getUserMedia(web.MediaStreamConstraints(video: true.toJS)).toDart;
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}
