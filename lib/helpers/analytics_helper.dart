import 'package:flutter/foundation.dart';

/// أحداث تحليلات بسيطة — Crashlytics مجاني ضمن Firebase (بدون اشتراك).
class AnalyticsHelper {
  static void logEvent(String name, {Map<String, Object>? params}) {
    debugPrint('Analytics: $name ${params ?? {}}');
    // يمكن ربط Firebase Analytics لاحقاً عند الحاجة
  }

  static void noteCreated() => logEvent('note_created');
  static void noteSaved() => logEvent('note_saved');
  static void templateUsed(String id) => logEvent('template_used', params: {'template': id});
  static void backupExported() => logEvent('backup_exported');
  static void backupImported(int count) => logEvent('backup_imported', params: {'count': count});
  static void reminderSet() => logEvent('reminder_set');
  static void onboardingCompleted() => logEvent('onboarding_completed');
  static void quickNoteOpened() => logEvent('quick_note_opened');
}
