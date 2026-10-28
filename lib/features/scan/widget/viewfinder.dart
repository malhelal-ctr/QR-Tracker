import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// Camera preview with green corner brackets, a crosshair and the aiming hint.
/// A null [controller] (camera being swapped) shows an empty frame.
class Viewfinder extends StatelessWidget {
  const Viewfinder({super.key, required this.controller, required this.onCode, this.height});

  final MobileScannerController? controller;
  final void Function(String code) onCode;

  /// Screen pixels; defaults to 360 design px.
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 16.r),
    height: height ?? 360.r,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: C.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (controller case final controller?)
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) onCode(value);
            },
            errorBuilder: (context, error) => const _CameraError(),
          )
        else
          const ColoredBox(color: C.lowest),
        // the aiming frame and hint would cover the camera error message
        if (controller case final controller?)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, overlay) => state.error == null ? overlay! : const SizedBox.shrink(),
            child: _overlay(),
          )
        else
          _overlay(),
      ],
    ),
  );

  Widget _overlay() => Stack(
    fit: StackFit.expand,
    children: [
      const IgnorePointer(child: CustomPaint(painter: _FramePainter())),
      Positioned(
        left: 12.r,
        right: 12.r,
        bottom: 12.r,
        child: IgnorePointer(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 12.r),
            decoration: BoxDecoration(color: C.lowest.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8.r)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.center_focus_strong_outlined, size: 18.r, color: C.success),
                SizedBox(width: 8.r),
                Flexible(
                  child: Text('Point at the QR code the machine is printing', style: sans(14, color: C.onSurface)),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: C.lowest,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_photography_outlined, color: C.danger, size: 40.r),
            SizedBox(height: 12.r),
            Text('Camera unavailable', style: sans(17, weight: FontWeight.w700)),
            SizedBox(height: 4.r),
            // the reason and its fix are in the camera check panel above the viewfinder
            Text(
              'Follow the steps above, or type the code below.',
              textAlign: TextAlign.center,
              style: sans(14, color: C.onVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.62;
    final r = Rect.fromCenter(center: size.center(Offset.zero) - const Offset(0, 16), width: side, height: side);
    final bracket = Paint()
      ..color = C.success
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const l = 34.0;
    for (final (corner, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(corner, corner + Offset(l * dx, 0), bracket);
      canvas.drawLine(corner, corner + Offset(0, l * dy), bracket);
    }
    final c = r.center;
    final thin = Paint()
      ..color = C.success.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(c - Offset(r.width / 2, 0), c + Offset(r.width / 2, 0), thin);
    canvas.drawLine(c - Offset(0, r.height / 2), c + Offset(0, r.height / 2), thin);
    canvas.drawCircle(c, 5, Paint()..color = C.success);
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => false;
}
