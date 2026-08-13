import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/note.dart';

class ReminderHelper {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  static Future<void> scheduleReminder(Note note) async {
    if (!_ready || note.id == null || note.reminderTime <= 0) return;
    final when = DateTime.fromMillisecondsSinceEpoch(note.reminderTime);
    if (when.isBefore(DateTime.now())) return;

    final android = AndroidNotificationDetails(
      'reminders_channel',
      'تذكيرات المذكرات',
      channelDescription: 'تذكيرات المذكرات المجدولة',
      importance: Importance.high,
      priority: Priority.high,
      actions: const [
        AndroidNotificationAction('done', 'تم'),
        AndroidNotificationAction('snooze', 'تأجيل ساعة'),
      ],
    );
    final details = NotificationDetails(android: android);

    DateTimeComponents? repeat;
    if (note.reminderRepeat == 1) {
      repeat = DateTimeComponents.time; // daily
    } else if (note.reminderRepeat == 2) {
      repeat = DateTimeComponents.dayOfWeekAndTime; // weekly
    } else if (note.reminderRepeat == 3) {
      repeat = DateTimeComponents.dayOfMonthAndTime; // monthly
    }

    await _plugin.zonedSchedule(
      id: note.id!,
      title: note.title,
      body: note.content == '••••••••' ? 'لديك تذكير بمذكرة' : note.content,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: repeat,
    );
  }

  static Future<void> cancelReminder(int noteId) async {
    await _plugin.cancel(id: noteId);
  }

  static Future<void> rescheduleAll(List<Note> notes) async {
    for (final n in notes) {
      if (n.reminderTime > 0 && n.id != null) {
        await scheduleReminder(n);
      }
    }
  }
}
