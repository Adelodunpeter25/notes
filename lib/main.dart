import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'layouts/desktop_layout.dart';

void main() {
  runApp(const NoteApp());
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Note',
      theme: MacosThemeData.light(),
      darkTheme: MacosThemeData.dark(),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const DesktopLayout(),
    );
  }
}
