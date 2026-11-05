import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme.dart';

/// Lock screen shown in front of the app whenever it starts or comes back
/// from the background. Unlocking always requires biometrics or the device's
/// screen lock. If the device has no lock method enrolled at all there is
/// nothing to authenticate against, so the app opens (and the lock screen
/// shows a hint to set one up).
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
  bool _deviceCanAuthenticate = false;
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
    _deviceCanAuthenticate = await widget.service.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _locked = _deviceCanAuthenticate;
    });
    if (_locked) _authenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _deviceCanAuthenticate) {
      // Left the app; require unlock when it comes back.
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked && !_authenticating) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    final unlocked = await widget.service.authenticate(reason: 'Unlock your notes');
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
            const SizedBox(height: 8),
            if (!_deviceCanAuthenticate)
              Text(
                'Set up a screen lock or fingerprint on this device to unlock',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
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
