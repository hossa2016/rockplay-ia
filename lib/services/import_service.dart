import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

/// Importar listas: un enlace de lista pública de YouTube (solo los
/// datos, no se descarga audio) o texto/CSV con «Artista - Canción» por
/// línea (por ejemplo, exportado de Spotify con TuneMyMusic).
class ImportService {
  ImportService._();

  static String? _playlistId(String text) {
    final m = RegExp(r'[?&]list=([A-Za-z0-9_-]+)').firstMatch(text);
    return m?.group(1);
  }

  static bool isYoutube(String text) => _playlistId(text) != null;

  /// (nombre sugerido, canciones)
  static Future<(String, List<Song>)> parse(String text) async {
    final id = _playlistId(text);
    if (id != null) {
      final yt = YoutubeExplode();
      try {
        final pl = await yt.playlists.get(id);
        final out = <Song>[];
        await for (final v in yt.playlists.getVideos(id)) {
          out.add(Song.fromYoutube(
            title: v.title,
            channel: v.author,
            image: v.thumbnails.mediumResUrl,
            videoId: v.id.value,
          ));
          if (out.length >= 500) break;
        }
        return (pl.title, out);
      } finally {
        yt.close();
      }
    }
    final out = <Song>[];
    for (var line in text.split(RegExp(r'\r?\n'))) {
      line = line.trim();
      if (line.isEmpty) continue;
      String a = '', t = '';
      final dash = RegExp(r'^(.+?)\s+[-–—]\s+(.+)$').firstMatch(line);
      if (dash != null) {
        a = dash.group(1)!;
        t = dash.group(2)!;
      } else if (line.contains(',') || line.contains(';')) {
        // CSV: «Canción,Artista,…» (TuneMyMusic) o «Artista;Canción».
        final cols = line
            .split(RegExp(r'[;,]'))
            .map((e) => e.replaceAll('"', '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (cols.length < 2) continue;
        final h = cols[0].toLowerCase();
        if (h == 'track name' || h == 'title' || h == 'artist' || h == 'nombre') {
          continue; // encabezado
        }
        t = cols[0];
        a = cols[1];
      } else {
        continue;
      }
      a = a.replaceAll('"', '').trim();
      t = t.replaceAll('"', '').trim();
      if (a.isEmpty || t.isEmpty) continue;
      out.add(Song(title: t, artist: a, query: '$a $t'));
    }
    return ('Lista importada', out);
  }
}
