import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_settings.dart';

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

  const Concert({
    required this.band,
    required this.city,
    required this.venue,
    required this.date,
    this.when = '',
    this.time = '',
    this.tickets = '',
    this.source = '',
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
      tickets: _url(s('boletas')),
      source: _url(s('fuente')),
    );
  }

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
    if (AiSettings.instance.geminiKey.trim().isEmpty) {
      state.value = ConcertState(
          items: prev.items, updatedAt: prev.updatedAt, noKey: true);
      return;
    }
    try {
      final list = await _search();
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
        '12 meses). Incluye rock, metal, hard rock, punk, grunge, rock '
        'alternativo, indie rock y rock en español; bandas internacionales y '
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
        'anunció"}]}';

    http.Response r;
    try {
      r = await http
          .post(
            Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/'
                '${s.geminiModel}:generateContent'),
            headers: {
              'x-goog-api-key': s.geminiKey.trim(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt}
                  ],
                }
              ],
              'tools': [
                {'google_search': {}}
              ],
              'generationConfig': {'temperature': 0.2},
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      throw 'Sin conexión o la búsqueda tardó demasiado.';
    }
    if (r.statusCode == 429) {
      throw 'Se alcanzó el límite gratuito de Gemini. Intenta más tarde.';
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw 'Gemini rechazó la clave. Revísala en Ajustes del asistente.';
    }
    if (r.statusCode != 200) throw 'Gemini respondió con error ${r.statusCode}.';

    String text = '';
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final parts = j['candidates'][0]['content']['parts'] as List;
      text = parts
          .map((p) => (p is Map ? p['text'] : null) ?? '')
          .join('\n');
    } catch (_) {
      throw 'Gemini no devolvió resultados.';
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) throw 'No se encontraron conciertos.';
    try {
      final j = jsonDecode(text.substring(start, end + 1));
      final raw = (j is Map ? j['conciertos'] : null) as List? ?? const [];
      final list = <Concert>[
        for (final e in raw)
          if (Concert.fromJson(e) != null) Concert.fromJson(e)!,
      ];
      return _upcoming(list);
    } catch (_) {
      throw 'La respuesta de Gemini llegó incompleta. Intenta de nuevo.';
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
