import 'camera_probe.dart';

// Android: the scanner asks for the permission itself when the camera starts.
Future<CameraEnv> probeCamera() async => const CameraEnv();

Future<bool> requestCameraAccess() async => true;
