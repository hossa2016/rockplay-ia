import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import 'deezer_service.dart';

class LibraryService {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  static const String _favKey = 'favorites';
  static const String _histKey = 'history';

  Future<List<Song>> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key) ?? <String>[];
    final out = <Song>[];
    for (final s in raw) {
      try {
        out.add(Song.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _save(String key, List<Song> songs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      key,
      songs.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  Future<List<Song>> favorites() => _load(_favKey);
  Future<List<Song>> history() => _load(_histKey);

  Future<bool> isFavorite(String videoId) async {
    final favs = await favorites();
    return favs.any((s) => s.videoId == videoId);
  }

  Future<bool> toggleFavorite(Song song) async {
    final favs = await favorites();
    final i = favs.indexWhere((s) => s.videoId == song.videoId);
    if (i >= 0) {
      favs.removeAt(i);
      await _save(_favKey, favs);
      return false;
    }
    favs.insert(0, song);
    await _save(_favKey, favs);
    return true;
  }

  /// Completa la portada con Deezer si la canción no la trae.
  Future<Song> _withCover(Song s) async {
    if (s.image.isNotEmpty) return s;
    try {
      final c = await DeezerService().coverFor('${s.artist} ${s.title}');
      if (c.isEmpty) return s;
      return Song(
        title: s.title,
        artist: s.artist,
        album: s.album,
        image: c,
        url: s.url,
        videoId: s.videoId,
        query: s.query,
      );
    } catch (_) {
      return s;
    }
  }

  Future<void> addToHistory(Song song) async {
    final h = await history();
    h.removeWhere((s) => s.videoId == song.videoId);
    h.insert(0, await _withCover(song));
    // Completa también algunas anteriores que quedaron sin portada.
    var fixed = 0;
    for (var i = 1; i < h.length && fixed < 6; i++) {
      if (h[i].image.isEmpty) {
        h[i] = await _withCover(h[i]);
        fixed++;
      }
    }
    await _save(_histKey, h.take(50).toList());
  }
}
