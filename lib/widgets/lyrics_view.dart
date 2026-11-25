import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/playback_service.dart';

import '../models/song.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';
import 'playback_ui.dart';

/// Letra de la canción: sincronizada (resalta la línea actual) si existe,
/// o texto simple desplazable.
class LyricsView extends StatefulWidget {
  final Song song;
  const LyricsView({super.key, required this.song});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final PlaybackUi pb = PlaybackUi.instance;
  Lyrics? _l;
  bool _loading = true;
  int _cur = -1;
  List<GlobalKey> _keys = [];
  final ScrollController _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    pb.position.addListener(_tick);
    _load();
  }

  @override
  void didUpdateWidget(covariant LyricsView old) {
    super.didUpdateWidget(old);
    if (old.song.title != widget.song.title ||
        old.song.artist != widget.song.artist) {
      _load();
    }
  }

  @override
  void dispose() {
    pb.position.removeListener(_tick);
    _sc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _l = null;
      _cur = -1;
    });
    final s = widget.song;
    final l = await LyricsService.instance.fetch(s.artist, s.title,
        seconds: pb.duration.value?.inSeconds);
    if (!mounted ||
        s.title != widget.song.title ||
        s.artist != widget.song.artist) return;
    setState(() {
      _l = l;
      _loading = false;
      _keys = List.generate(l?.synced.length ?? 0, (_) => GlobalKey());
    });
  }

  void _tick() {
    final l = _l;
    if (l == null || l.synced.isEmpty) return;
    final p = pb.position.value;
    var idx = -1;
    for (var i = 0; i < l.synced.length; i++) {
      if (l.synced[i].at <= p) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _cur) {
      setState(() => _cur = idx);
      if (idx >= 0 && idx < _keys.length) {
        final ctx = _keys[idx].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.35,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut);
        }
      }
    }
  }

  /// Una línea: la actual grande y nítida; las lejanas más chicas y
  /// difuminadas. Tocar una línea salta a ese momento de la canción.
  Widget _line(Lyrics l, int i, bool reduced) {
    final d = _cur < 0 ? (i + 1) : (i - _cur).abs();
    final active = i == _cur;
    final blur = reduced || active ? 0.0 : (d.clamp(0, 4) * 0.6).toDouble();
    final opacity = active ? 1.0 : (d == 1 ? 0.55 : 0.32);
    final text = Text(
      l.synced[i].text.isEmpty ? '♪' : l.synced[i].text,
      textAlign: TextAlign.left,
      style: AppType.oswald(27, height: 1.2),
    );
    return Padding(
      key: _keys[i],
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          HapticFeedback.selectionClick();
          PlaybackService.instance.seek(l.synced[i].at);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: AnimatedScale(
            scale: active ? 1.0 : 0.94,
            alignment: Alignment.centerLeft,
            duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
              child: blur == 0
                  ? text
                  : ImageFiltered(
                      imageFilter:
                          ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: text,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
          child: Text('Buscando la letra…',
              style: TextStyle(color: AppColors.textDim)));
    }
    final l = _l;
    if (l == null || l.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No encontré la letra de esta canción.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim)),
        ),
      );
    }
    if (l.synced.isNotEmpty) {
      final reduced = AppMotion.reduced(context);
      return ShaderMask(
        // Desvanece arriba y abajo para que la letra «flote».
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.12, 0.85, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _sc,
          padding: const EdgeInsets.fromLTRB(28, 80, 28, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < l.synced.length; i++)
                _line(l, i, reduced),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Text(
        l.plain,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: AppType.titleSm, height: 1.6, color: Colors.white70),
      ),
    );
  }
}
