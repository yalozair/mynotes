import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionHelper {
  static const _legacyKeyUtf8 = 'MyNotesSecretKey1234567890123456';
  static const _prefsKey = 'enc_device_key_v2';
  static const _cloudSalt = 'MyNotesCloudSalt_v1';

  static encrypt.Key? _deviceKey;
  static String? _activeUserId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(_prefsKey);
    if (stored == null || stored.isEmpty) {
      stored = base64Encode(encrypt.Key.fromSecureRandom(32).bytes);
      await prefs.setString(_prefsKey, stored);
    }
    _deviceKey = encrypt.Key(base64Decode(stored));
  }

  static void setActiveUser(String? userId) {
    _activeUserId = userId;
  }

  static encrypt.Key get _localKey {
    return _deviceKey ?? encrypt.Key.fromUtf8(_legacyKeyUtf8);
  }

  static encrypt.Key _cloudKeyFor(String userId) {
    final digest = sha256.convert(utf8.encode('$userId$_cloudSalt'));
    final bytes = digest.bytes.sublist(0, 32);
    return encrypt.Key(Uint8List.fromList(bytes));
  }

  static encrypt.Key _keyForCloud() {
    if (_activeUserId != null && _activeUserId!.isNotEmpty) {
      return _cloudKeyFor(_activeUserId!);
    }
    return _localKey;
  }

  static String encryptText(String text, {bool forCloud = false}) {
    if (text.isEmpty) return text;
    final key = forCloud ? _keyForCloud() : _localKey;
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(text, iv: iv);
    return 'v2:${iv.base64}:${encrypted.base64}';
  }

  static String decryptText(String text, {bool fromCloud = false}) {
    if (text.isEmpty) return text;
    return _decryptWithKey(text, fromCloud ? _keyForCloud() : _localKey) ??
        (fromCloud ? _decryptWithKey(text, _localKey) : null) ??
        _decryptLegacy(text) ??
        text;
  }

  static String? _decryptWithKey(String text, encrypt.Key key) {
    try {
      if (!text.startsWith('v2:')) return null;
      final parts = text.split(':');
      if (parts.length < 3) return null;
      final iv = encrypt.IV.fromBase64(parts[1]);
      final cipher = parts.sublist(2).join(':');
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      return encrypter.decrypt64(cipher, iv: iv);
    } catch (_) {
      return null;
    }
  }

  static String? _decryptLegacy(String text) {
    try {
      if (text.startsWith('v2:')) return null;
      final legacyKey = encrypt.Key.fromUtf8(_legacyKeyUtf8);
      final legacyIv = encrypt.IV.fromLength(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(legacyKey));
      return encrypter.decrypt64(text, iv: legacyIv);
    } catch (_) {
      return null;
    }
  }

  static bool looksEncrypted(String text) {
    return text.startsWith('v2:') || RegExp(r'^[A-Za-z0-9+/=]{24,}$').hasMatch(text);
  }

  /// فك تشفير محتوى HTML المخزّن محلياً (إن كان مشفراً).
  static String plainHtml(String? stored) {
    if (stored == null || stored.isEmpty) return '';
    if (!looksEncrypted(stored)) return stored;
    return decryptText(stored);
  }
}
