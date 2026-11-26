import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'deezer_service.dart';
import 'library_service.dart';
import 'music_api_service.dart';

/// «¿Qué está sonando?» en la radio: el título que envía la emisora (ICY),
/// el registro «Sonó en…» (últimas 20 por emisora) y guardar la canción.
class RadioNow {
  RadioNow._();

  /// Texto actual de la emisora («Aterciopelados - Bolero Falaz»), o ''.
  static final ValueNotifier<String> now = ValueNotifier<String>('');

  /// Canción confirmada con Deezer (artista, título); null si lo que envía
  /// la emisora no es una canción reconocible.
  static final ValueNotifier<(String, String)?> song =
      ValueNotifier<(String, String)?>(null);
  static final Map<String, bool> _valid = {};

  static Future<bool> _check(String a, String t) async {
    final k = '$a|$t'.toLowerCase();
    final v = _valid[k];
    if (v != null) return v;
    final ok = await DeezerService().trackExists(a, t);
    _valid[k] = ok;
    return ok;
  }
  static const String _prefKey = 'radio_heard_v1';

  /// Separa «Artista - Título». Null si no parece una canción (anuncios,
  /// nombre de la emisora, «En vivo»…).
  static (String, String)? parse(String text, {String station = ''}) {
    final t = text.trim();

    final m = RegExp(r'^(.+?)\s+[-–—]\s+(.+)$').firstMatch(t);
    if (m == null) return null;
    final a = m.group(1)!.trim(), s = m.group(2)!.trim();
    if (a.length < 2 || s.length < 2) return null;
    final bad = RegExp(
        r'(publicidad|comercial|anuncio|en vivo|\bradio\b|\bfm\b|\bam\b|www\.|http|\.com)',
        caseSensitive: false);
    if (bad.hasMatch(a) || bad.hasMatch(s)) return null;
    // Una parte es el nombre de la emisora: no es una canción.
    if (station.isNotEmpty) {
      final st = station.toLowerCase();
      final words = st.split(RegExp(r'\s+')).where((w) => w.length >= 4);
      for (final part in [a.toLowerCase(), s.toLowerCase()]) {
        if (st.contains(part) || words.any(part.contains)) return null;
      }
    }
    return (a, s);
  }

  /// Llega un título nuevo de la emisora [station].
  static Future<void> heard(String station, String text) async {
    now.value = text;
    song.value = null;
    final p = parse(text, station: station);
    if (p == null) return;
    if (!await _check(p.$1, p.$2)) return;
    if (now.value != text) return; // ya cambió
    song.value = p;
    try {
      final sp = await SharedPreferences.getInstance();
      final m = (jsonDecode(sp.getString(_prefKey) ?? '{}') as Map)
          .cast<String, dynamic>();
      final l = ((m[station] as List?) ?? []).cast<dynamic>().toList();
      if (l.isNotEmpty && (l.first as Map)['t'] == text) return;
      l.insert(0, {'t': text, 'at': DateTime.now().millisecondsSinceEpoch});
      if (l.length > 20) l.removeRange(20, l.length);
      m[station] = l;
      await sp.setString(_prefKey, jsonEncode(m));
    } catch (_) {}
  }

  static void reset() {
    now.value = '';
    song.value = null;
  }

  /// Lo que sonó en [station], lo más reciente primero.
  static Future<List<(String, DateTime)>> history(String station) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final m = (jsonDecode(sp.getString(_prefKey) ?? '{}') as Map);
      return [
        for (final e in (m[station] as List?) ?? const [])
          ('${e['t']}', DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()))
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Busca la canción en YouTube y la guarda en favoritas. Devuelve la
  /// canción guardada o null si no se encontró.
  static Future<Song?> save(String text) async {
    final p = parse(text);
    if (p == null || !await _check(p.$1, p.$2)) return null;
    final list = await MusicApiService().search('${p.$1} ${p.$2}');
    if (list.isEmpty) return null;
    final s = list.first;
    if (!await LibraryService.instance.isFavorite(s.videoId)) {
      await LibraryService.instance.toggleFavorite(s);
    }
    return s;
  }
}
