import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'native_helper.dart';

class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final bool mandatory;
  final List<String> changelog;
  final String? apkUrl;
  final String? windowsUrl;
  final String? linuxUrl;
  final String? webUrl;

  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.mandatory,
    required this.changelog,
    this.apkUrl,
    this.windowsUrl,
    this.linuxUrl,
    this.webUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final rawChangelog = json['changelog'];
    final List<String> notes;
    if (rawChangelog is List) {
      notes = rawChangelog.map((e) => e.toString()).toList();
    } else if (rawChangelog is String && rawChangelog.trim().isNotEmpty) {
      notes = rawChangelog
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      notes = const <String>[];
    }

    return AppUpdateInfo(
      versionName: json['versionName']?.toString() ?? '',
      versionCode: int.tryParse('${json['versionCode']}') ?? 0,
      mandatory: json['mandatory'] == true,
      changelog: notes,
      apkUrl: json['apkUrl']?.toString(),
      windowsUrl: json['windowsUrl']?.toString(),
      linuxUrl: json['linuxUrl']?.toString(),
      webUrl: json['webUrl']?.toString(),
    );
  }
}

/// تحديث داخل التطبيق عبر ملف [update.json] صغير.
///
/// - أندرويد: تنزيل APK مع شريط تقدّم ثم فتح مثبّت النظام.
/// - ويندوز/غيره: فتح رابط التنزيل في المتصفح.
class UpdateHelper {
  /// روابط التحقق بالترتيب (أول ناجح يُستخدم).
  /// 1) استضافة Firebase/الويب — تعمل حتى لو المستودع خاص.
  /// 2) ملف updates/update.json من GitHub — يحتاج مستودعاً عاماً.
  static const updateJsonUrls = <String>[
    'https://mysmartnotes-8459e.web.app/update.json',
    'https://raw.githubusercontent.com/yalozair/mynotes/main/updates/update.json',
    'https://github.com/yalozair/mynotes/releases/latest/download/update.json',
  ];

  static Future<void> checkForUpdate(
    BuildContext context, {
    bool silent = true,
  }) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      final remote = await fetchUpdateInfo();
      if (remote == null) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر التحقق من التحديثات')),
          );
        }
        return;
      }

      if (remote.versionCode <= currentCode) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('أنت على أحدث إصدار (${info.version})')),
          );
        }
        return;
      }

      if (!context.mounted) return;
      await _showUpdateDialog(context, remote, info.version);
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحقق من التحديث: $e')),
        );
      }
    }
  }

  static Future<AppUpdateInfo?> fetchUpdateInfo() async {
    for (final url in updateJsonUrls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          return AppUpdateInfo.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('update.json fetch failed ($url): $e');
      }
    }
    return null;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo update,
    String currentVersion,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (ctx) => _UpdateDialog(
        update: update,
        currentVersion: currentVersion,
      ),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo update;
  final String currentVersion;

  const _UpdateDialog({
    required this.update,
    required this.currentVersion,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _status;
  http.Client? _client;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _startUpdate() async {
    if (_downloading) return;

    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (isAndroid) {
      final apkUrl = widget.update.apkUrl;
      if (apkUrl == null || apkUrl.isEmpty) {
        setState(() => _status = 'رابط APK غير متوفر');
        return;
      }
      await _downloadAndInstall(apkUrl);
      return;
    }

    // ويندوز / لينكس / ماك / ويب: فتح رابط مناسب في المتصفح
    final url = _platformDownloadUrl();
    if (url == null) {
      setState(() => _status = 'لا يوجد رابط تنزيل لهذه المنصة');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (mounted && !widget.update.mandatory) Navigator.of(context).pop();
  }

  String? _platformDownloadUrl() {
    if (kIsWeb) return widget.update.webUrl ?? widget.update.windowsUrl;
    if (Platform.isWindows) {
      return widget.update.windowsUrl ?? widget.update.apkUrl;
    }
    if (Platform.isLinux) {
      return widget.update.linuxUrl ?? widget.update.windowsUrl;
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return widget.update.webUrl ?? widget.update.windowsUrl;
    }
    return widget.update.apkUrl;
  }

  Future<void> _downloadAndInstall(String apkUrl) async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _status = 'جاري التنزيل...';
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await _client!.send(request).timeout(
            const Duration(minutes: 15),
          );

      if (response.statusCode != 200) {
        throw Exception('فشل التنزيل (${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/mofkarti_update_${widget.update.versionCode}.apk',
      );
      final sink = file.openWrite();
      var received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (!mounted) continue;
        setState(() {
          if (total > 0) {
            _progress = received / total;
            _status =
                'جاري التنزيل... ${(100 * _progress).toStringAsFixed(0)}%';
          } else {
            _status =
                'جاري التنزيل... ${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          }
        });
      }
      await sink.flush();
      await sink.close();

      if (!mounted) return;
      setState(() {
        _progress = 1;
        _status = 'تم التنزيل — جاري فتح المثبّت...';
      });

      final opened = await NativeHelper.installApk(file.path);
      if (!opened && mounted) {
        setState(() {
          _status =
              'تعذر فتح المثبّت. فعّل «السماح بتثبيت التطبيقات» لمفكرتي من الإعدادات ثم أعد المحاولة.';
          _downloading = false;
        });
        return;
      }

      if (mounted && !widget.update.mandatory) {
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {
          _downloading = false;
          _status = 'أكمل التثبيت من شاشة النظام';
        });
      }
    } catch (e) {
      debugPrint('APK download failed: $e');
      if (mounted) {
        setState(() {
          _downloading = false;
          _status = 'فشل التنزيل: $e';
        });
      }
    } finally {
      _client?.close();
      _client = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    return PopScope(
      canPop: !update.mandatory && !_downloading,
      child: AlertDialog(
        title: Text('تحديث متوفر ${update.versionName}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إصدارك الحالي: ${widget.currentVersion}\n'
                'الإصدار الجديد: ${update.versionName} (${update.versionCode})',
                style: const TextStyle(fontSize: 13),
              ),
              if (update.changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('ما الجديد:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...update.changelog.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $line', style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ],
              if (_downloading || _status != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _downloading && _progress > 0 && _progress < 1
                      ? _progress
                      : (_downloading ? null : 1),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Text(_status!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ],
          ),
        ),
        actions: [
          if (!update.mandatory && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('لاحقاً'),
            ),
          FilledButton(
            onPressed: _downloading ? null : _startUpdate,
            child: Text(_downloading ? 'جاري التحديث...' : 'تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
