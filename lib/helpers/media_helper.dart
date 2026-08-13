import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class MediaHelper {
  static final ImagePicker _picker = ImagePicker();
  static final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _continuous = false;
  static String _lastFinal = '';
  static void Function(String text)? _onFinal;
  static void Function(String partial)? _onPartial;

  static Future<String?> pickImageAndRecognizeText(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 92, maxWidth: 2048);
      if (image == null) return null;
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> initSpeech() async {
    return await _speech.initialize(
      onStatus: (status) {
        if (_continuous && (status == 'done' || status == 'notListening')) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (_continuous && !_speech.isListening && _onFinal != null) {
              _beginListen();
            }
          });
        }
      },
    );
  }

  /// One-shot or continuous dictation.
  /// [onFinalResult] receives only newly finalized text segments.
  static void startListening(
    void Function(String text) onFinalResult, {
    bool continuous = false,
    void Function(String partial)? onPartial,
  }) {
    _continuous = continuous;
    _lastFinal = '';
    _onFinal = onFinalResult;
    _onPartial = onPartial;
    _beginListen();
  }

  static void _beginListen() {
    final onFinal = _onFinal;
    if (onFinal == null) return;
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          String delta = words;
          if (_lastFinal.isNotEmpty && words.startsWith(_lastFinal)) {
            delta = words.substring(_lastFinal.length).trim();
          }
          _lastFinal = words;
          if (delta.isNotEmpty) onFinal(delta);
          if (_continuous) {
            _lastFinal = '';
          }
        } else {
          _onPartial?.call(result.recognizedWords);
        }
      },
      listenMode: _continuous ? stt.ListenMode.dictation : stt.ListenMode.confirmation,
      partialResults: true,
      listenFor: _continuous ? const Duration(minutes: 30) : const Duration(seconds: 30),
      pauseFor: _continuous ? const Duration(seconds: 5) : const Duration(seconds: 3),
      localeId: 'ar_SA',
    );
  }

  static void stopListening() {
    _continuous = false;
    _onFinal = null;
    _onPartial = null;
    _speech.stop();
  }

  static bool get isListening => _speech.isListening;
  static bool get isContinuous => _continuous;

  static void dispose() {
    stopListening();
    _textRecognizer.close();
  }
}
