import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  final bool success;
  final String? message;

  const AuthResult.success() : success = true, message = null;
  const AuthResult.failure(this.message) : success = false;
}

class AuthHelper {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// هل الجهاز يدعم قفل الشاشة (بصمة، وجه، نمط، PIN، كلمة مرور)؟
  static Future<bool> isDeviceLockAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @Deprecated('Use isDeviceLockAvailable')
  static Future<bool> canCheckBiometrics() => isDeviceLockAvailable();

  static Future<String> deviceLockMethodsHint() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      final labels = <String>[];
      for (final type in types) {
        switch (type) {
          case BiometricType.face:
            labels.add('التعرف على الوجه');
          case BiometricType.fingerprint:
            labels.add('بصمة الإصبع');
          case BiometricType.iris:
            labels.add('بصمة العين');
          case BiometricType.strong:
          case BiometricType.weak:
            break;
        }
      }
      if (labels.isNotEmpty) {
        labels.add('رمز القفل / النمط / PIN');
        return labels.join('، ');
      }
    } catch (_) {}
    return 'بصمة الإصبع، التعرف على الوجه، النمط، أو رمز PIN';
  }

  static Future<AuthResult> authenticateWithMessage() async {
    try {
      final supported = await isDeviceLockAvailable();
      if (!supported) {
        return const AuthResult.failure(
          'فعّل قفل الشاشة في إعدادات الجهاز أولاً (نمط، PIN، بصمة، أو وجه)',
        );
      }

      final ok = await _auth.authenticate(
        localizedReason: 'استخدم طريقة قفل جهازك للدخول إلى الملاحظات',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? const AuthResult.success() : const AuthResult.failure('تم إلغاء التحقق');
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noCredentialsSet:
          return const AuthResult.failure('فعّل قفل الشاشة من إعدادات الجهاز (نمط، PIN، أو بصمة)');
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          // قد يظل PIN/النمط متاحاً؛ نعيد المحاولة عبر رسالة عامة
          return AuthResult.failure(e.description ?? 'تعذّر التحقق. استخدم رمز القفل أو النمط');
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return const AuthResult.failure('محاولات كثيرة. انتظر قليلاً ثم أعد المحاولة');
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
          return const AuthResult.failure('تم إلغاء التحقق');
        default:
          return AuthResult.failure(e.description ?? 'فشل التحقق');
      }
    } catch (e) {
      return AuthResult.failure('فشل التحقق: $e');
    }
  }

  static Future<bool> authenticate() async {
    final result = await authenticateWithMessage();
    return result.success;
  }

  static Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('lock') ?? false;
  }

  static Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock', enabled);
  }
}
