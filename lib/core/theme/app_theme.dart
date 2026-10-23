import 'package:flutter/material.dart';

/// ألوان الهوية: أخضر داكن للأساس، أبيض للخلفيات، ذهبي للتفاصيل.
class AppColors {
  AppColors._();

  static const Color forest = Color(0xFF003016); // خلفية الأيقونة
  static const Color emerald = Color(0xFF0E5A34);
  static const Color emeraldBright = Color(0xFF3FA06B);
  static const Color gold = Color(0xFFC9A24A);
  static const Color goldSoft = Color(0xFFE3C778);
  static const Color goldDeep = Color(0xFF8A6A1F);

  static const Color lightBg = Color(0xFFF6F7F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF14201A);
  static const Color lightMuted = Color(0xFF5B6B62);
  static const Color lightBorder = Color(0xFFDDE3DC);

  static const Color darkBg = Color(0xFF06120B);
  static const Color darkSurface = Color(0xFF0D2016);
  static const Color darkSurfaceHigh = Color(0xFF14301F);
  static const Color darkText = Color(0xFFEAF1EC);
  static const Color darkMuted = Color(0xFF9DB1A5);
  static const Color darkBorder = Color(0xFF1F3A2A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color muted(BuildContext context) {
    return isDark(context) ? AppColors.darkMuted : AppColors.lightMuted;
  }

  static Color border(BuildContext context) {
    return isDark(context) ? AppColors.darkBorder : AppColors.lightBorder;
  }

  static Color surface(BuildContext context) {
    return isDark(context) ? AppColors.darkSurface : AppColors.lightSurface;
  }

  static Color surfaceHigh(BuildContext context) {
    return isDark(context) ? AppColors.darkSurfaceHigh : AppColors.lightBg;
  }

  /// ذهبي مناسب لكل وضع (أغمق في الفاتح ليبقى مقروءاً).
  static Color accent(BuildContext context) {
    return isDark(context) ? AppColors.goldSoft : AppColors.goldDeep;
  }

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;

    final Color bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final Color surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color onSurface = dark ? AppColors.darkText : AppColors.lightText;
    final Color muted = dark ? AppColors.darkMuted : AppColors.lightMuted;
    final Color border = dark ? AppColors.darkBorder : AppColors.lightBorder;

    final ColorScheme base = ColorScheme.fromSeed(
      seedColor: AppColors.emerald,
      brightness: brightness,
    );

    final ColorScheme scheme = base.copyWith(
      primary: dark ? AppColors.emeraldBright : AppColors.emerald,
      onPrimary: dark ? AppColors.forest : Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.forest,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? AppColors.gold : AppColors.emerald,
          foregroundColor: dark ? AppColors.forest : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
