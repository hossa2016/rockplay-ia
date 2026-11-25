class Song {
  final String title;
  final String artist;
  final String album;
  final String image;
  final String url;
  final String videoId;
  final String query;

  Song({
    required this.title,
    required this.artist,
    this.videoId = '',
    this.album = '',
    this.image = '',
    this.url = '',
    this.query = '',
  });

  /// Emisora de radio en vivo (la dirección de la transmisión va en [url]).
  bool get isRadio => query.startsWith('radio:');

  Song withVideoId(String id) => Song(
        title: title,
        artist: artist,
        album: album,
        image: image,
        url: 'https://www.youtube.com/watch?v=$id',
        videoId: id,
        query: query,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'image': image,
        'url': url,
        'videoId': videoId,
        'query': query,
      };

  factory Song.fromJson(Map<String, dynamic> j) {
    final s = Song(
      title: (j['title'] ?? '') as String,
      artist: (j['artist'] ?? '') as String,
      album: (j['album'] ?? '') as String,
      image: (j['image'] ?? '') as String,
      url: (j['url'] ?? '') as String,
      videoId: (j['videoId'] ?? '') as String,
      query: (j['query'] ?? '') as String,
    );
    // Lo guardado antes venía con el nombre del canal: se limpia al leer.
    return s.query.isEmpty && s.videoId.isNotEmpty ? s.cleaned() : s;
  }

  /// Canción salida de YouTube: separa «Artista - Canción» del título, quita
  /// «(Official Video)», «[Lyrics]», etc. y limpia el nombre del canal.
  factory Song.fromYoutube({
    required String title,
    required String channel,
    required String videoId,
    String image = '',
  }) =>
      Song(
        title: title,
        artist: channel,
        image: image,
        url: 'https://www.youtube.com/watch?v=$videoId',
        videoId: videoId,
      ).cleaned();

  Song cleaned() {
    final m = SongMeta.split(title, artist);
    if (m.title == title && m.artist == artist) return this;
    return Song(
      title: m.title,
      artist: m.artist,
      album: album,
      image: image,
      url: url,
      videoId: videoId,
      query: query,
    );
  }
}

/// Limpieza de títulos y nombres de artista que vienen de YouTube.
class SongMeta {
  SongMeta._();

  static final RegExp _bracketJunk = RegExp(
      r'\s*[\(\[\{][^\)\]\}]*\b(official|oficial|video|vídeo|audio|lyrics?|letra|visuali[sz]er|hd|hq|4k|remaster(ed)?|videoclip|clip|mv|subtitulad[oa]|sub español|traducid[oa])\b[^\)\]\}]*[\)\]\}]',
      caseSensitive: false);
  static final RegExp _tailJunk = RegExp(
      r'\s*[-|–—]\s*(official\s+)?(music\s+)?(video|audio|lyrics?|lyric video|video oficial|audio oficial|hd|4k)\s*$',
      caseSensitive: false);
  static final RegExp _sep = RegExp(r'\s+[-–—|]\s+');

  /// «Rammstein Official», «PearlJamVEVO», «Korn - Topic» → nombre del artista.
  static final RegExp _uploader = RegExp(
      r'(uploader|vault|records\b|recordings|music\s*(channel|tv)?$|heartbeats|lyrics|letras|hits|classics|mix(es)?$|channel$|^\w+chef$|\btv$|archive|collection)',
      caseSensitive: false);

  /// ¿El «artista» parece un canal que sube música de otros?
  static bool looksLikeUploader(String a) => _uploader.hasMatch(a.trim());

  static const _noArtist = {
    'op', 'ed', 'hd', 'hq', 'amv', 'ost', 'lyrics', 'letra', 'audio', 'video',
    'official', 'oficial', 'live', 'en vivo', 'cover',
  };

  /// ¿Sirve como nombre de artista? Descarta «OP», «[FREE] … Type Beat»,
  /// «Kaelia Ash: "Self Destruction», canales que suben música ajena, etc.
  static bool isPlausibleArtist(String a) {
    final t = a.trim();
    if (t.length < 2 || t.length > 40) return false;
    final l = t.toLowerCase();
    if (_noArtist.contains(l)) return false;
    if (RegExp(r'["“”:\[\]]|type ?beat|\bprod\.? by\b|\bfree\b|\s[x×]\s')
        .hasMatch(l)) return false;
    if (RegExp(r'^\d+$').hasMatch(l)) return false;
    return !looksLikeUploader(t);
  }

  /// Lado derecho que no es un título: un año, un número o una etiqueta.
  static final RegExp _notTitle = RegExp(
      r'^((19|20)\d{2}|\d+|live|en vivo|directo|remaster(ed)?( \d{4})?|demo|version|versión|hd|hq|4k|lyrics?|letra)$',
      caseSensitive: false);

  static String cleanChannel(String a) => a
      .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*vevo$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*\(?official\)?\s*(channel)?$', caseSensitive: false), '')
      .replaceAll(RegExp(r'^official\s+', caseSensitive: false), '')
      .trim();

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñü]'), '');

  static ({String artist, String title}) split(String rawTitle, String rawArtist) {
    var t = rawTitle.replaceAll(_bracketJunk, '').replaceAll(_tailJunk, '');
    t = t
        .replaceAll(RegExp(r'\s+(hd|hq|4k)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.isEmpty) t = rawTitle.trim();
    final channel = cleanChannel(rawArtist);
    var artist = channel.isEmpty ? rawArtist.trim() : channel;
    // «Demon Slayer OP - "Gurenge" by LiSA» → Gurenge · LiSA.
    final by = RegExp(r'["“]([^"”]+)["”]\s+by\s+(.+)$', caseSensitive: false)
        .firstMatch(t);
    if (by != null) {
      final a = by.group(2)!.trim();
      if (a.isNotEmpty && a.length <= 40) {
        return (artist: a, title: by.group(1)!.trim());
      }
    }
    final m = _sep.firstMatch(t);
    if (m != null) {
      final left = t.substring(0, m.start).trim().replaceAll(RegExp(r'^["“]|["”]$'), '');
      final right = t.substring(m.end).trim().replaceAll(RegExp(r'^["“]|["”]$'), '');
      if (left.isNotEmpty && right.isNotEmpty && left.length <= 60) {
        final nc = _norm(channel), nl = _norm(left), nr = _norm(right);
        if (_notTitle.hasMatch(right)) {
          // «Killing In The Name - 1993»: la derecha no es un título; la
          // izquierda es la canción y el artista es el canal (si lo es).
          t = left;
          if (!looksLikeUploader(channel) && channel.isNotEmpty) artist = channel;
        } else if (nc.isNotEmpty && nr.contains(nc) && !nl.contains(nc)) {
          // «Canción - Artista»
          artist = right;
          t = left;
        } else {
          artist = left;
          t = right;
        }
      }
    } else if (channel.isNotEmpty) {
      // «Rammstein Du Hast» con canal Rammstein → «Du Hast».
      final lower = t.toLowerCase(), lc = channel.toLowerCase();
      if (lower.startsWith('$lc ') && t.length > channel.length + 2) {
        t = t.substring(channel.length).trim();
      }
    }
    return (artist: artist, title: t);
  }
}
