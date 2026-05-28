import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class AppTheme {
  static const Color accentColor = Color(0xFFD4A017); // Gold/Yellow from Notes app
  static const Color sidebarBackground = Color(0xFF1E1E1E);
  static const Color noteListBackground = Color(0xFF252525);
  static const Color editorBackground = Color(0xFF1A1A1A);

  static MacosThemeData get darkTheme {
    return MacosThemeData.dark().copyWith(
      accentColor: accentColor,
      primaryColor: accentColor,
      typography: MacosTypography.dark().copyWith(
        headline: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        body: const TextStyle(
          color: CupertinoColors.systemGrey4,
          fontSize: 13,
        ),
      ),
    );
  }
}
