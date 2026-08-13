/// مساعد الذكاء الاصطناعي معطّل افتراضياً — لا مفاتيح في المصدر.
/// فعّله لاحقاً عبر --dart-define=GEMINI_API_KEY=... إن رغبت.
class AIHelper {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static bool get isConfigured => _apiKey.isNotEmpty;

  static Future<String?> processWithGemini(String prompt, String content) async {
    if (!isConfigured) {
      return null;
    }
    // عمداً بدون تبعية google_generative_ai في البناء الافتراضي لتقليل الحجم والمخاطر.
    return null;
  }
}
