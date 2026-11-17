import 'package:shared_preferences/shared_preferences.dart';

/// Claves y opciones del asistente. Se guardan solo en este teléfono.
class AiSettings {
  AiSettings._();
  static final AiSettings instance = AiSettings._();

  static const String defaultGroqModel = 'openai/gpt-oss-120b';
  static const String defaultGeminiModel = 'gemini-flash-latest';

  String groqKey = '';
  String geminiKey = '';
  String groqModel = defaultGroqModel;
  String geminiModel = defaultGeminiModel;
  bool learn = true;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      groqKey = sp.getString('ai_groq_key') ?? '';
      geminiKey = sp.getString('ai_gemini_key') ?? '';
      groqModel = sp.getString('ai_groq_model') ?? defaultGroqModel;
      // Modelos que Groq ya retiró: usa el actual.
      if (groqModel == 'llama-3.3-70b-versatile' ||
          groqModel == 'llama-3.1-8b-instant') {
        groqModel = defaultGroqModel;
      }
      geminiModel = sp.getString('ai_gemini_model') ?? defaultGeminiModel;
      learn = sp.getBool('ai_learn') ?? true;
    } catch (_) {}
    _loaded = true;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('ai_groq_key', groqKey.trim());
      await sp.setString('ai_gemini_key', geminiKey.trim());
      await sp.setString('ai_groq_model',
          groqModel.trim().isEmpty ? defaultGroqModel : groqModel.trim());
      await sp.setString('ai_gemini_model',
          geminiModel.trim().isEmpty ? defaultGeminiModel : geminiModel.trim());
      await sp.setBool('ai_learn', learn);
    } catch (_) {}
  }
}
