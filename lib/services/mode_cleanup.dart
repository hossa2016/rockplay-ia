import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'artist_pools.dart';
import 'general_catalog.dart';

/// Arreglo de una sola vez: en la versión anterior, si cambiabas de modo con
/// música sonando, canciones de «Todos los géneros» quedaban en el historial
/// y las escuchas de rock. Aquí se devuelven a su modo.
class ModeCleanup {
  ModeCleanup._();

  static const _flag = 'fix_mode_mix_v1';
  // Desde que existe el modo Pulso (24 nov 2026, 11 p. m. hora Colombia).
  static const _since = 1795579200;

  static String _k(String a, String t) =>
      '${a.toLowerCase().trim()}|${t.toLowerCase().trim()}';

  static Future<void> run() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool(_flag) == true) return;
      await sp.setBool(_flag, true);

      final rockArtists = <String>{
        for (final l in kMixArtistPools.values)
          for (final a in l) a.toLowerCase()
      };
      final generalArtists = <String>{
        for (final l in GeneralCatalog.pools.values)
          for (final a in l) a.toLowerCase(),
        for (final d in GeneralCatalog.genre)
          for (final a in d.artists) a.toLowerCase(),
        for (final d in GeneralCatalog.mood)
          for (final a in d.artists) a.toLowerCase(),
      }..removeAll(rockArtists);

      // Lo que ya sonó en Pulso.
      final gSongs = <String>{};
      final gPlaysRaw = sp.getString('g_plays_v1');
      final gPlays = gPlaysRaw == null ? <dynamic>[] : jsonDecode(gPlaysRaw) as List;
      for (final e in gPlays) {
        final l = e as List;
        gSongs.add(_k(l[1] as String, l[2] as String));
      }
      for (final raw in sp.getStringList('g_history') ?? const <String>[]) {
        try {
          final j = jsonDecode(raw) as Map<String, dynamic>;
          gSongs.add(_k('${j['artist'] ?? ''}', '${j['title'] ?? ''}'));
        } catch (_) {}
      }

      bool isGeneral(String artist, String title) =>
          gSongs.contains(_k(artist, title)) ||
          generalArtists.contains(artist.toLowerCase().trim());

      // Escuchas de rock desde que existe Pulso.
      final playsRaw = sp.getString('plays_v1');
      if (playsRaw != null) {
        final keep = <dynamic>[];
        final move = <dynamic>[];
        for (final e in jsonDecode(playsRaw) as List) {
          final l = e as List;
          final recent = (l[0] as int) >= _since;
          (recent && isGeneral(l[1] as String, l[2] as String) ? move : keep)
              .add(l);
        }
        if (move.isNotEmpty) {
          await sp.setString('plays_v1', jsonEncode(keep));
          await sp.setString('g_plays_v1', jsonEncode([...gPlays, ...move]));
        }
      }

      // Historial de rock.
      final hist = sp.getStringList('history');
      if (hist != null) {
        final keep = <String>[];
        final seen = <String>{};
        for (final raw in hist) {
          try {
            final j = jsonDecode(raw) as Map<String, dynamic>;
            final a = '${j['artist'] ?? ''}', t = '${j['title'] ?? ''}';
            if (isGeneral(a, t)) continue;
            if (!seen.add(_k(a, t))) continue; // repetidas
            keep.add(raw);
          } catch (_) {
            keep.add(raw);
          }
        }
        await sp.setStringList('history', keep);
      }
    } catch (_) {}
  }
}
