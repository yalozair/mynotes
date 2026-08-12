import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateHelper {
  static const repoOwner = 'yalozair';
  static const repoName = 'mynotes';
  static const repoUrl = 'https://github.com/yalozair/mynotes';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final uri = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );
      final response = await http.get(uri, headers: {'Accept': 'application/vnd.github+json'});
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String?)?.replaceAll('v', '') ?? '';
      if (latestTag.isEmpty || !_isNewer(latestTag, current)) return;

      if (!context.mounted) return;
      final notes = data['body']?.toString() ?? '';
      final downloadUrl = _pickApkAsset(data['assets'] as List<dynamic>?);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('تحديث متوفر $latestTag'),
          content: SingleChildScrollView(
            child: Text(
              notes.isEmpty
                  ? 'يتوفر إصدار أحدث ($latestTag). إصدارك الحالي: $current'
                  : notes,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final url = downloadUrl ?? data['html_url']?.toString() ?? repoUrl;
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: const Text('تحديث'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static String? _pickApkAsset(List<dynamic>? assets) {
    if (assets == null) return null;
    for (final asset in assets) {
      final name = asset['name']?.toString() ?? '';
      if (name.endsWith('.apk')) return asset['browser_download_url']?.toString();
    }
    return null;
  }

  static bool _isNewer(String latest, String current) {
    List<int> parse(String v) =>
        v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final a = parse(latest);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai > bi) return true;
      if (ai < bi) return false;
    }
    return false;
  }
}
