import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationTapHandler = void Function(String? payload);

class StickyNoteHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static NotificationTapHandler? onNotificationTap;
  static const quickNoteId = 999001;

  static Future<void> init({NotificationTapHandler? onTap}) async {
    onNotificationTap = onTap;
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'مفكرتي',
          appUserModelId: 'com.alozair.my_nots.MyNotesApp',
          guid: '778a7c24-4f0b-4e00-b6f7-c2579698c0b2',
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        onNotificationTap?.call(details.payload);
      },
    );
  }

  static Future<void> showStickyNotification(int id, String title, String content) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'sticky_notes_channel',
      'Sticky Notes',
      channelDescription: 'Notifications for pinned notes',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    final preview = content.trim().replaceAll('\n', ' ');
    final body = preview.length > 80 ? '${preview.substring(0, 80)}…' : preview;
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body.isEmpty ? 'ملاحظة مثبتة' : body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  static Future<void> showQuickNoteShortcut() async {
    const android = AndroidNotificationDetails(
      'quick_note_channel',
      'مذكرة سريعة',
      channelDescription: 'اختصار لإنشاء مذكرة جديدة',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: true,
      autoCancel: false,
    );
    await _notificationsPlugin.show(
      id: quickNoteId,
      title: 'مذكرة سريعة',
      body: 'اضغط لإنشاء مذكرة جديدة',
      notificationDetails: const NotificationDetails(android: android),
      payload: 'quick_note',
    );
  }

  static Future<void> removeStickyNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> removeQuickNoteShortcut() async {
    await _notificationsPlugin.cancel(id: quickNoteId);
  }
}
