import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const String _pinKey = 'security_pin_hash';
  static const String _saltKey = 'security_pin_salt';
  static const String _biometricsKey = 'biometrics_enabled';

  bool _isLocked = false;
  bool _isPinConfigured = false;
  bool _isBiometricsEnabled = false;
  DateTime? _lastActiveTime;
  final Duration autoLockTimeout = const Duration(minutes: 5);

  // Rate Limiting & Lockout
  int _failedAttemptCount = 0;
  DateTime? _lockoutUntil;

  late final Future<void> initFuture;

  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? auth,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _auth = auth ?? LocalAuthentication() {
    initFuture = _initSecurityState();
  }

  bool get isLocked => _isLocked;
  bool get isPinConfigured => _isPinConfigured;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  int get failedAttemptCount => _failedAttemptCount;
  bool get isLockoutActive => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  int get lockoutRemainingSeconds =>
      isLockoutActive ? _lockoutUntil!.difference(DateTime.now()).inSeconds : 0;

  Future<void> _initSecurityState() async {
    try {
      final pinHash = await _storage.read(key: _pinKey);
      _isPinConfigured = pinHash != null && pinHash.isNotEmpty;

      final bioStr = await _storage.read(key: _biometricsKey);
      _isBiometricsEnabled = bioStr == 'true';

      if (_isPinConfigured || _isBiometricsEnabled) {
        _isLocked = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing security state: $e');
    }
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  Future<bool> setPin(String pin) async {
    try {
      final salt = DateTime.now().microsecondsSinceEpoch.toString();
      final hash = _hashPin(pin, salt);
      await _storage.write(key: _saltKey, value: salt);
      await _storage.write(key: _pinKey, value: hash);
      _isPinConfigured = true;
      _failedAttemptCount = 0;
      _lockoutUntil = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to set PIN: $e');
      return false;
    }
  }

  Future<bool> verifyPin(String inputPin) async {
    if (isLockoutActive) {
      notifyListeners();
      return false;
    }

    try {
      final storedHash = await _storage.read(key: _pinKey);
      final storedSalt = await _storage.read(key: _saltKey);

      if (storedHash == null || storedSalt == null) return false;

      final inputHash = _hashPin(inputPin, storedSalt);
      final isCorrect = _constantTimeCompare(inputHash, storedHash);

      if (isCorrect) {
        _failedAttemptCount = 0;
        _lockoutUntil = null;
        unlock();
        return true;
      } else {
        _failedAttemptCount++;
        if (_failedAttemptCount >= 5) {
          final lockoutSeconds = (_failedAttemptCount - 4) * 30;
          _lockoutUntil = DateTime.now().add(Duration(seconds: lockoutSeconds));
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Failed to verify PIN: $e');
      return false;
    }
  }

  Future<bool> disablePin({required String currentPin}) async {
    final isValid = await verifyPin(currentPin);
    if (!isValid) return false;

    try {
      await _storage.delete(key: _pinKey);
      await _storage.delete(key: _saltKey);
      await _storage.delete(key: _biometricsKey);
      _isPinConfigured = false;
      _isBiometricsEnabled = false;
      _isLocked = false;
      _failedAttemptCount = 0;
      _lockoutUntil = null;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to disable PIN: $e');
      return false;
    }
  }

  Future<bool> enableBiometrics(String reason) async {
    try {
      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        await _storage.write(key: _biometricsKey, value: 'true');
        _isBiometricsEnabled = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to enable biometrics: $e');
      return false;
    }
  }

  Future<bool> disableBiometrics() async {
    try {
      await _storage.write(key: _biometricsKey, value: 'false');
      _isBiometricsEnabled = false;
      if (!_isPinConfigured) {
        _isLocked = false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to disable biometrics: $e');
      return false;
    }
  }

  Future<bool> setBiometricsEnabled(bool enabled, {String? reason}) async {
    if (enabled) {
      return enableBiometrics(reason ?? 'Authenticate to enable biometrics');
    } else {
      return disableBiometrics();
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final available = await _auth.getAvailableBiometrics();
      return isDeviceSupported || canCheck || available.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics(String reason) async {
    if (!_isBiometricsEnabled) return false;
    if (isLockoutActive) return false;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        _failedAttemptCount = 0;
        _lockoutUntil = null;
        unlock();
      }
      return authenticated;
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }

  void lock() {
    if (_isPinConfigured || _isBiometricsEnabled) {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    _isLocked = false;
    _lastActiveTime = DateTime.now();
    notifyListeners();
  }

  Future<void> clearAllSecurity() async {
    try {
      await _storage.deleteAll();
      _isPinConfigured = false;
      _isBiometricsEnabled = false;
      _isLocked = false;
      _failedAttemptCount = 0;
      _lockoutUntil = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear security storage: $e');
    }
  }

  void onAppPaused() {
    _lastActiveTime = DateTime.now();
  }

  void onAppResumed() {
    if ((_isPinConfigured || _isBiometricsEnabled) && _lastActiveTime != null) {
      final elapsed = DateTime.now().difference(_lastActiveTime!);
      if (elapsed >= autoLockTimeout) {
        lock();
      }
    }
  }
}
