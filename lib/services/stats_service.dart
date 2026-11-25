import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'music_mode.dart';
import 'deezer_service.dart';

class PlayEntry {
  final int ts; // segundos desde epoch
  final String artist;
  final String title;
  final String videoId;
  final String image;
  const PlayEntry(this.ts, this.artist, this.title, this.videoId, this.image);
}

class CountItem {
  final String name;
  final int count;
  final PlayEntry? sample; // para reproducir una canción
  const CountItem(this.name, this.count, [this.sample]);
}

/// Registro local de lo que escuchas (solo en este teléfono).
class StatsService {
  StatsService._();
  static final StatsService instance = StatsService._();

  // Las escuchas de cada modo van aparte (Tus números, mixes, asistente).
  static String get _key => modeKey('plays_v1');
  MusicMode? _cacheMode;
  static const int _cap = 3000;
  List<PlayEntry>? _cache;

  static String cleanArtist(String a) => SongMeta.cleanChannel(a);

  Future<List<PlayEntry>> _load() async {
    if (_cache != null && _cacheMode == MusicModeService.mode.value) {
      return _cache!;
    }
    _cacheMode = MusicModeService.mode.value;
    final out = <PlayEntry>[];
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List) {
          final l = e as List;
          out.add(PlayEntry(l[0] as int, l[1] as String, l[2] as String,
              l[3] as String, l[4] as String));
        }
      }
    } catch (_) {}
    return _cache = out;
  }

  Future<void> record(Song s) async {
    try {
      final list = await _load();
      var artist = cleanArtist(s.artist);
      // Canal que sube música ajena («Music Uploader», «… Vault»): se
      // confirma el artista real con Deezer para que Tus números y los
      // mixes no se llenen de canales.
      if (SongMeta.looksLikeUploader(artist)) {
        final real = await DeezerService().artistForTitle(s.title);
        if (real != null) artist = real;
      }
      list.add(PlayEntry(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        artist,
        s.title,
        s.videoId,
        s.image,
      ));
      if (list.length > _cap) list.removeRange(0, list.length - _cap);
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode([
          for (final p in list) [p.ts, p.artist, p.title, p.videoId, p.image]
        ]),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    _cache = <PlayEntry>[];
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
    } catch (_) {}
  }

  /// Solo cuentan las canciones que sonaron al menos 30 s (si la siguiente
  /// empezó antes, fue un salto o una versión que falló). Artista y título se
  /// limpian (canales de YouTube → artista real).
  static List<PlayEntry> _real(List<PlayEntry> all) {
    final out = <PlayEntry>[];
    for (var i = 0; i < all.length; i++) {
      final p = all[i];
      if (i + 1 < all.length && all[i + 1].ts - p.ts < 30) continue;
      final m = SongMeta.split(p.title, p.artist);
      out.add(PlayEntry(p.ts, m.artist, m.title, p.videoId, p.image));
    }
    return out;
  }

  /// [days] null = todo el tiempo.
  Future<List<PlayEntry>> plays({int? days}) async {
    final all = _real(await _load());
    if (days == null) return all;
    final from = DateTime.now()
            .subtract(Duration(days: days))
            .millisecondsSinceEpoch ~/
        1000;
    return [for (final p in all) if (p.ts >= from) p];
  }

  static List<CountItem> topArtists(List<PlayEntry> plays, {int n = 10}) {
    final m = <String, int>{};
    for (final p in plays) {
      if (p.artist.isEmpty) continue;
      m[p.artist] = (m[p.artist] ?? 0) + 1;
    }
    final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in l.take(n)) CountItem(e.key, e.value)];
  }

  static List<CountItem> topSongs(List<PlayEntry> plays, {int n = 10}) {
    final m = <String, int>{};
    final sample = <String, PlayEntry>{};
    for (final p in plays) {
      final k = '${p.artist}|${p.title}';
      m[k] = (m[k] ?? 0) + 1;
      sample[k] = p;
    }
    final l = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in l.take(n))
        CountItem('${sample[e.key]!.title} · ${sample[e.key]!.artist}', e.value,
            sample[e.key])
    ];
  }
}
