import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_service.dart';
import 'concert_service.dart';
import 'library_service.dart';
import 'music_mode.dart';
import 'stats_service.dart';

/// Radar: conciertos de TUS bandas (las más escuchadas en 90 días, tus
/// favoritas y las que sigues), con aviso cuando aparece uno nuevo.
class RadarService {
  RadarService._();
  static final RadarService instance = RadarService._();

  static String get _followKey => modeKey('followed_v1');
  static const String _seenKey = 'radar_seen_v1';

  static String fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áà]'), 'a')
      .replaceAll(RegExp('[éè]'), 'e')
      .replaceAll(RegExp('[íì]'), 'i')
      .replaceAll(RegExp('[óò]'), 'o')
      .replaceAll(RegExp('[úù]'), 'u')
      .replaceAll(RegExp(r'^the\s+'), '')
      .replaceAll(RegExp(r'[^a-z0-9ñ ]'), '')
      .trim();

  Future<List<String>> followed() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_followKey) ?? const [];
  }

  Future<bool> isFollowed(String artist) async =>
      (await followed()).any((a) => fold(a) == fold(artist));

  Future<bool> toggleFollow(String artist) async {
    final sp = await SharedPreferences.getInstance();
    final l = List<String>.of(sp.getStringList(_followKey) ?? const []);
    final i = l.indexWhere((a) => fold(a) == fold(artist));
    if (i >= 0) {
      l.removeAt(i);
    } else {
      l.insert(0, artist);
    }
    await sp.setStringList(_followKey, l);
    return i < 0;
  }

  /// Tus bandas: seguidas + 20 más escuchadas (90 días) + de tus favoritas.
  Future<List<String>> bands() async {
    final out = <String>[];
    final seen = <String>{};
    void add(String a) {
      final k = fold(a);
      if (k.length >= 2 && seen.add(k)) out.add(a);
    }

    for (final a in await followed()) {
      add(a);
    }
    try {
      final plays = await StatsService.instance.plays(days: 90);
      for (final a in StatsService.topArtists(plays, n: 20)) {
        add(StatsService.cleanArtist(a.name));
      }
    } catch (_) {}
    try {
      for (final s in (await LibraryService.instance.favorites()).take(60)) {
        add(StatsService.cleanArtist(s.artist));
      }
    } catch (_) {}
    return out;
  }

  /// La banda de [c] (o del cartel del festival) que es tuya, si hay.
  static String? matchBand(Concert c, List<String> bands) {
    final t = ' ${fold(c.band)} ';
    for (final b in bands) {
      final k = fold(b);
      if (k.length < 3) continue;
      if (t.contains(' $k ')) return b;
    }
    return null;
  }

  /// Conciertos próximos de tus bandas, ordenados por fecha.
  Future<List<(Concert, String)>> matches() async {
    final bs = await bands();
    final now = DateTime.now();
    final out = <(Concert, String)>[];
    for (final c in ConcertService.instance.state.value.items) {
      if (c.date != null && c.date!.isBefore(DateTime(now.year, now.month, now.day))) {
        continue;
      }
      final b = matchBand(c, bs);
      if (b != null) out.add((c, b));
    }
    out.sort((a, b) {
      final da = a.$1.date, db = b.$1.date;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return out;
  }

  /// Avisa de los conciertos nuevos de tus bandas (una vez cada uno).
  Future<void> notifyNew() async {
    try {
      final l = await matches();
      if (l.isEmpty) return;
      final sp = await SharedPreferences.getInstance();
      final seen = Set<String>.of(
          (jsonDecode(sp.getString(_seenKey) ?? '[]') as List).map((e) => '$e'));
      var n = 0;
      for (final (c, b) in l) {
        final id = '${fold(c.band)}|${c.date?.toIso8601String() ?? c.when}|${fold(c.city)}';
        if (!seen.add(id)) continue;
        if (n++ >= 3) continue; // máximo 3 avisos de golpe
        final when = c.date == null
            ? c.when
            : '${c.date!.day} de ${_months[c.date!.month - 1]}';
        await AlarmService.instance.notify(
          7000 + id.hashCode.abs() % 1000,
          '$b toca en ${c.city.isEmpty ? 'Colombia' : c.city}',
          '${when.isEmpty ? 'Fecha por confirmar' : when}${c.venue.isEmpty ? '' : ' · ${c.venue}'}',
        );
      }
      await sp.setString(_seenKey, jsonEncode(seen.toList()));
    } catch (_) {}
  }

  static const List<String> _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// Enlace para añadir el concierto a Google Calendar (abre la app).
  static Uri calendarUri(Concert c) {
    final d = c.date ?? DateTime.now();
    String ymd(DateTime x) =>
        '${x.year}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    final end = d.add(const Duration(days: 1));
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': 'Concierto: ${c.band}',
      'dates': '${ymd(d)}/${ymd(end)}',
      'location': [c.venue, c.city].where((e) => e.isNotEmpty).join(', '),
      'details': c.tickets.isNotEmpty ? 'Boletas: ${c.tickets}' : 'Desde RockPlay IA',
    });
  }
}
