import 'package:local_auth/local_auth.dart';

/// Device-local app lock backed by biometrics or the device's screen lock.
///
/// Always enabled: the gate locks on app start and whenever the app returns
/// from the background. Nothing about it is synced or configurable — and it
/// lives entirely on this device, like the reminders.
class AppLockService {
  final LocalAuthentication _auth = LocalAuthentication();

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
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // fall back to the device PIN/pattern
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
