import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local app lock backed by biometrics or the device's screen lock.
///
/// The flag is stored in SharedPreferences on this device only; nothing is
/// synced. Enabling or disabling the lock always requires a successful
/// authentication first, so a thief (or a friend) can't just turn it off.
class AppLockService {
  static const String _enabledKey = 'app_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Persists the flag. Only call after a successful [authenticate] — the UI
  /// enforces this so the lock can never be switched off without unlocking.
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Whether this device has a lock method available (biometrics or PIN).
  Future<bool> canAuthenticate() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user to unlock. Returns true when authentication succeeds.
  Future<bool> authenticate({String reason = 'Unlock your notes'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // fall back to the device PIN/pattern
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
