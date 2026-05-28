import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import '../services/auth.dart';
import '../layouts/desktop_layout.dart';

class LoginPage extends StatefulWidget {
  final AuthService authService;

  const LoginPage({super.key, required this.authService});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await widget.authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => const DesktopLayout()),
        );
      }
    } catch (e) {
      if (mounted) {
        showMacosAlertDialog(
          context: context,
          builder: (context) => MacosAlertDialog(
            appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
            title: const Text('Login Failed'),
            message: Text(e.toString()),
            primaryButton: PushButton(
              controlSize: ControlSize.large,
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MacosScaffold(
      children: [
        ContentArea(
          builder: (context, _) {
            return Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const MacosIcon(
                      CupertinoIcons.doc_text_fill,
                      size: 64,
                      color: Color(0xFFD4A017),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note',
                      style: MacosTheme.of(context).typography.largeTitle,
                    ),
                    const SizedBox(height: 32),
                    MacosTextField(
                      controller: _emailController,
                      placeholder: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    MacosTextField(
                      controller: _passwordController,
                      placeholder: 'Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const ProgressCircle()
                    else
                      Column(
                        children: [
                          PushButton(
                            controlSize: ControlSize.large,
                            onPressed: _login,
                            child: const Text('Login'),
                          ),
                          const SizedBox(height: 16),
                          MacosIconButton(
                            onPressed: () {
                              // Navigate to Signup or handle toggle
                            },
                            icon: const Text('Create an account', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
