import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// Draws a fading green outline over [child] when it first appears.
/// Give it a new key for each new result to replay the flash.
class FlashOnChange extends StatefulWidget {
  const FlashOnChange({super.key, required this.child});

  final Widget child;

  @override
  State<FlashOnChange> createState() => _FlashOnChangeState();
}

class _FlashOnChangeState extends State<FlashOnChange> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..reverse(from: 1);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          // panels keep a 16 bottom margin; stop the outline at the card edge
          bottom: 16.r,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fade,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: C.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: C.success, width: 3.r),
                ),
              ),
            ),
          ),
        ),
      ]);
}
