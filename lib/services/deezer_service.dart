import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class RadioResult {
  final String artistName;
  final List<String> similar;
  final List<Song> tracks;

  RadioResult({
    required this.artistName,
    required this.similar,
    required this.tracks,
  });
}

/// Usa la API pública de Deezer (sin clave) para armar una emisora:
/// canciones del artista y de artistas similares.
class DeezerService {
  static const String _base = 'https://api.deezer.com';

  Future<Map<String, dynamic>> _get(String path, Map<String, String> q) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: q);
    final r = await http.get(uri).timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) {
      throw Exception('Deezer HTTP ${r.statusCode}');
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// URL de la vista previa (30 s, mp3) de la mejor coincidencia en Deezer.
  Future<String?> previewUrl(String query) async {
    final q = query
        .replaceAll(RegExp(r'[\[\(][^\]\)]*[\]\)]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return null;
    final j = await _get('/search', {'q': q, 'limit': '5'});
    final data = (j['data'] as List?) ?? <dynamic>[];
    for (final t in data) {
      if (t is Map) {
        final p = t['preview'];
        if (p is String && p.isNotEmpty) return p;
      }
    }
    return null;
  }

  /// Portada de la mejor coincidencia (vacía si no hay).
  Future<String> coverFor(String query) async {
    final q = query
        .replaceAll(RegExp(r'[\[\(][^\]\)]*[\]\)]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty) return '';
    final j = await _get('/search', {'q': q, 'limit': '3'});
    for (final t in (j['data'] as List?) ?? <dynamic>[]) {
      if (t is Map && t['album'] is Map) {
        final c = (t['album']['cover_medium'] ?? '') as String;
        if (c.isNotEmpty) return c;
      }
    }
    return '';
  }

  List<Song> _tracks(Map<String, dynamic> json) {
    final out = <Song>[];
    final data = (json['data'] as List?) ?? <dynamic>[];
    for (final t in data) {
      if (t is! Map<String, dynamic>) continue;
      final title = (t['title'] ?? '') as String;
      final artistMap = t['artist'];
      final artist = artistMap is Map ? (artistMap['name'] ?? '') as String : '';
      final albumMap = t['album'];
      final image =
          albumMap is Map ? (albumMap['cover_medium'] ?? '') as String : '';
      if (title.isEmpty) continue;
      out.add(Song(
        title: title,
        artist: artist,
        image: image,
        query: '$artist $title',
      ));
    }
    return out;
  }

  /// Solo nombre oficial + artistas parecidos (2 peticiones, rápido).
  Future<RadioResult?> similarOnly(String name) async {
    final found = await _get('/search/artist', {'q': name, 'limit': '1'});
    final list = (found['data'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return null;
    final artist = list.first as Map<String, dynamic>;
    final id = artist['id'].toString();
    final names = <String>[];
    final ids = <String>[];
    final self = (artist['name'] ?? name).toString().toLowerCase();
    try {
      final rel = await _get('/artist/$id/related', {'limit': '50'});
      for (final a in (rel['data'] as List?) ?? <dynamic>[]) {
        if (a is Map<String, dynamic> && a['name'] != null) {
          names.add(a['name'] as String);
          ids.add(a['id'].toString());
        }
      }
    } catch (_) {}
    // Parecidos de los parecidos: más variedad de artistas.
    final extra = await Future.wait([
      for (final rid in ids.take(16))
        () async {
          try {
            final r = await _get('/artist/$rid/related', {'limit': '30'});
            return [
              for (final a in (r['data'] as List?) ?? <dynamic>[])
                if (a is Map<String, dynamic> && a['name'] != null)
                  a['name'] as String,
            ];
          } catch (_) {
            return <String>[];
          }
        }(),
    ]);
    final seen = <String>{self, ...names.map((n) => n.toLowerCase())};
    for (final l in extra) {
      for (final n in l) {
        if (seen.add(n.toLowerCase())) names.add(n);
      }
    }
    return RadioResult(
      artistName: (artist['name'] ?? name) as String,
      similar: names,
      tracks: <Song>[],
    );
  }

  Future<RadioResult?> artistRadio(String name) async {
    final found = await _get('/search/artist', {'q': name, 'limit': '1'});
    final list = (found['data'] as List?) ?? <dynamic>[];
    if (list.isEmpty) return null;
    final artist = list.first as Map<String, dynamic>;
    final id = artist['id'].toString();
    final artistName = (artist['name'] ?? name) as String;

    Future<List<Song>> safeTracks(String path, String limit) async {
      try {
        return _tracks(await _get(path, {'limit': limit}));
      } catch (_) {
        return <Song>[];
      }
    }

    // Todo en paralelo: radio + top del artista + artistas parecidos.
    final similarNames = <String>[];
    final similarIds = <String>[];
    try {
      final rel = await _get('/artist/$id/related', {'limit': '50'});
      for (final a in (rel['data'] as List?) ?? <dynamic>[]) {
        if (a is Map<String, dynamic> && a['name'] != null) {
          similarNames.add(a['name'] as String);
          similarIds.add(a['id'].toString());
        }
      }
    } catch (_) {}

    final futures = <Future<List<Song>>>[
      safeTracks('/artist/$id/top', '50'),
      safeTracks('/artist/$id/radio', '100'),
      for (final sid in similarIds.take(25)) safeTracks('/artist/$sid/top', '25'),
    ];
    final lists = await Future.wait(futures);

    // Primero lo del artista; luego los parecidos. Sin duplicados.
    final seen = <String>{};
    final tracks = <Song>[];
    for (final l in lists) {
      for (final t in l) {
        final key = '${t.artist}|${t.title}'.toLowerCase();
        if (seen.add(key) && tracks.length < 500) tracks.add(t);
      }
    }

    return RadioResult(
      artistName: artistName,
      similar: similarNames,
      tracks: tracks,
    );
  }
}
