import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';
import 'stats_service.dart';

/// Un concierto encontrado en internet.
class Concert {
  final String band;
  final String city;
  final String venue;
  /// Nula cuando el concierto está anunciado sin fecha exacta.
  final DateTime? date;
  /// Lo que se sabe de la fecha si no es exacta ("Marzo 2027").
  final String when;
  final String time;
  final String tickets;
  final String source;
  /// Género principal (punk, grunge, metal…).
  final String genre;

  const Concert({
    required this.band,
    required this.city,
    required this.venue,
    required this.date,
    this.when = '',
    this.time = '',
    this.tickets = '',
    this.source = '',
    this.genre = '',
  });

  Map<String, dynamic> toJson() => {
        'banda': band,
        'ciudad': city,
        'lugar': venue,
        'fecha': date == null ? '' : _ymd(date!),
        'cuando': when,
        'hora': time,
        'boletas': tickets,
        'fuente': source,
        'genero': genre,
      };

  static Concert? fromJson(dynamic j) {
    if (j is! Map) return null;
    String s(String k) => (j[k] ?? '').toString().trim();
    final band = s('banda');
    final date = DateTime.tryParse(s('fecha'));
    if (band.isEmpty) return null;
    return Concert(
      band: band,
      city: s('ciudad'),
      venue: s('lugar'),
      date: date == null ? null : DateTime(date.year, date.month, date.day),
      when: date == null ? (s('cuando').isEmpty ? 'Por confirmar' : s('cuando')) : '',
      time: s('hora'),
      tickets: _url(s('boletas')).isNotEmpty
          ? _url(s('boletas'))
          : (isTicketSite(s('fuente')) ? _url(s('fuente')) : ''),
      source: _url(s('fuente')),
      genre: s('genero'),
    );
  }

  /// Boleterías conocidas: si la fuente es una de ellas, es el enlace de compra.
  static const List<String> ticketSites = [
    'tuboleta.com',
    'eticket.co',
    'ticketmaster.co',
    'ticketmaster.com',
    'taquillalive.com',
    'primerafila.com.co',
    'colboletos.com',
    'passline.com',
    'livepass.com',
    'ticketshop.com.co',
  ];

  static bool isTicketSite(String url) {
    final h = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return h.isNotEmpty && ticketSites.any((t) => h == t || h.endsWith('.$t'));
  }

  /// Búsqueda en Google de boletas para cuando no hay enlace directo.
  String get ticketSearchUrl => Uri.https('www.google.com', '/search', {
        'q': '$band ${city.isEmpty ? 'Colombia' : city} boletas',
      }).toString();

  static String _url(String u) =>
      u.startsWith('http://') || u.startsWith('https://') ? u : '';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const List<String> kMonthsShort = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];
const List<String> kMonthsLong = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class ConcertState {
  final List<Concert> items;
  final DateTime? updatedAt;
  final bool loading;
  final String? error;
  final bool noKey;

  const ConcertState({
    this.items = const [],
    this.updatedAt,
    this.loading = false,
    this.error,
    this.noKey = false,
  });
}

/// Busca en internet (Gemini + Google) los conciertos de rock en Colombia
/// de los próximos 12 meses. Guarda el resultado y solo vuelve a buscar
/// cada 3 días o cuando el usuario lo pide.
class ConcertService {
  ConcertService._();
  static final ConcertService instance = ConcertService._();

  static const Duration refreshEvery = Duration(days: 3);
  static const String _cacheKey = 'concerts_cache_v1';

  /// Bares de rock que el usuario sigue; se buscan uno por uno.
  static const List<String> defaultBars = [
    'Barnaby Jones',
    'Kings Rock',
    'La Cúpula',
    'Virus Pub',
    'Jungle Burger',
  ];
  static const String _barsKey = 'concert_bars_v1';
  List<String> bars = List<String>.of(defaultBars);

