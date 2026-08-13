import 'package:shared_preferences/shared_preferences.dart';

class WritingStreakHelper {
  static const _daysKey = 'writing_days_v1';

  static Future<void> markToday() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(_daysKey) ?? [];
    final today = _dayKey(DateTime.now());
    if (!days.contains(today)) {
      days.add(today);
      // Keep ~1 year
      days.sort();
      while (days.length > 400) {
        days.removeAt(0);
      }
      await prefs.setStringList(_daysKey, days);
    }
  }

  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final set = (prefs.getStringList(_daysKey) ?? []).toSet();
    if (set.isEmpty) return 0;
    var streak = 0;
    var cursor = DateTime.now();
    // Allow streak to count yesterday if not written today yet
    if (!set.contains(_dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!set.contains(_dayKey(cursor))) return 0;
    }
    while (set.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static Future<int> bestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final days = (prefs.getStringList(_daysKey) ?? [])..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var cur = 1;
    for (var i = 1; i < days.length; i++) {
      final prev = DateTime.parse(days[i - 1]);
      final now = DateTime.parse(days[i]);
      if (now.difference(prev).inDays == 1) {
        cur++;
        if (cur > best) best = cur;
      } else {
        cur = 1;
      }
    }
    return best;
  }

  static Future<int> daysWrittenThisMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getStringList(_daysKey) ?? [];
    final now = DateTime.now();
    final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return days.where((d) => d.startsWith(prefix)).length;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
