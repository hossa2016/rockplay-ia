import 'package:flutter/material.dart';

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
        : Image.network(
            url,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _placeholder();
            },
            errorBuilder: (context, error, stack) => _placeholder(),
          );

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
