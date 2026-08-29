import 'package:flutter/material.dart';

import '../../app/service_scope.dart';
import '../../app/theme.dart';
import '../shell/shell_page.dart';

/// Desktop login / signup page.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignup = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _submit(ServiceScope scope) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (_isSignup
        ? (username.isEmpty || email.isEmpty || password.isEmpty)
        : (email.isEmpty || password.isEmpty)) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignup) {
        await scope.authService.registerUser(username, email, password);
      } else {
        await scope.authService.login(email, password);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellPage()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ServiceScope.of(context);

    return Scaffold(
      backgroundColor: AppSurfaces.background(context),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _AuthCard(scope: scope, state: this),
          ),
        ),
      ),
    );
  }

  void _setObscure(bool value) => setState(() => _obscurePassword = value);

  void _toggleSignup() => setState(() {
        _isSignup = !_isSignup;
        _errorMessage = null;
      });
}

class _AuthCard extends StatelessWidget {
  final ServiceScope scope;
  final _AuthPageState state;

  const _AuthCard({required this.scope, required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppSurfaces.surface(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppSurfaces.divider(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 40,
              color: AppColors.accent,
            ),
            const SizedBox(height: 12),
            Text(
              state._isSignup ? 'Create your account' : 'Welcome back',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTextColors.primary(context),
              ),
            ),
            const SizedBox(height: 24),
            if (state._isSignup) ...[
              TextField(
                controller: state._usernameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: state._emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: state._passwordController,
              obscureText: state._obscurePassword,
              onSubmitted: (_) => state._submit(scope),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    state._obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => state._setObscure(!state._obscurePassword),
                ),
              ),
            ),
            if (state._errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                state._errorMessage!,
                style: const TextStyle(
                  color: AppColors.destructive,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state._isLoading ? null : () => state._submit(scope),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state._isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(state._isSignup ? 'Sign Up' : 'Log In'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed:
                  state._isLoading ? null : () => state._toggleSignup(),
              child: Text(
                state._isSignup
                    ? 'Already have an account? Log in'
                    : "Don't have an account? Sign up",
                style: const TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

