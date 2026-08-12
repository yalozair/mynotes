class TagHelper {
  static const _stopWords = {
    'في', 'من', 'إلى', 'على', 'عن', 'أن', 'إن', 'كان', 'هذا', 'هذه', 'ذلك', 'تلك',
    'التي', 'الذي', 'مع', 'بين', 'عند', 'بعد', 'قبل', 'كل', 'some', 'the', 'and',
    'or', 'for', 'with', 'not', 'you', 'your', 'is', 'are', 'was', 'were', 'a', 'an',
    'مذكرة', 'ملاحظة', 'note', 'text', 'title',
  };

  /// استخراج وسوم محلية من العنوان والمحتوى (بدون AI أو اشتراك).
  static String generateTags(String title, String content, {int maxTags = 5}) {
    final text = '$title $content'.toLowerCase();
    final words = text
        .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF#@]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();

    final hashtags = RegExp(r'#(\w+)').allMatches(text).map((m) => m.group(1)!).toList();

    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final tags = <String>{...hashtags};
    for (final e in sorted) {
      if (tags.length >= maxTags) break;
      tags.add(e.key);
    }
    return tags.take(maxTags).join(',');
  }

  static List<String> parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    return raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }
}
