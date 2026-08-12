import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ExportHelper {
  static Future<bool> exportMarkdown(String title, String plainText) async {
    try {
      final safeTitle = title.trim().isEmpty ? 'مذكرة' : title.trim();
      final md = '# $safeTitle\n\n${plainText.trim()}\n';
      final fileName = '${safeTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.md';

      final path = await FilePicker.saveFile(
        dialogTitle: 'حفظ Markdown',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['md'],
      );
      if (path == null) return false;
      await File(path).writeAsString(md, encoding: utf8);
      return true;
    } catch (e) {
      debugPrint('Markdown export failed: $e');
      return false;
    }
  }
}