  Future<void> saveBars(List<String> list) async {
    bars = list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_barsKey, bars);
    } catch (_) {}
  }

  /// ¿El lugar del concierto es uno de los bares guardados?
  bool isFavoriteBar(Concert c) {
    final v = '${c.venue} ${c.band}'.toLowerCase();
    return bars.any((b) => b.isNotEmpty && v.contains(b.toLowerCase()));
  }

  final ValueNotifier<ConcertState> state =
      ValueNotifier<ConcertState>(const ConcertState());
  bool _cacheRead = false;

  /// Lee la caché y busca de nuevo si está vieja.
  Future<void> ensureLoaded() async {
    if (!_cacheRead) {
      _cacheRead = true;
      await _readCache();
    }
    final s = state.value;
    if (s.loading) return;
    final old = s.updatedAt == null ||
        DateTime.now().difference(s.updatedAt!) > refreshEvery;
    if (old) await refresh();
  }

  Future<void> refresh() async {
    if (state.value.loading) return;
    final prev = state.value;
    state.value = ConcertState(
        items: prev.items, updatedAt: prev.updatedAt, loading: true);
    await AiSettings.instance.load();
    if (AiSettings.instance.geminiKey.trim().isEmpty &&
        AiSettings.instance.groqKey.trim().isEmpty) {
      state.value = ConcertState(
          items: prev.items, updatedAt: prev.updatedAt, noKey: true);
      return;
    }
    try {
      final list = _merge(await _search(), prev.items);
      final now = DateTime.now();
      state.value = ConcertState(items: list, updatedAt: now);
      _writeCache(list, now);
    } catch (e) {
      state.value = ConcertState(
        items: _upcoming(prev.items),
        updatedAt: prev.updatedAt,
        error: e is String ? e : 'No se pudo buscar conciertos.',
      );
    }
  }

  Future<void> _readCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getStringList(_barsKey);
      if (saved != null) bars = saved;
      final raw = sp.getString(_cacheKey);
      if (raw == null) return;
      final j = jsonDecode(raw);
      final at = DateTime.tryParse((j['at'] ?? '').toString());
      final items = <Concert>[
        for (final e in (j['items'] as List? ?? const []))
          if (Concert.fromJson(e) != null) Concert.fromJson(e)!,
      ];
      state.value = ConcertState(items: _upcoming(items), updatedAt: at);
    } catch (_) {}
  }

  Future<void> _writeCache(List<Concert> list, DateTime at) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          _cacheKey,
          jsonEncode({
            'at': at.toIso8601String(),
            'items': [for (final c in list) c.toJson()],
          }));
    } catch (_) {}
  }

  /// Une lo nuevo con lo que ya se había encontrado: una búsqueda nueva
  /// puede dejar por fuera un concierto que sigue vigente (p. ej. Slipknot).
  /// Los viejos se quedan hasta que pase su fecha.
  static List<Concert> _merge(List<Concert> fresh, List<Concert> old) {
    String key(Concert c) {
      final b = c.band.toLowerCase().split('(').first.trim();
      return c.date == null ? b : '$b|${_ymd(c.date!)}';
    }
    final have = {for (final c in fresh) key(c)};
    final bands = {
      for (final c in fresh) c.band.toLowerCase().split('(').first.trim()
    };
    return _upcoming([
      ...fresh,
      for (final c in old)
        if (!have.contains(key(c)) &&
            // Si ahora tiene fecha exacta, descarta el viejo "por confirmar".
            !(c.date == null &&
                bands.contains(c.band.toLowerCase().split('(').first.trim())))
          c,
    ]);
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _limit() {
    final t = _today();
    return DateTime(t.year + 1, t.month, t.day);
  }

  /// Quita los que ya pasaron o están a más de 12 meses, ordena por fecha,
  /// deja al final los de fecha por confirmar y quita repetidos.
  static List<Concert> _upcoming(List<Concert> list) {
    final from = _today();
    final to = _limit();
    final seen = <String>{};
    final dated = <Concert>[];
    final tbd = <Concert>[];
    for (final c in list) {
      final d = c.date;
      if (d != null && (d.isBefore(from) || d.isAfter(to))) continue;
      final k = '${c.band.toLowerCase()}|${d == null ? '' : _ymd(d)}';
      if (!seen.add(k)) continue;
      (d == null ? tbd : dated).add(c);
    }
    dated.sort((a, b) => a.date!.compareTo(b.date!));
    return [...dated, ...tbd];
  }

  Future<List<Concert>> _search() async {
    final s = AiSettings.instance;
    final from = _ymd(_today());
    final to = _ymd(_limit());
    final prompt =
        'Hoy es $from. Busca en internet los conciertos y festivales de rock '
        'que se van a presentar en Colombia entre $from y $to (los próximos '
        '12 meses). Incluye todos los géneros del rock: rock clásico, hard '
        'rock, metal y sus variantes, punk, hardcore, ska punk, grunge, rock '
        'alternativo, indie rock, post-punk, stoner y rock en español; '
        'bandas internacionales y '
        'colombianas; en cualquier ciudad del país. Revisa varias fuentes '
        '(boleterías como Tuboleta, eTicket, Ticketmaster y Taquilla Live, '
        'medios de música y redes oficiales de los festivales). Incluye solo '
        'eventos anunciados oficialmente, con fecha dentro de ese rango. No '
        'inventes nada: si no conoces un dato, déjalo vacío. Para un festival '
        'usa como "banda" el nombre del festival seguido de las bandas '
        'principales entre paréntesis. Si un concierto ya está anunciado '
        'pero aún no tiene fecha exacta, inclúyelo igual: deja "fecha" vacía '
        'y pon en "cuando" lo que se sepa (por ejemplo "Marzo 2027" o '
        '"Por confirmar"). Incluye también los que aún no tienen boletería '
        'abierta.\n'
        'Responde SOLO con JSON válido, sin texto adicional, con esta forma:\n'
        '{"conciertos":[{"banda":"","ciudad":"","lugar":"","fecha":"AAAA-MM-DD o vacío","cuando":"",'
        '"hora":"","boletas":"url de compra o vacío","fuente":"url donde se '
        'anunció","genero":"rock|metal|punk|grunge|alternativo|indie|rock en español|festival"}]}';

    final errors = <String>[];
    // 1) Tavily busca en la web y Gemini/Groq (sin búsqueda) ordenan.
    if (s.tavilyKey.trim().isNotEmpty) {
      try {
        return await _viaTavily(s.tavilyKey.trim(), from, to);
      } catch (e) {
        errors.add('Tavily: $e');
      }
    }
    final geminiKey = s.geminiKey.trim();
    if (geminiKey.isNotEmpty) {
      for (final model in <String>{s.geminiModel, 'gemini-2.5-flash'}) {
        try {
          return _parse(await _gemini(model, geminiKey, prompt));
        } catch (e) {
          errors.add('Gemini ($model): $e');
        }
      }
    }
    final groqKey = s.groqKey.trim();
    if (groqKey.isNotEmpty) {
      for (final model in const ['groq/compound', 'groq/compound-mini']) {
        try {
          return _parse(await _groq(model, groqKey, prompt));
        } catch (e) {
          errors.add('Groq ($model): $e');
        }
      }
    }
    debugPrint('Conciertos: ${errors.join(' | ')}');
    if (errors.isEmpty) throw 'Falta una clave de Gemini o Groq.';
    // Muestra el error de la opción principal (Tavily si hay clave).
    throw 'No se pudo buscar en internet (${errors.first}). Intenta más tarde.';
  }

  /// Detalle de la última búsqueda (para revisar qué encontró cada grupo).
  final ValueNotifier<String> lastLog = ValueNotifier<String>('');

  /// Busca por grupos, en orden de prioridad, y ordena cada grupo por
  /// separado: así una respuesta larga no se corta y lo importante (tus
  /// bandas, escenarios grandes, tus bares) nunca queda al final.
  Future<List<Concert>> _viaTavily(String key, String from, String to) async {
    final now = DateTime.now();
    final y1 = now.year;
    final y2 = y1 + 1;
    final mes = kMonthsLong[now.month - 1].toLowerCase();
    var favs = <String>[];
    try {
      final plays = await StatsService.instance.plays(days: 120);
      favs = [
        for (final a in StatsService.topArtists(plays, n: 8))
          StatsService.cleanArtist(a.name)
      ].where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {}

    Map<String, dynamic> q(String text, [int n = 6]) =>
        {'query': text, 'max_results': n};
    final groups = <MapEntry<String, List<Map<String, dynamic>>>>[
      MapEntry('Tus bandas', [
        for (final a in favs) q('$a concierto Colombia $y1 $y2', 4),
      ]),
      MapEntry('Escenarios grandes', [
        q('Vive Claro Bogotá conciertos $y2'),
        q('Movistar Arena Bogotá conciertos $y2 rock metal'),
        q('gira Sudamérica $y2 Bogotá confirmado rock metal'),
        {
          ...q('concierto rock metal Colombia $y1 $y2', 8),
          'include_domains': Concert.ticketSites,
        },
      ]),
      MapEntry('Bares de Medellín', [
        for (final b in bars) q('"$b" Medellín rock', 4),
        {
          ...q('rock bar Medellín $mes $y1', 8),
          'include_domains': const [
            'eventbrite.co',
            'eventbrite.com',
            'passline.com',
            'tuboleta.com',
          ],
        },
        q('toques de rock en bares de Medellín $mes $y1'),
      ]),
      MapEntry('Medellín', [
        q('agenda conciertos rock punk metal Medellín $mes $y1'),
        q('conciertos rock Medellín $y1 $y2'),
      ]),
      MapEntry('Géneros', [
        q('conciertos de rock en Colombia $y1 $y2'),
        q('conciertos de metal en Colombia $y1 $y2'),
        q('conciertos punk hardcore ska Colombia $y1 $y2'),
        q('conciertos grunge rock alternativo indie Colombia $y1 $y2'),
        q('rock en español gira Colombia $y1 $y2'),
      ]),
      MapEntry('Festivales', [
        q('festivales de rock Colombia $y2 cartel confirmado'),
        q('bandas internacionales de rock gira Colombia $y2 boletas'),
      ]),
    ];

    final seen = <String>{};
    final all = <Concert>[];
    final log = <String>[];
    String? firstErr;
    var okGroups = 0;
    for (final g in groups) {
      if (g.value.isEmpty) continue;
      final found = <String>[];
      String? searchErr;
      for (final job in g.value) {
        try {
          final r = await http
              .post(
                Uri.parse('https://api.tavily.com/search'),
                headers: {
                  'Authorization': 'Bearer $key',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'search_depth': 'basic', ...job}),
              )
              .timeout(const Duration(seconds: 30));
          if (r.statusCode != 200) {
            searchErr = r.statusCode == 401 || r.statusCode == 403
                ? 'clave de Tavily rechazada'
                : r.statusCode == 429 || r.statusCode == 432
                    ? 'se acabaron las búsquedas gratis de Tavily'
                    : 'Tavily error ${r.statusCode}';
            if (r.statusCode == 401 || r.statusCode == 403) {
              lastLog.value = searchErr;
              throw searchErr;
            }
            continue;
          }
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          for (final it in (j['results'] as List? ?? const [])) {
            if (it is! Map) continue;
            final url = (it['url'] ?? '').toString();
            if (url.isEmpty || !seen.add(url)) continue;
            var content = (it['content'] ?? '').toString();
            if (content.length > 500) content = content.substring(0, 500);
            found.add('- ${it['title'] ?? ''}\n  URL: $url\n  $content');
          }
        } on String {
          rethrow;
        } catch (_) {
          searchErr = 'sin conexión';
        }
      }
      if (found.isEmpty) {
        log.add('${g.key}: 0 resultados${searchErr == null ? '' : ' ($searchErr)'}');
        continue;
      }
      try {
        final list = await _organize(found.join('\n'), from, to);
        all.addAll(list);
        okGroups++;
        log.add('${g.key}: ${found.length} resultados → ${list.length} conciertos');
      } catch (e) {
        firstErr ??= '$e';
        log.add('${g.key}: ${found.length} resultados → error: $e');
      }
    }
    lastLog.value = log.join('\n');
    if (okGroups == 0) {
      throw firstErr ?? 'Tavily no encontró resultados';
    }
    return _upcoming(all);
  }

  /// Pide a Gemini (o Groq) que convierta resultados de búsqueda en la lista.
  Future<List<Concert>> _organize(String results, String from, String to) async {
    final system =
        'Extrae conciertos de rock de estos resultados de búsqueda. Hoy es '
        '$from. Usa SOLO la información de los resultados, no inventes nada. '
        'Incluye conciertos, festivales y toques en bares de cualquier género '
        'del rock (hard rock, metal, punk, hardcore, ska punk, grunge, '
        'alternativo, indie, post-punk, stoner, rock en español) que se hagan '
        'en Colombia entre $from y $to. Fíjate bien en el AÑO: los resultados '
        'pueden traer noticias viejas de la misma banda; descarta solo lo que '
        'ya pasó y conserva el anuncio nuevo. Si un evento está anunciado sin '
        'fecha exacta, deja "fecha" vacía y pon en "cuando" lo que se sepa. '
        'En "fuente" pon la URL del resultado. Si la URL es de una boletería '
        'o de Eventbrite, ponla también en "boletas". Para festivales usa como '
        '"banda" el nombre del festival y entre paréntesis las bandas '
        'principales. En "lugar" pon el escenario o el nombre del bar. Si no '
        'hay ningún concierto, responde {"conciertos":[]}. Responde solo con '
        'JSON: {"conciertos":[{"banda":"","ciudad":"","lugar":"",'
        '"fecha":"AAAA-MM-DD o vacío","cuando":"","hora":"","boletas":"",'
        '"fuente":"","genero":""}]}';
    final errs = <String>[];
    final s = AiSettings.instance;
    final gKey = s.geminiKey.trim();
    if (gKey.isNotEmpty) {
      for (final model in <String>{s.geminiModel, 'gemini-2.5-flash'}) {
        try {
          return _parse(await _gemini(
              model, gKey, '$system\n\nResultados de búsqueda:\n$results',
              search: false));
        } catch (e) {
          errs.add('Gemini: $e');
        }
      }
    }
    final qKey = s.groqKey.trim();
    if (qKey.isNotEmpty) {
      final short =
          results.length > 14000 ? results.substring(0, 14000) : results;
      for (final model in <String>{s.groqModel, 'openai/gpt-oss-20b'}) {
        try {
          return _parse(await _groq(
              model, qKey, '$system\n\nResultados de búsqueda:\n$short',
              json: true));
        } catch (e) {
          errs.add('Groq: $e');
        }
      }
    }
    throw errs.isEmpty ? 'falta clave de Gemini o Groq' : errs.join('; ');
  }

  static String _why(int code) {
    if (code == 429) return 'límite alcanzado o búsqueda no incluida en el plan gratis';
    if (code == 401 || code == 403) return 'clave rechazada';
    if (code == 404 || code == 400) return 'modelo no disponible';
    return 'error $code';
  }

  Future<String> _gemini(String model, String key, String prompt,
      {bool search = true}) async {
    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
                '$model:generateContent'),
            headers: {'x-goog-api-key': key, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ],
                }
              ],
              if (search)
                'tools': [
                  {'google_search': {}}
                ],
              'generationConfig': {
                'temperature': 0.2,
                'maxOutputTokens': 16000,
                if (!search) 'responseMimeType': 'application/json',
                if (!search)
                  'thinkingConfig': model.contains('2.5')
                      ? {'thinkingBudget': 0}
                      : {'thinkingLevel': 'low'},
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw 'sin conexión o tardó demasiado';
    }
    if (r.statusCode != 200) throw _why(r.statusCode);
    String reason = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final c = j['candidates'][0];
      reason = (c['finishReason'] ?? '').toString();
      final parts = c['content']['parts'] as List;
      final t = parts
          .where((p) => p is Map && p['thought'] != true)
          .map((p) => (p as Map)['text'] ?? '')
          .join('\n');
      if (t.trim().isNotEmpty) return t;
    } catch (_) {}
    throw reason.isEmpty || reason == 'STOP'
        ? 'respuesta vacía'
        : 'respuesta cortada ($reason)';
  }

  /// Groq Compound busca en la web por su cuenta.
  Future<String> _groq(String model, String key, String prompt,
      {bool json = false}) async {
    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0.2,
              if (json) 'response_format': {'type': 'json_object'},
              if (model.startsWith('openai/gpt-oss')) 'reasoning_effort': 'low',
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw 'sin conexión o tardó demasiado';
    }
    if (r.statusCode != 200) throw _why(r.statusCode);
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final t = j['choices'][0]['message']['content'];
      if (t is String && t.trim().isNotEmpty) return t;
    } catch (_) {}
    throw 'respuesta vacía';
  }

  static List<Concert> _parse(String text) {
    final t = text.trim();
    final obj = t.indexOf('{');
    final arr = t.indexOf('[');
    final useArr = arr >= 0 && (obj < 0 || arr < obj);
    final start = useArr ? arr : obj;
    final end = useArr ? t.lastIndexOf(']') : t.lastIndexOf('}');
    if (start < 0 || end <= start) {
      final peek = t.length > 60 ? '${t.substring(0, 60)}…' : t;
      throw 'respuesta sin datos: "$peek"';
    }
    try {
      final j = jsonDecode(t.substring(start, end + 1));
      List raw = const [];
      if (j is List) {
        raw = j;
      } else if (j is Map) {
        final v = j['conciertos'] ?? j['concerts'] ??
            j.values.firstWhere((e) => e is List, orElse: () => null);
        if (v is List) raw = v;
      }
      return _upcoming(<Concert>[
        for (final e in raw)
          if (Concert.fromJson(e) != null) Concert.fromJson(e)!,
      ]);
    } catch (_) {
      throw 'respuesta incompleta';
    }
  }
}

/// "hace 2 días", "justo ahora"…
String concertsUpdatedLabel(DateTime? at) {
  if (at == null) return 'Aún no se ha buscado';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 2) return 'Actualizado justo ahora';
  if (d.inHours < 1) return 'Actualizado hace ${d.inMinutes} min';
  if (d.inDays < 1) {
    return 'Actualizado hace ${d.inHours} ${d.inHours == 1 ? 'hora' : 'horas'}';
  }
  return 'Actualizado hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}
