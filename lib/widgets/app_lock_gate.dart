import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme.dart';

/// Gate widget shown over the app when the app lock is enabled.
///
/// Locks on app start and whenever the app returns from the background. If
/// the device has no unlock method enrolled, the lock stays open and disables
/// itself rather than permanently locking the user out.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.service, required this.child});

  final AppLockService service;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initialCheck() async {
    final enabled = await widget.service.isEnabled();
    if (!enabled || !mounted) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    final canAuthenticate = await widget.service.canAuthenticate();
    if (!canAuthenticate) {
      // No biometrics or device credential enrolled: don't lock the user out.
      await widget.service.setEnabled(false);
      if (mounted) setState(() => _checking = false);
      return;
    }
    if (mounted) {
      setState(() {
        _checking = false;
        _locked = true;
      });
      _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _locked == false &&
        _checking == false) {
      // Left the app; require unlock when it comes back.
      widget.service.isEnabled().then((enabled) {
        if (enabled && mounted) setState(() => _locked = true);
      });
    } else if (state == AppLifecycleState.resumed &&
        _locked &&
        !_authenticating) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    final unlocked =
        await widget.service.authenticate(reason: 'Unlock your notes');
    _authenticating = false;
    if (mounted) setState(() => _locked = !unlocked);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_locked) return widget.child;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.lock_shield_fill,
              size: 72,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            Text(
              'Your notes are locked',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _authenticate,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
