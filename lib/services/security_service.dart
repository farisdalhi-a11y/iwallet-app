import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const MethodChannel _nativeChannel = MethodChannel('com.wallet.pay/native');

  /// التحقق البيومتري (بصمة الإصبع أو الوجه) قبل الدفع أو كشف البيانات
  static Future<bool> authenticateBiometric(String reason) async {
    try {
      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// توليد رمز تحقق عشوائي من 6 أرقام
  static String generateOtpCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// تشفير رمز التحقق بتقنية SHA-256 قبل تخزينه
  static String hashString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// حفظ مفتاح الجلسة في Android Keystore
  static Future<void> saveSecureToken(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> readSecureToken(String key) async {
    return await _storage.read(key: key);
  }

  /// تفعيل بطاقة NFC HCE لإرسال رمز الدفع
  static Future<void> activateNfcPayment(String paymentToken) async {
    await _nativeChannel.invokeMethod('activateHceToken', {'token': paymentToken});
  }

  static Future<void> deactivateNfcPayment() async {
    await _nativeChannel.invokeMethod('deactivateHceToken');
  }

  /// تشغيل وضع التاجر لاستقبال الدفع عبر NFC
  static Future<void> startMerchantNfcReader(Function(String token) onTokenReceived) async {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcTokenReceived') {
        onTokenReceived(call.arguments as String);
      }
    });
    await _nativeChannel.invokeMethod('startMerchantReader');
  }

  static Future<void> stopMerchantNfcReader() async {
    await _nativeChannel.invokeMethod('stopMerchantReader');
  }
}
