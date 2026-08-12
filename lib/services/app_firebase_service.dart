import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../helpers/sticky_note_helper.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppFirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    if (Firebase.apps.isEmpty) return;

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestNotificationPermission();
    _setupForegroundMessages();
    await _saveFcmToken();
  }

  static Future<void> _requestNotificationPermission() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  static void _setupForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'مفكرتي';
      final body = message.notification?.body ?? '';
      if (body.isNotEmpty) {
        StickyNoteHelper.showStickyNotification(
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title,
          body,
        );
      }
    });
  }

  static Future<void> _saveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  static Future<void> logError(Object error, StackTrace stack, {bool fatal = false}) async {
    if (Firebase.apps.isEmpty) return;
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }
}
