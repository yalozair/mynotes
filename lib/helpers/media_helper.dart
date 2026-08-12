import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static final stt.SpeechToText _speech = stt.SpeechToText();

  // OCR: Pick image and extract text
  static Future<String?> pickImageAndRecognizeText(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (_) {
      return null;
    }
  }

  // STT: Initialize speech
  static Future<bool> initSpeech() async {
    return await _speech.initialize();
  }

  // STT: Start listening
  static void startListening(Function(String) onResult) {
    _speech.listen(onResult: (result) {
      onResult(result.recognizedWords);
    });
  }

  // STT: Stop listening
  static void stopListening() {
    _speech.stop();
  }

  static bool get isListening => _speech.isListening;

  static void dispose() {
    _textRecognizer.close();
  }
}
