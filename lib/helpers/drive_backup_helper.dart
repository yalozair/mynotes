import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_helper.dart';

class _GoogleAuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();
  _GoogleAuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

class DriveBackupHelper {
  static const _lastDriveKey = 'last_drive_auto_backup_ms';
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['https://www.googleapis.com/auth/drive.file'],
  );

  static Future<String?> uploadEncryptedBackup() async {
    final export = await BackupHelper.exportEncryptedBackup();
    if (export.status != BackupExportStatus.success || export.path == null) return null;
    final exportPath = export.path!;

    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(exportPath)],
        text: 'نسخة احتياطية مشفّرة من مفكرتي',
        subject: 'مفكرتي — نسخة احتياطية',
      ));
      return exportPath;
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null || token.isEmpty) return null;

      final file = File(exportPath);
      final bytes = await file.readAsBytes();
      final fileName = p.basename(exportPath);
      final client = _GoogleAuthClient(token);
      final metadata = jsonEncode({'name': fileName, 'mimeType': 'application/octet-stream'});
      final boundary = 'mofkarti_${DateTime.now().millisecondsSinceEpoch}';
      final body = <int>[
        ...utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'
          '--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n',
        ),
        ...bytes,
        ...utf8.encode('\r\n--$boundary--'),
      ];
      final response = await client.post(
        Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
        headers: {'Content-Type': 'multipart/related; boundary=$boundary'},
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastDriveKey, DateTime.now().millisecondsSinceEpoch);
        return fileName;
      }
      debugPrint('Drive upload failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Drive backup error: $e');
    }

    await SharePlus.instance.share(ShareParams(files: [XFile(exportPath)], text: 'نسخة احتياطية مشفّرة من مفكرتي'));
    return exportPath;
  }

  static Future<String?> lastBackupLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastDriveKey) ?? 0;
    if (last <= 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(last);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static Future<String?> runWeeklyIfDue({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('drive_auto_backup') ?? false) && !force) return null;
    final last = prefs.getInt(_lastDriveKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - last < const Duration(days: 7).inMilliseconds) return null;
    return uploadEncryptedBackup();
  }
}
