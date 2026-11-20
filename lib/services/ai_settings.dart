import 'package:shared_preferences/shared_preferences.dart';

/// Claves y opciones del asistente. Se guardan solo en este teléfono.
class AiSettings {
  AiSettings._();
  static final AiSettings instance = AiSettings._();

  static const String defaultGroqModel = 'openai/gpt-oss-120b';
  static const String defaultGeminiModel = 'gemini-flash-latest';

  String groqKey = '';
  String geminiKey = '';
  /// Buscador web gratuito (1.000 búsquedas al mes) para los conciertos.
  String tavilyKey = '';
  /// Apify: lee el Instagram de tus bares (crédito gratis mensual).
  String apifyKey = '';
  String groqModel = defaultGroqModel;
  String geminiModel = defaultGeminiModel;
  bool learn = true;
  static const List<int> maxOptions = [20, 40, 60, 80, 100];
  int maxSongs = 100;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final sp = await SharedPreferences.getInstance();
      groqKey = sp.getString('ai_groq_key') ?? '';
      geminiKey = sp.getString('ai_gemini_key') ?? '';
      tavilyKey = sp.getString('ai_tavily_key') ?? '';
      apifyKey = sp.getString('ai_apify_key') ?? '';
      groqModel = sp.getString('ai_groq_model') ?? defaultGroqModel;
      // Modelos que Groq ya retiró: usa el actual.
      if (groqModel == 'llama-3.3-70b-versatile' ||
          groqModel == 'llama-3.1-8b-instant') {
        groqModel = defaultGroqModel;
      }
      geminiModel = sp.getString('ai_gemini_model') ?? defaultGeminiModel;
      learn = sp.getBool('ai_learn') ?? true;
      maxSongs = (sp.getInt('ai_max') ?? 100).clamp(20, 100);
    } catch (_) {}
    _loaded = true;
  }

  Future<void> save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('ai_groq_key', groqKey.trim());
      await sp.setString('ai_gemini_key', geminiKey.trim());
      await sp.setString('ai_tavily_key', tavilyKey.trim());
      await sp.setString('ai_apify_key', apifyKey.trim());
      await sp.setString('ai_groq_model',
          groqModel.trim().isEmpty ? defaultGroqModel : groqModel.trim());
      await sp.setString('ai_gemini_model',
          geminiModel.trim().isEmpty ? defaultGeminiModel : geminiModel.trim());
      await sp.setBool('ai_learn', learn);
      await sp.setInt('ai_max', maxSongs);
    } catch (_) {}
  }
}
