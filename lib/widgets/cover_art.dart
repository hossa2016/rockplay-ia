import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/data_saver.dart';
import '../services/music_mode.dart';
import '../services/track_info_service.dart';
import '../theme/app_theme.dart';

/// Portada con esquinas redondeadas y placeholder elegante.
/// Debe recibir tamaño ([size]) o restricciones ajustadas del padre.
class CoverArt extends StatelessWidget {
  final String url;
  final double? size;
  final double radius;
  final bool shadow;

  /// Texto (artista o título) para dar identidad al placeholder.
  final String? seed;

  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.radius = 10,
    this.shadow = false,
    this.seed,
  });

  static List<List<Color>> get _tones =>
      MusicModeService.general ? _tonesPulso : _tonesRock;

  static const List<List<Color>> _tonesPulso = [
    [Color(0xFF3A2C8C), Color(0xFF15142A)],
    [Color(0xFF233E7A), Color(0xFF111628)],
    [Color(0xFF14505A), Color(0xFF0E1A20)],
    [Color(0xFF4A2A6E), Color(0xFF16122A)],
    [Color(0xFF2A2A3A), Color(0xFF111118)],
  ];

  static const List<List<Color>> _tonesRock = [
    [Color(0xFF6B1A16), Color(0xFF17171E)],
    [Color(0xFF7A2A22), Color(0xFF1A1114)],
    [Color(0xFF5A3A12), Color(0xFF17171E)],
    [Color(0xFF3A1A24), Color(0xFF14141A)],
    [Color(0xFF2A2A33), Color(0xFF111116)],
  ];

  Widget _placeholder() {
    final s = (seed ?? '').trim();
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final tone = _tones[h % _tones.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth.isFinite && box.maxHeight.isFinite
              ? (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight)
              : 48.0;
          if (s.isEmpty) {
            return Center(
              child: Icon(
                Icons.music_note_rounded,
                size: side * 0.42,
                color: MusicModeService.general
                    ? AppColors.text.withValues(alpha: 0.6)
                    : AppColors.amber.withValues(alpha: 0.65),
              ),
            );
          }
          return Center(
            child: Text(
              s.substring(0, 1).toUpperCase(),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: AppType.head,
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                fontSize: side * 0.5,
                height: 1.0,
                color: MusicModeService.general
                    ? AppColors.text.withValues(alpha: 0.6)
                    : AppColors.amber.withValues(alpha: 0.7),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = url.isEmpty
        ? _placeholder()
        : _CoverImage(url: url, placeholder: _placeholder());

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: AppColors.surfaceHigh,
        boxShadow: shadow ? AppShadow.card : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }
}

/// Imagen con caché en disco (ver DataSaver).
class _CoverImage extends StatefulWidget {
  final String url;
  final Widget placeholder;
  const _CoverImage({required this.url, required this.placeholder});

  @override
  State<_CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<_CoverImage> {
  late Future<ImageProvider?> _f;

  @override
  void initState() {
    super.initState();
    _f = DataSaver.instance.image(widget.url);
  }

  @override
  void didUpdateWidget(covariant _CoverImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _f = DataSaver.instance.image(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: _f,
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) return widget.placeholder;
        return Image(
          image: p,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => widget.placeholder,
        );
      },
    );
  }
}


/// Carátula de una canción resuelta como en el reproductor: la de
/// TrackInfoService (Deezer/iTunes) si la canción no trae una buena
/// (vacía o un fotograma de YouTube); si no, la que trae.
class SongArtwork {
  SongArtwork._();
  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _pending = {};

  static bool _weak(String url) =>
      url.isEmpty || url.contains('ytimg.com') || url.contains('youtube.com');

  static String _key(Song s) => '${s.artist}|${s.title}'.toLowerCase();

  /// La mejor conocida ya, sin esperar.
  static String peek(Song s) => _cache[_key(s)] ?? s.image;

  static Future<String> of(Song s) {
    if (s.isRadio || !_weak(s.image)) return Future.value(s.image);
    final k = _key(s);
    final hit = _cache[k];
    if (hit != null) return Future.value(hit);
    return _pending[k] ??= TrackInfoService.instance
        .fetch(s.artist, s.title)
        .then((i) {
          final u = (i?.artwork ?? '').isNotEmpty ? i!.artwork : s.image;
          _cache[k] = u;
          return u;
        })
        .catchError((_) => s.image)
        .whenComplete(() => _pending.remove(k));
  }
}

/// [CoverArt] para una canción, con la carátula de [SongArtwork].
class SongCover extends StatelessWidget {
  const SongCover(this.song,
      {super.key, this.size, this.radius = 10, this.shadow = false});
  final Song song;
  final double? size;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        key: ValueKey('${song.artist}|${song.title}|${song.image}'),
        future: SongArtwork.of(song),
        initialData: SongArtwork.peek(song),
        builder: (context, snap) => CoverArt(
            url: snap.data ?? song.image,
            size: size,
            radius: radius,
            shadow: shadow,
            seed: song.artist),
      );
}
