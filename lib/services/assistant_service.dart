import 'dart:convert';

import '../models/song.dart';
import 'ai_client.dart';
import 'ai_settings.dart';
import 'artist_pools.dart';
import 'mix_service.dart';
import 'stats_service.dart';

class AssistantResult {
  final String reply;
  final String title;
  final List<Song> songs;

  /// 'Groq', 'Gemini' o 'Reglas simples'.
  final String source;

  /// Avisos (por ejemplo, por qué falló un servicio).
  final String? note;

  const AssistantResult(this.reply, this.title, this.songs, this.source,
      [this.note]);
}

/// Cerebro del asistente: intenta Groq, luego Gemini y, si ninguno responde,
/// usa reglas simples con los mixes y artistas que ya conoce la app.
class AssistantService {
  AssistantService._();
  static final AssistantService instance = AssistantService._();

  static const String _system = '''
Eres el asistente musical de una app de rock llamada RockPlay IA. Hablas en español, con tono cercano y breve.
Armas listas de canciones REALES de rock (cualquier época y subgénero, incluido rock en español) según lo que pida la persona: estado de ánimo, momento del día, actividad, artistas parecidos o descubrimiento.
Reglas:
- Devuelve SOLO un objeto JSON con esta forma exacta: {"reply":"texto corto (máx. 2 frases)","title":"nombre corto de la lista","songs":[{"artist":"...","title":"..."}]}
- Entre 90 y 100 canciones, todas distintas. Mezcla canciones conocidas con algunas menos conocidas que encajen con sus gustos.
- No repitas artistas más de 2 veces. No inventes canciones: si dudas de una, no la incluyas.
- Si la persona pide cambiar la lista anterior (más tranquilo, más pesado, solo en español...), ajusta según eso.
- Usa el contexto de gustos solo para personalizar; no lo recites.
''';

  Future<String> _context() async {
    await AiSettings.instance.load();
    if (!AiSettings.instance.learn) return '';
    final b = StringBuffer();
    try {
      final plays = await StatsService.instance.plays(days: 60);
      final top = StatsService.topArtists(plays, n: 8);
      if (top.isNotEmpty) {
        b.write('Artistas que más escucha últimamente: ');
        b.writeln(top.map((e) => e.name).join(', '));
      }
      final fav = await MixService.personalArtists();
      if (fav.isNotEmpty) {
        b.write('Artistas de sus favoritos e historial: ');
        b.writeln(fav.take(12).join(', '));
      }
    } catch (_) {}
    final h = DateTime.now().hour;
    final part = h < 6
        ? 'madrugada'
        : h < 12
            ? 'mañana'
            : h < 19
                ? 'tarde'
                : 'noche';
    b.write('Momento del día ahora: $part.');
    return b.toString();
  }

  Future<AssistantResult> ask(String text, List<AiMessage> history) async {
    await AiSettings.instance.load();
    final ctx = await _context();
    final system = ctx.isEmpty ? _system : '$_system\nContexto:\n$ctx';
    final msgs = <AiMessage>[
      ...history.length > 6 ? history.sublist(history.length - 6) : history,
      AiMessage(true, text),
    ];

    final notes = <String>[];
    final tries = <MapEntry<String, Future<String> Function()>>[
      MapEntry('Gemini', () => AiClient.instance.gemini(system, msgs)),
      MapEntry('Groq', () => AiClient.instance.groq(system, msgs)),
    ];
    for (final t in tries) {
      try {
        final raw = await t.value();
        final r = _parse(raw, t.key);
        if (r != null) {
          return AssistantResult(r.reply, r.title, r.songs, t.key,
              notes.isEmpty ? null : notes.join(' · '));
        }
        notes.add('${t.key}: respuesta no válida');
      } on AiFailure catch (e) {
        if (e.reason != 'sin clave') notes.add(e.toString());
      } catch (_) {
        notes.add('${t.key}: error inesperado');
      }
    }
    final r = await _rules(text);
    return AssistantResult(r.reply, r.title, r.songs, 'Reglas simples',
        notes.isEmpty ? null : notes.join(' · '));
  }

  AssistantResult? _parse(String raw, String source) {
    try {
      final a = raw.indexOf('{');
      final z = raw.lastIndexOf('}');
      if (a < 0 || z <= a) return null;
      final j = jsonDecode(raw.substring(a, z + 1));
      final songs = <Song>[];
      final seen = <String>{};
      for (final e in (j['songs'] as List? ?? const [])) {
        if (e is! Map) continue;
        final artist = (e['artist'] ?? '').toString().trim();
        final title = (e['title'] ?? '').toString().trim();
        if (artist.isEmpty || title.isEmpty) continue;
        if (!seen.add('${artist.toLowerCase()}|${title.toLowerCase()}')) {
          continue;
        }
        songs.add(Song(
            title: title, artist: artist, query: '$artist $title'));
      }
      if (songs.length < 3) return null;
      final title = (j['title'] ?? '').toString().trim();
      final reply = (j['reply'] ?? '').toString().trim();
      return AssistantResult(
        reply.isEmpty ? 'Armé esta lista para ti.' : reply,
        title.isEmpty ? 'Lista del asistente' : title,
        songs,
        source,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- Reglas simples (sin IA) ----------

  static const Map<String, List<String>> _keywords = {
    'Energía': ['energ', 'pesado', 'fuerte', 'animad', 'subir', 'metal'],
    'Para entrenar': ['entren', 'gym', 'gimnasio', 'correr', 'ejercicio'],
    'Para manejar': ['manej', 'carretera', 'viaje', 'conducir'],
    'Tranquilo': [
      'tranquil',
      'relaj',
      'calma',
      'melanc',
      'triste',
      'concentr',
      'estudi',
      'dormir',
      'lento',
      'suave'
    ],
    'Nostalgia': ['nostalg', 'clásic', 'clasic', 'viejo', 'recuerd', 'antigu'],
  };

  Future<AssistantResult> _rules(String text) async {
    final t = text.toLowerCase();
    final artists = <String>[];
    String title = 'Mix del asistente';
    String reply = 'Sin IA disponible, armé esta lista con mis reglas simples.';

    for (final e in _keywords.entries) {
      if (e.value.any(t.contains)) {
        final m = MixService.mood.firstWhere((x) => x.title == e.key);
        artists.addAll(MixService.pool(m));
        title = m.title;
        reply = 'Armé una lista "${m.title}" para ti (modo reglas simples).';
        break;
      }
    }
    if (t.contains('español') || t.contains('espanol')) {
      artists.addAll(kMixArtistPools['Rock en español'] ?? const <String>[]);
      title = 'Rock en español';
      reply = 'Armé una lista de rock en español (modo reglas simples).';
    }
    if (t.contains('nuev') || t.contains('descubr') || t.contains('algo diferente')) {
      artists.addAll(await MixService.personalArtists());
      title = 'Para descubrir';
    }
    if (artists.isEmpty) {
      final personal = await MixService.personalArtists();
      artists.addAll(personal);
      artists.addAll(kMixArtistPools['Rock clásico'] ?? const <String>[]);
      title = 'Mix del asistente';
    }
    final uniq = <String>{...artists}.toList();
    var songs = <Song>[];
    await for (final l in MixService.buildMix(uniq, pick: 40, perArtist: 3)) {
      songs = l;
    }
    return AssistantResult(reply, title, songs, 'Reglas simples');
  }
}
