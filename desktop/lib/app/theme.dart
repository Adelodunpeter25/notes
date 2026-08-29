import 'package:flutter/material.dart';

class AppColors {
  static const Color accent = Color(0xFFD4A017);
  static const Color onAccent = Colors.black;
  static const Color destructive = Color(0xFFFF3B30);
  static const Color onDestructive = Colors.white;
  static const Color success = Color(0xFF34C759);
  static const Color handle = Color(0xFFBDBDBD);
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkElevated = Color(0xFF2C2C2E);
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Colors.white;
  static const Color lightElevated = Color(0xFFE5E5EA);
}

class AppTextColors {
  static Color primary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }

  static Color secondary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white54 : Colors.black54;
  }

  static Color tertiary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white38 : Colors.black38;
  }

  static Color quaternary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white24 : Colors.black26;
  }
}

class AppSurfaces {
  static Color background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkBg : AppColors.lightBg;
  }

  static Color surface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkSurface : AppColors.lightSurface;
  }

  static Color elevated(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.darkElevated : AppColors.lightElevated;
  }

  static Color divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white12 : Colors.black12;
  }
}

ThemeData buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    colorSchemeSeed: AppColors.accent,
    useMaterial3: true,
    fontFamily: 'SF Pro Text',
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorSchemeSeed: AppColors.accent,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBg,
    fontFamily: 'SF Pro Text',
  );
}
