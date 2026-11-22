import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local app lock backed by biometrics or the device's screen lock.
///
/// Caches the last unlock/activity timestamp in [SharedPreferences] so the user
/// is not prompted again within [gracePeriod] across app restarts or brief
/// background switches.
class AppLockService {
  static const String _lastUnlockedKey = 'app_lock_last_unlocked_at';
  static const Duration defaultGracePeriod = Duration(minutes: 5);

  AppLockService({
    LocalAuthentication? auth,
    this.gracePeriod = defaultGracePeriod,
    DateTime Function()? clock,
  })  : _auth = auth ?? LocalAuthentication(),
        _clock = clock ?? DateTime.now;

  final LocalAuthentication _auth;
  final Duration gracePeriod;
  final DateTime Function() _clock;

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

  /// Returns true if the user unlocked or was active within [gracePeriod].
  Future<bool> isWithinGracePeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_lastUnlockedKey);
      if (lastMs == null) return false;
      final lastUnlocked = DateTime.fromMillisecondsSinceEpoch(lastMs);
      final elapsed = _clock().difference(lastUnlocked);
      return !elapsed.isNegative && elapsed < gracePeriod;
    } catch (_) {
      return false;
    }
  }

  /// Records the current time as the last unlocked/active timestamp.
  Future<void> markUnlocked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUnlockedKey, _clock().millisecondsSinceEpoch);
    } catch (_) {
      // Ignore storage errors; worst case the user is prompted again.
    }
  }

  /// Prompts the user to unlock. Returns true when authentication succeeds.
  Future<bool> authenticate({String reason = 'Unlock your notes'}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // fall back to the device PIN/pattern
        ),
      );
      if (ok) {
        await markUnlocked();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }
}
