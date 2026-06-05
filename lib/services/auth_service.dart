import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricsEnabled() async {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('useBiometrics', defaultValue: false);
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final settingsBox = Hive.box('settings');
    await settingsBox.put('useBiometrics', enabled);
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    final bool enabled = await isBiometricsEnabled();
    if (!enabled) return true;

    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to access patient records',
      );
    } on PlatformException catch (e) {
      print('Authentication error: $e');
      return false;
    }
  }
}
