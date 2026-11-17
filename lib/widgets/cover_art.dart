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

  const CoverArt({
    super.key,
    required this.url,
    this.size,
    this.radius = 10,
    this.shadow = false,
  });

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A1512), Color(0xFF17171E)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth.isFinite && box.maxHeight.isFinite
              ? (box.maxWidth < box.maxHeight ? box.maxWidth : box.maxHeight)
              : 48.0;
          return Center(
            child: Icon(
              Icons.music_note_rounded,
              size: side * 0.42,
              color: const Color.fromRGBO(255, 176, 46, 0.65),
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
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.55),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ]
            : null,
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
