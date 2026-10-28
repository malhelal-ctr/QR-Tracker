import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/camera_probe.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_widgets.dart';
import '../widget/camera_check_panel.dart';
import '../widget/invert_toggle.dart';
import '../widget/manual_entry.dart';
import '../widget/viewfinder.dart';

/// Reads one code (camera or typed) and closes, returning it. Nothing is recorded here.
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key, required this.title, required this.hint});

  final String title;

  /// Short instruction above the camera.
  final String hint;

  /// Opens the page; resolves to the code, or null when closed without one.
  static Future<String?> open(BuildContext context, {required String title, required String hint}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => ScanCodePage(title: title, hint: hint)));

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  bool _invert = false;
  MobileScannerController? _controller = _makeController(false);
  CameraEnv? _env;

  /// Set once a code is returned, so a second read can't pop the page twice.
  bool _done = false;

  static MobileScannerController _makeController(bool invert) =>
      MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates, invertImage: invert);

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final env = await probeCamera();
    if (mounted) setState(() => _env = env);
  }

  /// One camera controller at a time: the old one is removed and disposed before the new one starts.
  Future<void> _restartCamera() async {
    final old = _controller;
    setState(() => _controller = null);
    await WidgetsBinding.instance.endOfFrame;
    await old?.dispose();
    if (mounted) setState(() => _controller = _makeController(_invert));
  }

  Future<void> _recheck() async {
    await _check();
    if (mounted) await _restartCamera();
  }

  Future<void> _allow() async {
    await requestCameraAccess();
    if (mounted) await _recheck();
  }

  void _setInvert(bool value) {
    _invert = value;
    unawaited(_restartCamera());
  }

  void _finish(String code) {
    final c = code.trim();
    if (_done || c.isEmpty) return;
    _done = true;
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title, style: sans(18, weight: FontWeight.w700)), backgroundColor: C.surface),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600.r),
            child: ListView(
              padding: EdgeInsets.all(16.r),
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12.r),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: C.onVariant),
                    SizedBox(width: 10.r),
                    Expanded(child: Text(widget.hint, style: sans(14, color: C.onVariant))),
                  ]),
                ),
                CameraCheckPanel(env: _env, controller: _controller, onAllow: _allow, onRecheck: _recheck),
                Viewfinder(
                  key: _controller == null ? null : GlobalObjectKey(_controller!),
                  controller: _controller,
                  height: 320.r,
                  onCode: _finish,
                ),
                // browsers can't invert the camera image (the scanner ignores the setting on the web)
                InvertToggle(value: _invert, onChanged: kIsWeb ? null : _setInvert),
                SizedBox(height: 16.r),
                ManualEntry(onSubmit: _finish),
                Panel(
                  color: C.high,
                  padding: EdgeInsets.all(12.r),
                  child: Text('Nothing is saved until you confirm the counter on the next step.', style: sans(13, color: C.onVariant)),
                ),
              ],
            ),
          ),
        ),
      );
}
