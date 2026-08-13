import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionItem {
  final Permission permission;
  final String title;
  final String reason;

  const AppPermissionItem({
    required this.permission,
    required this.title,
    required this.reason,
  });
}

class PermissionHelper {
  /// إشعارات فقط عند التشغيل — بقية الصلاحيات عند الاستخدام (سياسة Play).
  static List<AppPermissionItem> get startupItems {
    return const [
      AppPermissionItem(
        permission: Permission.notification,
        title: 'الإشعارات',
        reason: 'لتذكيرات المذكرات واختصار المذكرة السريعة',
      ),
    ];
  }

  /// قائمة كاملة للمراجعة اليدوية من الإعدادات.
  static List<AppPermissionItem> get reviewItems {
    final items = <AppPermissionItem>[
      ...startupItems,
      const AppPermissionItem(
        permission: Permission.camera,
        title: 'الكاميرا',
        reason: 'لمسح النصوص (OCR) وإرفاق الصور عند اختيارك',
      ),
      const AppPermissionItem(
        permission: Permission.microphone,
        title: 'الميكروفون',
        reason: 'لتحويل الكلام إلى نص عند تفعيله',
      ),
    ];
    if (Platform.isAndroid) {
      items.add(const AppPermissionItem(
        permission: Permission.photos,
        title: 'معرض الصور',
        reason: 'لاختيار الصور وإرفاقها في المذكرات',
      ));
    }
    return items;
  }

  @Deprecated('Use ensureNotifications or feature-specific requests')
  static List<AppPermissionItem> get requiredItems => reviewItems;

  static Future<bool> ensureNotifications(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return _requestItems(context, startupItems, optional: true);
  }

  static Future<bool> ensureCamera(BuildContext context) async {
    return _requestSingle(
      context,
      const AppPermissionItem(
        permission: Permission.camera,
        title: 'الكاميرا',
        reason: 'لاستخدام الكاميرا لمسح النص أو التقاط صورة',
      ),
    );
  }

  static Future<bool> ensurePhotos(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return _requestSingle(
      context,
      const AppPermissionItem(
        permission: Permission.photos,
        title: 'معرض الصور',
        reason: 'لاختيار صورة من المعرض',
      ),
    );
  }

  static Future<bool> ensureMicrophone(BuildContext context) async {
    return _requestSingle(
      context,
      const AppPermissionItem(
        permission: Permission.microphone,
        title: 'الميكروفون',
        reason: 'لتحويل الصوت إلى نص',
      ),
    );
  }

  /// مراجعة يدوية من الإعدادات — لا تُستدعى عند كل تشغيل.
  static Future<bool> reviewAll(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    return _requestItems(context, reviewItems, optional: true);
  }

  @Deprecated('Use ensureNotifications / reviewAll')
  static Future<bool> ensureAllGranted(BuildContext context) => reviewAll(context);

  static Future<bool> _requestSingle(
    BuildContext context,
    AppPermissionItem item,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await item.permission.status;
    if (status.isGranted || status.isLimited) return true;
    if (!context.mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('صلاحية ${item.title}'),
        content: Text(item.reason),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقاً')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (proceed != true) return false;
    final result = await item.permission.request();
    if (result.isPermanentlyDenied && context.mounted) {
      await _showOpenSettingsDialog(context, item.title);
    }
    return result.isGranted || result.isLimited;
  }

  static Future<bool> _requestItems(
    BuildContext context,
    List<AppPermissionItem> items, {
    bool optional = false,
  }) async {
    final missing = <AppPermissionItem>[];
    for (final item in items) {
      final status = await item.permission.status;
      if (!status.isGranted && !status.isLimited) missing.add(item);
    }
    if (missing.isEmpty) return true;
    if (!context.mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: optional,
      builder: (ctx) => AlertDialog(
        title: const Text('صلاحيات التطبيق'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'سنطلب فقط الصلاحيات التالية عند الحاجة:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...missing.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${m.title}: ${m.reason}', style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقاً')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تفعيل')),
        ],
      ),
    );

    if (proceed != true) return optional;
    for (final item in missing) {
      final result = await item.permission.request();
      if (result.isPermanentlyDenied && context.mounted) {
        await _showOpenSettingsDialog(context, item.title);
      }
    }
    return await allGranted(items);
  }

  static Future<bool> requestOverlayPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) return true;
    if (!context.mounted) return false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الظهور فوق التطبيقات'),
        content: const Text(
          'لتفعيل المذكرة العائمة، اسمح للتطبيق بالظهور فوق التطبيقات الأخرى.\n\n'
          'سيتم فتح إعدادات النظام — فعّل «السماح بالظهور فوق التطبيقات الأخرى».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('فتح الإعدادات')),
        ],
      ),
    );

    if (proceed != true) return false;

    final requestResult = await Permission.systemAlertWindow.request();
    if (!requestResult.isGranted) {
      await openAppSettings();
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final after = await Permission.systemAlertWindow.status;
    if (after.isGranted) return true;

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تفعيل الصلاحية يدوياً'),
          content: const Text(
            'لم تُفعَّل الصلاحية بعد.\n'
            'افتح إعدادات التطبيق ← «الظهور فوق التطبيقات الأخرى» ← فعّل.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('فتح الإعدادات'),
            ),
          ],
        ),
      );
    }
    return await Permission.systemAlertWindow.status.isGranted;
  }

  static Future<bool> allGranted([List<AppPermissionItem>? items]) async {
    for (final item in items ?? reviewItems) {
      final status = await item.permission.status;
      if (!status.isGranted && !status.isLimited) return false;
    }
    return true;
  }

  static Future<void> _showOpenSettingsDialog(BuildContext context, String name) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفعيل $name'),
        content: Text('تم رفض صلاحية $name. افتح إعدادات التطبيق لتفعيلها يدوياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }
}
