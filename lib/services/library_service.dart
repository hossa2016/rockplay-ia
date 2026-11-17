import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

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

  Future<void> addToHistory(Song song) async {
    final h = await history();
    h.removeWhere((s) => s.videoId == song.videoId);
    h.insert(0, song);
    await _save(_histKey, h.take(50).toList());
  }
}
