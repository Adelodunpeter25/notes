import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'database/database.dart';
import 'services/api_service.dart';
import 'services/auth.dart';
import 'layouts/desktop_layout.dart';
import 'pages/auth_pages.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final db = AppDatabase();
  final api = ApiService();
  final auth = AuthService(db, api);
  
  // Check session persistence
  final token = await auth.getSessionToken();

  runApp(NoteApp(
    authService: auth,
    isLoggedIn: token != null,
  ));
}

class NoteApp extends StatelessWidget {
  final AuthService authService;
  final bool isLoggedIn;

  const NoteApp({
    super.key, 
    required this.authService,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'Note',
      theme: AppTheme.darkTheme, // Force dark mode as default
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn 
          ? const DesktopLayout() 
          : LoginPage(authService: authService),
    );
  }
}
