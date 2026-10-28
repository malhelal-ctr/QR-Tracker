import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// "Industrial Optical Matrix" design tokens (from the Stitch design).
abstract final class C {
  static const surface = Color(0xFF0B1326);
  static const lowest = Color(0xFF060E20);
  static const low = Color(0xFF131B2E);
  static const container = Color(0xFF171F33);
  static const high = Color(0xFF222A3D);
  static const highest = Color(0xFF2D3449);
  static const onSurface = Color(0xFFDAE2FD);
  static const onVariant = Color(0xFFC4C5D5);
  static const outline = Color(0xFF8E909F);
  static const outlineVariant = Color(0xFF444653);
  static const primary = Color(0xFFB8C4FF);
  static const onPrimary = Color(0xFF002584);
  static const primaryContainer = Color(0xFF1E40AF);
  static const success = Color(0xFF68DBA9);
  static const successContainer = Color(0xFF25A475);
  static const onSuccessContainer = Color(0xFF00311F);
  static const danger = Color(0xFFFFB4AB);
  static const dangerContainer = Color(0xFF9B000D);
  static const onDangerContainer = Color(0xFFFFDAD6);
  static const warning = Color(0xFFFBBF24);
}

// The bundled fonts are variable fonts, so the weight axis is set explicitly.
// Sizes are design pixels and are scaled to the screen here, so callers pass the Stitch values.
TextStyle _font(String family, double size, FontWeight weight, Color? color, double? spacing, double? height) => TextStyle(
      fontFamily: family,
      fontSize: size.r,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      color: color,
      letterSpacing: spacing?.r,
      height: height,
    );

TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color? color, double? spacing, double? height}) =>
    _font('JetBrainsMono', size, weight, color, spacing, height);

TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color, double? spacing, double? height}) =>
    _font('Inter', size, weight, color, spacing, height);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: C.surface,
    onSurface: C.onSurface,
    onSurfaceVariant: C.onVariant,
    surfaceContainerLowest: C.lowest,
    surfaceContainerLow: C.low,
    surfaceContainer: C.container,
    surfaceContainerHigh: C.high,
    surfaceContainerHighest: C.highest,
    primary: C.primary,
    onPrimary: C.onPrimary,
    primaryContainer: C.primaryContainer,
    onPrimaryContainer: Colors.white,
    secondary: C.success,
    secondaryContainer: C.successContainer,
    onSecondaryContainer: C.onSuccessContainer,
    error: C.danger,
    errorContainer: C.dangerContainer,
    onErrorContainer: C.onDangerContainer,
    outline: C.outline,
    outlineVariant: C.outlineVariant,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r));
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12.r),
    borderSide: const BorderSide(color: C.outlineVariant, width: 1.5),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: C.surface,
    fontFamily: 'Inter',
    textTheme: TextTheme(
      bodyLarge: sans(16, weight: FontWeight.w500),
      bodyMedium: sans(14),
      bodySmall: sans(12, color: C.onVariant),
      titleLarge: sans(22, weight: FontWeight.w600),
      titleMedium: sans(18, weight: FontWeight.w600),
      titleSmall: sans(14, weight: FontWeight.w600),
      labelLarge: sans(14, weight: FontWeight.w700, spacing: 0.6),
    ).apply(bodyColor: C.onSurface, displayColor: C.onSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.lowest,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2)),
      hintStyle: sans(15, color: C.outline),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.lowest : C.outline),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? C.successContainer : C.highest),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.lowest,
      indicatorColor: C.high,
      indicatorShape: rounded,
      height: 72.r,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => mono(11, weight: FontWeight.w700, spacing: 0.8, color: s.contains(WidgetState.selected) ? C.primary : C.onVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.primary : C.onVariant),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: C.container,
      dragHandleColor: C.outline,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: C.high, shape: rounded),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.highest,
      contentTextStyle: sans(14, weight: FontWeight.w500, color: C.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: rounded,
    ),
    iconTheme: IconThemeData(size: 24.r),
    dividerTheme: const DividerThemeData(color: C.high, space: 1, thickness: 1),
  );
}
