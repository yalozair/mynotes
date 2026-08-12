import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../helpers/encryption_helper.dart';
import '../helpers/db_helper.dart';
import '../models/note.dart';

enum BackupExportStatus { cancelled, success, failed }

class BackupExportResult {
  final BackupExportStatus status;
  final String? path;

  const BackupExportResult(this.status, [this.path]);
}

class BackupHelper {
  static const backupExtension = 'mynotes';

  static Future<BackupExportResult> exportEncryptedBackup() async {
    try {
      final notes = await DBHelper().getNotes(deleted: false);
      final trash = await DBHelper().getNotes(deleted: true);
      final payload = jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'notes': [...notes, ...trash].map((n) => n.toMap()).toList(),
      });
      final encrypted = EncryptionHelper.encryptText(payload);
      final fileName = 'mynotes_backup_${DateTime.now().millisecondsSinceEpoch}.$backupExtension';

      String? path;
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        path = p.join(dir.path, fileName);
      } else {
        path = await FilePicker.saveFile(
          dialogTitle: 'تصدير نسخة احتياطية مشفّرة',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [backupExtension],
        );
        if (path == null) return const BackupExportResult(BackupExportStatus.cancelled);
      }

      await File(path).writeAsString(encrypted, encoding: utf8);
      return BackupExportResult(BackupExportStatus.success, path);
    } catch (e) {
      debugPrint('Backup export failed: $e');
      return const BackupExportResult(BackupExportStatus.failed);
    }
  }

  static Future<int> importEncryptedBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [backupExtension],
      );
      if (result == null || result.files.single.path == null) return 0;

      final raw = await File(result.files.single.path!).readAsString(encoding: utf8);
      final decrypted = EncryptionHelper.decryptText(raw);
      final data = jsonDecode(decrypted) as Map<String, dynamic>;
      final list = (data['notes'] as List<dynamic>?) ?? [];

      final db = DBHelper();
      var imported = 0;
      for (final item in list) {
        final note = Note.fromMap(Map<String, dynamic>.from(item as Map));
        note.id = null;
        note.isSynced = false;
        await db.insertNote(note);
        imported++;
      }
      return imported;
    } catch (e) {
      debugPrint('Backup import failed: $e');
      rethrow;
    }
  }
}
