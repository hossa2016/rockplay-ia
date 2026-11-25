import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'music_mode.dart';

class RadioStation {
  final String id;
  final String name;
  final String url;
  final String favicon;
  final String country;
  final String tags;
  final int bitrate;

  const RadioStation({
    required this.id,
    required this.name,
    required this.url,
    this.favicon = '',
    this.country = '',
    this.tags = '',
    this.bitrate = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'favicon': favicon,
        'country': country,
        'tags': tags,
        'bitrate': bitrate,
      };

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        favicon: (j['favicon'] ?? '') as String,
        country: (j['country'] ?? '') as String,
        tags: (j['tags'] ?? '') as String,
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
      );

  /// Una línea tenue: país · primer género.
  String get subtitle {
    final parts = <String>[
      if (country.isNotEmpty) country,
      if (tags.isNotEmpty) tags.split(',').first.trim(),
    ];
    return parts.isEmpty ? 'Radio en vivo' : parts.join(' · ');
  }

  Song toSong() => Song(
        title: name,
        artist: 'Radio en vivo',
        image: favicon,
        url: url,
        query: 'radio:$id',
      );
}

/// Emisoras guardadas (en el teléfono) y búsqueda en el directorio gratuito
/// Radio Browser.
class RadioService {
  RadioService._();
  static final RadioService instance = RadioService._();

  static const String _key = 'radio_v1';
  static const List<String> _hosts = [
    'https://de1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://all.api.radio-browser.info',
  ];

  /// Sube cada vez que cambian las emisoras guardadas.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  List<RadioStation>? _saved;

  Future<List<RadioStation>> saved() async {
    if (_saved != null) return List<RadioStation>.of(_saved!);
    final out = <RadioStation>[];
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List) {
          if (e is Map<String, dynamic>) out.add(RadioStation.fromJson(e));
        }
      }
    } catch (_) {}
    _saved = out;
    return List<RadioStation>.of(out);
  }

  Future<void> _persist() async {
    revision.value++;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
          _key, jsonEncode([for (final s in _saved!) s.toJson()]));
    } catch (_) {}
  }

  Future<bool> isSaved(String id) async =>
      (await saved()).any((s) => s.id == id);

  Future<void> save(RadioStation s) async {
    await saved();
    if (_saved!.any((x) => x.id == s.id)) return;
    _saved!.insert(0, s);
    await _persist();
  }

  Future<void> remove(String id) async {
    await saved();
    _saved!.removeWhere((s) => s.id == id);
    await _persist();
  }

  /// Emisora creada con un enlace pegado a mano.
  RadioStation custom(String name, String url) => RadioStation(
        id: 'c${url.hashCode.abs()}',
        name: name.trim(),
        url: url.trim(),
      );

  Future<dynamic> _get(String path) async {
    Object? last;
    for (final h in _hosts) {
      try {
        final r = await http.get(Uri.parse('$h$path'), headers: const {
          'User-Agent': 'RockPlayIA/1.0 (uso personal)'
        }).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200) return jsonDecode(utf8.decode(r.bodyBytes));
        last = 'HTTP ${r.statusCode}';
      } catch (e) {
        last = e;
      }
    }
    throw Exception('Radio Browser no responde: $last');
  }

  List<RadioStation> _parse(dynamic j) {
    final out = <RadioStation>[];
    final seen = <String>{};
    for (final e in (j as List? ?? const [])) {
      if (e is! Map) continue;
      final url = ((e['url_resolved'] ?? '') as String).trim().isNotEmpty
          ? (e['url_resolved'] as String).trim()
          : ((e['url'] ?? '') as String).trim();
      final name = ((e['name'] ?? '') as String).trim();
      if (url.isEmpty || name.isEmpty) continue;
      final id = ((e['stationuuid'] ?? '') as String).isNotEmpty
          ? e['stationuuid'] as String
          : 'u${url.hashCode.abs()}';
      if (!seen.add(id)) continue;
      out.add(RadioStation(
        id: id,
        name: name,
        url: url,
        favicon: ((e['favicon'] ?? '') as String).trim(),
        country: ((e['country'] ?? '') as String).trim(),
        tags: ((e['tags'] ?? '') as String).trim(),
        bitrate: (e['bitrate'] as num?)?.toInt() ?? 0,
      ));
    }
    return out;
  }

  /// [query] vacío con [colombiaOnly] = populares de Colombia.
  Future<List<RadioStation>> search(String query,
      {bool colombiaOnly = true}) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final params = StringBuffer('limit=40&hidebroken=true&order=votes&reverse=true');
    if (q.isNotEmpty) params.write('&name=$q');
    if (colombiaOnly) params.write('&countrycode=CO');
    if (q.isEmpty && !colombiaOnly && MusicModeService.rock) {
      params.write('&tag=rock');
    }
    final j = await _get('/json/stations/search?$params');
    return _parse(j);
  }
}
