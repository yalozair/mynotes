import 'package:google_generative_ai/google_generative_ai.dart';

class AIHelper {
  // Replace with your actual API Key
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  
  static Future<String?> processWithGemini(String prompt, String content) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final response = await model.generateContent([Content.text('$prompt: $content')]);
      return response.text;
    } catch (e) {
      return null;
    }
  }
}
