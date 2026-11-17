import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_settings.dart';

class AiMessage {
  final bool fromUser;
  final String text;
  const AiMessage(this.fromUser, this.text);
}

class AiFailure implements Exception {
  final String provider;
  final String reason;
  const AiFailure(this.provider, this.reason);
  @override
  String toString() => '$provider: $reason';
}

/// Llama a Groq o a Gemini (planes gratuitos). Devuelve el texto de la
/// respuesta (JSON) o lanza [AiFailure].
class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  static const Duration _timeout = Duration(seconds: 25);

  Future<String> groq(String system, List<AiMessage> msgs) async {
    final s = AiSettings.instance;
    if (s.groqKey.trim().isEmpty) throw const AiFailure('Groq', 'sin clave');
    try {
      final r = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${s.groqKey.trim()}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': s.groqModel,
              'temperature': 0.8,
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': system},
                for (final m in msgs)
                  {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
              ],
            }),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) {
        throw AiFailure('Groq', _why(r.statusCode));
      }
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final t = j['choices'][0]['message']['content'];
      if (t is! String || t.trim().isEmpty) {
        throw const AiFailure('Groq', 'respuesta vacía');
      }
      return t;
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure('Groq', 'sin conexión o tardó demasiado');
    }
  }

  Future<String> gemini(String system, List<AiMessage> msgs) async {
    final s = AiSettings.instance;
    if (s.geminiKey.trim().isEmpty) {
      throw const AiFailure('Gemini', 'sin clave');
    }
    try {
      final r = await http
          .post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
                '${s.geminiModel}:generateContent'),
            headers: {
              'x-goog-api-key': s.geminiKey.trim(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': system}
                ]
              },
              'contents': [
                for (final m in msgs)
                  {
                    'role': m.fromUser ? 'user' : 'model',
                    'parts': [
                      {'text': m.text}
                    ],
                  },
              ],
              'generationConfig': {
                'temperature': 0.8,
                'responseMimeType': 'application/json',
              },
            }),
          )
          .timeout(_timeout);
      if (r.statusCode != 200) {
        throw AiFailure('Gemini', _why(r.statusCode));
      }
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final t = j['candidates'][0]['content']['parts'][0]['text'];
      if (t is! String || t.trim().isEmpty) {
        throw const AiFailure('Gemini', 'respuesta vacía');
      }
      return t;
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure('Gemini', 'sin conexión o tardó demasiado');
    }
  }

  static String _why(int code) {
    if (code == 429) return 'límite diario o por minuto alcanzado';
    if (code == 401 || code == 403) return 'clave rechazada';
    if (code == 404) return 'modelo no encontrado';
    return 'error $code';
  }
}
