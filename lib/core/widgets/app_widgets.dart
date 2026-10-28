import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

// Size parameters are screen pixels (already scaled with `.r`); defaults are design values scaled here.

/// App bar with the QR logo tile, app name and current screen.
class TrackerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TrackerAppBar(this.screen, {super.key});

  final String screen;

  @override
  Size get preferredSize => Size.fromHeight(68.r);

  @override
  Widget build(BuildContext context) => AppBar(
        toolbarHeight: 68.r,
        backgroundColor: C.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16.r,
        shape: const Border(bottom: BorderSide(color: C.low)),
        title: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(color: C.primaryContainer, borderRadius: BorderRadius.circular(10.r)),
              child: Icon(Icons.qr_code_2, color: Colors.white, size: 26.r),
            ),
            SizedBox(width: 12.r),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR TRACKER', style: sans(18, weight: FontWeight.w800, spacing: 0.6)),
                Text(screen, style: sans(13, weight: FontWeight.w500, color: C.onVariant)),
              ],
            ),
          ],
        ),
      );
}

/// Level-1 card: container surface with a hairline border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding, this.gradient, this.color});

  final Widget child;
  final EdgeInsets? padding;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: 16.r),
        padding: padding ?? EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? C.container) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: C.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: child,
      );
}

/// Inner metric tile.
class Tile extends StatelessWidget {
  const Tile({super.key, required this.child, this.color = C.low, this.padding});

  final Widget child;
  final Color color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? EdgeInsets.all(12.r),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12.r)),
        child: child,
      );
}

/// Uppercase micro label used above every reading.
class MicroLabel extends StatelessWidget {
  const MicroLabel(this.text, {super.key, this.icon, this.color = C.onVariant});

  final String text;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15.r, color: color), SizedBox(width: 6.r)],
          Flexible(child: Text(text.toUpperCase(), style: mono(11, weight: FontWeight.w700, spacing: 1, color: color))),
        ],
      );
}

/// Metric tile: micro label, big mono value, optional caption.
class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value, this.icon, this.caption, this.valueColor, this.captionColor, this.unit, this.color = C.low});

  final String label;
  final String value;
  final IconData? icon;
  final String? caption;
  final String? unit;
  final Color? valueColor;
  final Color? captionColor;
  final Color color;

  @override
  Widget build(BuildContext context) => Tile(
        color: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MicroLabel(label, icon: icon),
            SizedBox(height: 10.r),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: value, style: mono(34, weight: FontWeight.w700, color: valueColor ?? C.onSurface, height: 1)),
                if (unit != null) TextSpan(text: ' $unit', style: sans(14, color: C.onVariant)),
              ])),
            ),
            if (caption != null) ...[
              SizedBox(height: 6.r),
              Text(caption!, style: sans(13, color: captionColor ?? C.onVariant)),
            ],
          ],
        ),
      );
}

/// Two widgets side by side with the standard gutter.
class Pair extends StatelessWidget {
  const Pair(this.left, this.right, {super.key});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: left), SizedBox(width: 12.r), Expanded(child: right)],
        ),
      );
}

enum PillKind { success, danger, info, neutral }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.kind = PillKind.neutral, this.icon, this.solid = false});

  final String text;
  final PillKind kind;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch ((kind, solid)) {
      (PillKind.success, false) => (C.successContainer.withValues(alpha: 0.18), C.success),
      (PillKind.success, true) => (C.successContainer, C.onSuccessContainer),
      (PillKind.danger, false) => (C.dangerContainer.withValues(alpha: 0.35), C.danger),
      (PillKind.danger, true) => (C.dangerContainer, C.onDangerContainer),
      (PillKind.info, _) => (C.primaryContainer.withValues(alpha: 0.5), C.primary),
      (PillKind.neutral, _) => (C.highest, C.onVariant),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.r, vertical: 5.r),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular((solid ? 20 : 6).r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14.r, color: fg), SizedBox(width: 4.r)],
          Text(text, style: mono(solid ? 15 : 11, weight: FontWeight.w700, spacing: solid ? 0 : 1, color: fg)),
        ],
      ),
    );
  }
}

/// Thick rounded progress meter. Gradient (cobalt → green) or a solid color.
class Meter extends StatelessWidget {
  const Meter(this.value, {super.key, this.color, this.height});

  final double value;
  final Color? color;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final h = height ?? 14.r;
    return Container(
      height: h,
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(color: C.lowest, borderRadius: BorderRadius.circular(h)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.isFinite ? value.clamp(0, 1) : 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(h),
              color: color,
              gradient: color == null ? const LinearGradient(colors: [Color(0xFF3B5BDB), C.success]) : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Section title row: icon + bold title, optional right-hand micro label.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon, this.trailing, this.color = C.onSurface, this.upper = false});

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Color color;
  final bool upper;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 12.r),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: color, size: 22.r), SizedBox(width: 8.r)],
            Expanded(
              child: Text(
                upper ? title.toUpperCase() : title,
                style: sans(upper ? 17 : 21, weight: FontWeight.w700, spacing: upper ? 0.8 : 0, color: color),
              ),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Square icon tile used at the start of list rows.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color = C.highest, this.iconColor = C.primary, this.size});

  final IconData icon;
  final Color color;
  final Color iconColor;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final s = size ?? 44.r;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10.r)),
      child: Icon(icon, color: iconColor, size: s * 0.5),
    );
  }
}

/// 56px primary action (cobalt), or tonal/danger variants.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed, this.icon, this.trailing, this.style = BigButtonStyle.primary, this.height});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailing;
  final BigButtonStyle style;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (style) {
      BigButtonStyle.primary => (C.primaryContainer, Colors.white),
      BigButtonStyle.light => (C.primary, C.onPrimary),
      BigButtonStyle.tonal => (C.high, C.onSurface),
      BigButtonStyle.danger => (C.dangerContainer, C.onDangerContainer),
      BigButtonStyle.success => (C.successContainer, C.onSuccessContainer),
    };
    return SizedBox(
      height: height ?? 56.r,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: 16.r),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 22.r), SizedBox(width: 10.r)],
            Flexible(child: Text(label.toUpperCase(), textAlign: TextAlign.center, style: sans(15, weight: FontWeight.w700, spacing: 1, color: fg))),
            if (trailing != null) ...[SizedBox(width: 10.r), Icon(trailing, size: 22.r)],
          ],
        ),
      ),
    );
  }
}

enum BigButtonStyle { primary, light, tonal, danger, success }

/// Small status dot.
class Dot extends StatelessWidget {
  const Dot({super.key, this.color = C.success});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 10.r, height: 10.r, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message, style: error ? sans(14, weight: FontWeight.w600, color: C.onDangerContainer) : null),
    backgroundColor: error ? C.dangerContainer : null,
    width: isTablet ? 480.r : null,
  ));
}

Future<bool> confirm(BuildContext context, String title, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: C.danger, size: 32.r),
        title: Text(title, style: sans(20, weight: FontWeight.w700)),
        content: Text(message, style: sans(15, color: C.onVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.dangerContainer, foregroundColor: C.onDangerContainer),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    ) ??
    false;
