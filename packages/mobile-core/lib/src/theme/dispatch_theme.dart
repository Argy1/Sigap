import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dispatch_colors.dart';
import 'dispatch_typography.dart';

/// Skala radius sistem desain, diambil dari mockup.
/// Sudut tajam dan tanpa bayangan bertentangan dengan sistem ini — pertahankan
/// skala yang sama di seluruh layar.
class DispatchRadii {
  const DispatchRadii._();

  static const double panel = 15;
  static const double card = 13;
  static const double input = 12;
  static const double button = 13;
  static const double chip = 9;
  static const double statusChip = 6;
  static const double navbar = 16;
  static const double avatar = 10;
  static const double icon = 9;
}

/// Jarak baku — padding horizontal layar di mockup konsisten 20px.
class DispatchSpacing {
  const DispatchSpacing._();

  static const double screenH = 20;
  static const double gap = 9;
  static const double panelGap = 12;
}

ThemeData buildDispatchTheme(Brightness brightness) {
  final palette =
      brightness == Brightness.dark ? DispatchColors.dark : DispatchColors.light;

  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: palette.ink,
    // Material default akan menimpa warna sistem desain ini di banyak tempat,
    // jadi ColorScheme-nya dipetakan langsung ke palet Dispatch Console.
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.vital,
      brightness: brightness,
    ).copyWith(
      surface: palette.ink,
      primary: palette.vital,
      onPrimary: palette.onVital,
      error: palette.siren,
    ),
  );

  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[palette],
    splashFactory: InkRipple.splashFactory,
    textTheme: base.textTheme.apply(
      fontFamily: DispatchType.body,
      fontFamilyFallback: const [DispatchType.body],
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    dividerTheme: DividerThemeData(color: palette.divider, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.isDark
          ? const Color(0xFF1A2332)
          : const Color(0xFF0A0E14),
      contentTextStyle: DispatchType.bodyStyle(
        size: 12,
        weight: 600,
        color: const Color(0xFFF4F6F8),
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DispatchRadii.input),
      ),
    ),
  );
}
