import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeHelper {
  static const platform = MethodChannel('com.alozair.my_nots/native');

  static Future<void> toggleFloatingNote() async {
    try {
      await platform.invokeMethod('toggleFloatingNote');
    } on PlatformException catch (e) {
      debugPrint("Failed to toggle floating note: '${e.message}'.");
    }
  }

  static Future<void> updateWidget() async {
    try {
      await platform.invokeMethod('updateWidget');
    } on PlatformException catch (e) {
      debugPrint("Failed to update widget: '${e.message}'.");
    }
  }

  static Future<String?> getLaunchAction() async {
    try {
      final action = await platform.invokeMethod<String>('getLaunchAction');
      return action;
    } on PlatformException catch (e) {
      debugPrint("getLaunchAction failed: '${e.message}'.");
      return null;
    }
  }
}
