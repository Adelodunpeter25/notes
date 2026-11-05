import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';
import '../theme.dart';

/// App settings, currently the app-lock switch. Enabling or disabling the
/// lock requires a successful biometric/device-credential authentication.
Future<void> showSettingsSheet(
    BuildContext context, AppLockService appLockService) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppSurfaces.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SettingsSheet(appLockService: appLockService),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.appLockService});

  final AppLockService appLockService;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _enabled = false;
  bool _canAuthenticate = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.appLockService.isEnabled();
    final canAuthenticate = await widget.appLockService.canAuthenticate();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _canAuthenticate = canAuthenticate;
    });
  }

  Future<void> _toggle(bool want) async {
    if (_busy) return;
    setState(() => _busy = true);

    var granted = want;
    if (_canAuthenticate) {
      // Turning the lock on or off both require proving it's the owner.
      granted = await widget.appLockService.authenticate(
        reason: want ? 'Enable app lock' : 'Disable app lock',
      );
    }
    if (granted) {
      await widget.appLockService.setEnabled(want);
    }

    if (!mounted) return;
    final enabled = await widget.appLockService.isEnabled();
    setState(() {
      _enabled = enabled;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTextColors.primary(context),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accent,
              value: _enabled,
              onChanged: (_canAuthenticate && !_busy) ? _toggle : null,
              secondary: const Icon(CupertinoIcons.lock_shield_fill,
                  color: AppColors.accent),
              title: Text('App Lock',
                  style: TextStyle(color: AppTextColors.primary(context))),
              subtitle: Text(
                _canAuthenticate
                    ? 'Require biometrics or your device PIN to open the app'
                    : 'No biometrics or screen lock is set up on this device',
                style: TextStyle(color: AppTextColors.secondary(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
