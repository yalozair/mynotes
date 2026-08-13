import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import 'pdf_helper.dart';

class FolderExportHelper {
  static Future<String?> exportFolderAsZip(String folder, List<Note> notes) async {
    try {
      final filtered = notes.where((n) => n.folder == folder && !n.isDeleted).toList();
      if (filtered.isEmpty) return null;

      final archive = Archive();
      for (final note in filtered) {
        final safe = _safeName(note.title.isEmpty ? 'note_${note.id}' : note.title);
        final body = StringBuffer()
          ..writeln('# ${note.title}')
          ..writeln()
          ..writeln(note.isEncrypted ? 'ملاحظة مشفرة' : note.content);
        archive.addFile(ArchiveFile(
          '$safe.md',
          utf8.encode(body.toString()).length,
          utf8.encode(body.toString()),
        ));
      }

      final bytes = ZipEncoder().encode(archive);
      if (bytes == null) return null;

      final dir = await getTemporaryDirectory();
      final path = p.join(dir.path, 'folder_${_safeName(folder)}_${DateTime.now().millisecondsSinceEpoch}.zip');
      await File(path).writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: 'مجلد $folder'));
      return path;
    } catch (e) {
      debugPrint('Folder ZIP export failed: $e');
      return null;
    }
  }

  static Future<String?> exportFolderAsPdf(String folder, List<Note> notes) async {
    try {
      final filtered = notes.where((n) => n.folder == folder && !n.isDeleted).toList();
      if (filtered.isEmpty) return null;
      final buffer = StringBuffer();
      for (final note in filtered) {
        buffer.writeln(note.title);
        buffer.writeln('-' * 20);
        buffer.writeln(note.isEncrypted ? 'ملاحظة مشفرة' : note.content);
        buffer.writeln('\n\n');
      }
      await PDFHelper.exportToPDF('مجلد $folder', buffer.toString());
      return 'ok';
    } catch (e) {
      debugPrint('Folder PDF export failed: $e');
      return null;
    }
  }

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}
