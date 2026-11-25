import 'package:flutter/material.dart';

import '../services/data_saver.dart';
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

  static const List<List<Color>> _tones = [
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
                color: AppColors.amber.withValues(alpha: 0.65),
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
                color: AppColors.amber.withValues(alpha: 0.7),
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
