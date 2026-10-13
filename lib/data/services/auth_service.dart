import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Device owner authentication wrapper.
/// Uses platform biometrics with passcode fallback where available.
class AuthService {
  AuthService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isDeviceAuthenticationAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
