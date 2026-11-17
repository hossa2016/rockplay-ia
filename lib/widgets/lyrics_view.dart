import 'package:flutter/material.dart';

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
              alignment: 0.4,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: Text('Buscando la letra…',
              style: TextStyle(color: AppColors.textDim)));
    }
    final l = _l;
    if (l == null || l.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No encontré la letra de esta canción.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim)),
        ),
      );
    }
    if (l.synced.isNotEmpty) {
      return SingleChildScrollView(
        controller: _sc,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
        child: Column(
          children: [
            for (var i = 0; i < l.synced.length; i++)
              Padding(
                key: _keys[i],
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: i == _cur ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: i == _cur ? Colors.white : Colors.white38,
                  ),
                  child: Text(l.synced[i].text.isEmpty ? '♪' : l.synced[i].text,
                      textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Text(
        l.plain,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 17, height: 1.6, color: Colors.white70),
      ),
    );
  }
}
