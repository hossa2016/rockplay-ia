import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter/scheduler.dart';

import 'package:url_launcher/url_launcher.dart';

import '../models/song.dart';
import '../services/embed_bridge.dart';
import '../services/track_info_service.dart';
import '../services/block_service.dart';
import '../widgets/add_to_playlist.dart';
import '../widgets/cover_art.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/favorite_button.dart';
import '../widgets/music_card.dart';
import '../widgets/lyrics_view.dart';
import 'artist_screen.dart';
import '../widgets/playback_ui.dart';

/// Pantalla de reproducción inmersiva. Lee todo de [PlaybackUi].
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  final PlaybackUi pb = PlaybackUi.instance;
  double? _drag;
  final GlobalKey _slotKey = GlobalKey();
  late final Ticker _ticker;
  late final AnimationController _spin;
  late final AnimationController _eq;
  final bool _showVideo = false;
  bool _disc = false;
  bool _lyrics = false;
  TrackInfo? _info;
  String _infoKey = '';

  void _ensureInfo(Song song) {
    if (song.isRadio) {
      _infoKey = '';
      _info = null;
      return;
    }
    final key = '${song.artist}|${song.title}';
    if (_infoKey == key) return;
    _infoKey = key;
    _info = null;
    TrackInfoService.instance.fetch(song.artist, song.title).then((i) {
      if (mounted && _infoKey == key) setState(() => _info = i);
    });
  }


  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _measure())..start();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 14));
    _eq = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    pb.playing.addListener(_syncAnim);
    _syncAnim();
  }

  void _sleepSheet() {
    final svc = PlaybackService.instance;
    Widget opt(BuildContext ctx, String label, VoidCallback go) => ListTile(
          title: Text(label),
          onTap: () {
            go();
            Navigator.of(ctx).pop();
          },
        );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Apagar la música en…',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
            opt(ctx, '15 minutos',
                () => svc.setSleep(const Duration(minutes: 15))),
            opt(ctx, '30 minutos',
                () => svc.setSleep(const Duration(minutes: 30))),
            opt(ctx, '45 minutos',
                () => svc.setSleep(const Duration(minutes: 45))),
            opt(ctx, '1 hora', () => svc.setSleep(const Duration(hours: 1))),
            opt(ctx, 'Al terminar la canción',
                () => svc.setSleep(null, endOfSong: true)),
            if (pb.sleepLabel.value != null)
              opt(ctx, 'Cancelar temporizador', () => svc.setSleep(null)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final s = pb.song.value;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('¿Bloquear este artista?'),
        content: Text(
            'No volverá a salir «${s.artist}» en búsquedas, DJ ni mixes. Lo desbloqueas desde Inicio.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bloquear',
                  style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) await _block();
  }

  Future<void> _block() async {
    final s = pb.song.value;
    if (s == null) return;
    final name = s.artist
        .replaceAll(
            RegExp(r'\s*(-\s*topic|vevo|oficial|official)\s*$',
                caseSensitive: false),
            '')
        .trim();
    if (name.isEmpty) return;
    await BlockService.instance.add(name);
    pb.bumpLibrary();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Listo: no volverá a salir «$name». Se desbloquea en Inicio.'),
      ));
    if (PlaybackService.instance.hasNext) PlaybackService.instance.next();
  }

  void _syncAnim() {
    if (pb.playing.value) {
      if (!_spin.isAnimating) _spin.repeat();
      if (!_eq.isAnimating) _eq.repeat();
    } else {
      _spin.stop();
      _eq.stop();
    }
  }

  void _measure() {
    if (!_showVideo) {
      if (EmbedBridge.instance.slot.value != null) {
        EmbedBridge.instance.slot.value = null;
      }
      return;
    }
    final ro = _slotKey.currentContext?.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      final r = ro.localToGlobal(Offset.zero) & ro.size;
      if (EmbedBridge.instance.slot.value != r) {
        EmbedBridge.instance.slot.value = r;
      }
    }
  }

  @override
  void dispose() {
    pb.playing.removeListener(_syncAnim);
    _spin.dispose();
    _eq.dispose();
    _ticker.dispose();
    EmbedBridge.instance.slot.value = null;
    if (EmbedBridge.instance.fullscreen.value) {
      EmbedBridge.instance.fullscreen.value = false;
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  static String _fmt(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
    return '$m:$ss';
  }

  Widget _background(Song? song) {
    final url = song?.image ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A1512), AppColors.bg],
            ),
          ),
        ),
        if (url.isNotEmpty)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Opacity(
              opacity: 0.55,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(10, 10, 13, 0.25),
                Color.fromRGBO(10, 10, 13, 0.75),
                AppColors.bg,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<Song?>(
              valueListenable: pb.song,
              builder: (context, s, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: KeyedSubtree(
                    key: ValueKey<String>(s?.image ?? ''),
                    child: _background(s),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: ValueListenableBuilder<Song?>(
              valueListenable: pb.song,
              builder: (context, s, _) {
                if (s == null) return _empty(context);
                return _content(context, s);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      children: [
        _topBar(context),
        const Expanded(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No hay nada en reproducción.\nElige una canción para empezar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDim, height: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            iconSize: 32,
            tooltip: 'Cerrar',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'REPRODUCIENDO',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ),
          if (!(pb.song.value?.isRadio ?? false))
          IconButton(
            iconSize: 24,
            tooltip: _lyrics ? 'Ocultar letra' : 'Ver letra',
            icon: Icon(_lyrics
                ? Icons.lyrics_rounded
                : Icons.lyrics_outlined),
            onPressed: () => setState(() => _lyrics = !_lyrics),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surfaceHigh,
            onSelected: (v) {
              if (v == 'list') {
                final s = pb.song.value;
                if (s != null) showAddToPlaylist(context, s);
              } else if (v == 'artist') {
                final s = pb.song.value;
                if (s != null) {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ArtistScreen(
                          name: _info?.artist ?? s.artist)));
                }
              } else if (v == 'sleep') {
                _sleepSheet();
              } else if (v == 'view') {
                setState(() => _disc = !_disc);
              } else if (v == 'block') {
                _confirmBlock();
              }
            },
            itemBuilder: (_) => _menuFor([
              const PopupMenuItem(
                value: 'list',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.playlist_add_rounded),
                  title: Text('Guardar en una lista'),
                ),
              ),
              PopupMenuItem(
                value: 'view',
                child: ListTile(
                  dense: true,
                  leading: Icon(_disc ? Icons.image_rounded : Icons.album_rounded),
                  title: Text(_disc ? 'Ver portada' : 'Ver disco'),
                ),
              ),
              const PopupMenuItem(
                value: 'artist',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_outline_rounded),
                  title: Text('Ver artista y discos'),
                ),
              ),
              PopupMenuItem(
                value: 'sleep',
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(pb.sleepLabel.value == null
                      ? 'Temporizador para dormir'
                      : 'Temporizador: ${pb.sleepLabel.value}'),
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.block_rounded, color: AppColors.red),
                  title: Text('No me interesa este artista',
                      style: TextStyle(color: AppColors.red)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// En radio solo tiene sentido el temporizador para dormir.
  List<PopupMenuItem<String>> _menuFor(List<PopupMenuItem<String>> all) {
    if (pb.song.value?.isRadio ?? false) {
      return all.where((e) => e.value == 'sleep').toList();
    }
    return all;
  }

  Widget _liveBar() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: AppColors.red),
          SizedBox(width: 8),
          Text('EN VIVO',
              style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, Song song) {
    _ensureInfo(song);
    final info = _info;
    return Column(
      children: [
        _topBar(context),
        Expanded(
          child: (_lyrics && !song.isRadio)
              ? LyricsView(song: song)
              : _visual(song),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info?.title ?? song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                info?.artist ?? song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (info != null && info.meta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  info.meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textFaint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        _errorBanner(),
        const SizedBox(height: 8),
        song.isRadio ? _liveBar() : _progress(),
        const SizedBox(height: 4),
        _controls(context, song),
        if (!song.isRadio) _extraControls(context, song),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Fila de acciones a la vista: aleatorio, repetir, guardar en lista y
  /// temporizador (antes escondidas en la cola o en el menú ⋮).
  Widget _extraControls(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: ListenableBuilder(
        listenable: Listenable.merge([pb.repeat, pb.sleepLabel]),
        builder: (context, _) {
          final rep = pb.repeat.value;
          final sleeping = pb.sleepLabel.value != null;
          Widget btn(IconData icon, String label, VoidCallback onTap,
              {bool on = false}) {
            final c = on ? AppColors.amber : AppColors.textDim;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: SizedBox(
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 24, color: c),
                      const SizedBox(height: 2),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: c)),
                    ],
                  ),
                ),
              ),
            );
          }

          return Row(
            children: [
              btn(Icons.shuffle_rounded, 'Mezclar',
                  () => PlaybackService.instance.queueShuffle()),
              btn(
                  rep == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  rep == 0
                      ? 'Repetir'
                      : rep == 1
                          ? 'Repetir lista'
                          : 'Repetir una',
                  () => PlaybackService.instance.setRepeat((rep + 1) % 3),
                  on: rep != 0),
              btn(Icons.playlist_add_rounded, 'Guardar',
                  () => showAddToPlaylist(context, song)),
              btn(Icons.bedtime_outlined,
                  sleeping ? (pb.sleepLabel.value ?? 'Dormir') : 'Dormir',
                  _sleepSheet,
                  on: sleeping),
            ],
          );
        },
      ),
    );
  }

  Widget _cover(Song song) {
    return LayoutBuilder(builder: (context, box) {
      final art = song.isRadio ? song.image : (_info?.artwork ?? '');
      final square = art.isNotEmpty;
      final w = square
          ? math.min(box.maxWidth - 56, box.maxHeight - 90)
          : math.min(box.maxWidth - 40, (box.maxHeight - 90) * 16 / 9);
      final h = square ? w : w * 9 / 16;
      final fallback = song.image;
      final thumb = square
          ? art
          : (song.videoId.isEmpty
              ? fallback
              : 'https://i.ytimg.com/vi/${song.videoId}/hqdefault.jpg');
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color.fromRGBO(229, 51, 46, 0.35), blurRadius: 40),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, child) {
                  final t = math.sin(_spin.value * 2 * math.pi);
                  return Transform.scale(
                      scale: (square ? 1.0 : 1.12) + 0.04 * t,
                      child: child);
                },
                child: thumb.isEmpty
                    ? const ColoredBox(color: Color(0xFF0B0B0E))
                    : Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => fallback.isEmpty
                            ? const ColoredBox(color: Color(0xFF0B0B0E))
                            : Image.network(fallback, fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            width: math.min(box.maxWidth - 64, 320),
            child: AnimatedBuilder(
              animation: _eq,
              builder: (context, _) => CustomPaint(
                painter: _EqPainter(_eq.value),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _visual(Song song) {
    if (!_disc) return _cover(song);
    return LayoutBuilder(builder: (context, box) {
      final disc = math.max(
          120.0, math.min(box.maxWidth - 64, box.maxHeight - 90));
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: SizedBox(
              width: disc,
              height: disc,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0B0E),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(229, 51, 46, 0.35),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: Size.square(disc),
                    painter: _GroovesPainter(),
                  ),
                  CoverArt(
                    url: (_info?.artwork.isNotEmpty ?? false)
                        ? _info!.artwork
                        : song.image,
                    size: disc * 0.46,
                    radius: disc * 0.23,
                    shadow: false,
                  ),
                  Container(
                    width: disc * 0.05,
                    height: disc * 0.05,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            width: math.min(box.maxWidth - 64, 320),
            child: AnimatedBuilder(
              animation: _eq,
              builder: (context, _) => CustomPaint(
                painter: _EqPainter(_eq.value),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _errorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: pb.error,
      builder: (context, err, _) {
        if (err == null || err.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 176, 46, 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromRGBO(255, 176, 46, 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    err,
                    style: const TextStyle(
                      color: AppColors.amber,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: _showSkipped, child: const Text('Ver cuáles')),
              if (pb.song.value != null &&
                  pb.song.value!.videoId.isNotEmpty &&
                  !pb.song.value!.isRadio)
                TextButton(
                  onPressed: () => launchUrl(
                      Uri.parse(
                          'https://www.youtube.com/watch?v=${pb.song.value!.videoId}'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Abrir en YouTube'),
                ),
            ]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSkipped() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Canciones saltadas'),
        content: SizedBox(
          width: double.maxFinite,
          child: SkipLog.entries.isEmpty
              ? const Text('Todavía no se ha saltado ninguna.')
              : ListView(shrinkWrap: true, children: [
                  for (final e in SkipLog.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(e, style: const TextStyle(fontSize: 12.5)),
                    ),
                ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _progress() {
    return ListenableBuilder(
      listenable: Listenable.merge([pb.position, pb.duration]),
      builder: (context, _) {
        final total = (pb.duration.value ?? Duration.zero).inMilliseconds;
        final totalD = total > 0 ? total.toDouble() : 1.0;
        final posMs = pb.position.value.inMilliseconds.toDouble();
        final value = (_drag ?? posMs).clamp(0.0, totalD).toDouble();
        final shown = Duration(milliseconds: value.round());
        final remaining =
            Duration(milliseconds: total > 0 ? total - value.round() : 0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Slider(
                value: total > 0 ? value : 0.0,
                min: 0.0,
                max: totalD,
                onChanged: total > 0
                    ? (v) => setState(() => _drag = v)
                    : null,
                onChangeEnd: (v) {
                  PlaybackService.instance
                      .seek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(shown), style: _timeStyle),
                    Text(total > 0 ? '-${_fmt(remaining)}' : '--:--',
                        style: _timeStyle),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const TextStyle _timeStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textDim,
    fontWeight: FontWeight.w500,
    fontFeatures: [ui.FontFeature.tabularFigures()],
  );

  Widget _controls(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListenableBuilder(
        listenable: Listenable.merge([pb.playing, pb.loading, pb.index, pb.queue]),
        builder: (context, _) {
          final svc = PlaybackService.instance;
          final loading = pb.loading.value;
          final playing = pb.playing.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                iconSize: 28,
                tooltip: 'Cola de reproducción',
                color: Colors.white,
                icon: const Icon(Icons.queue_music_rounded),
                onPressed: () => _showQueue(context),
              ),
              IconButton(
                iconSize: 44,
                color: Colors.white,
                disabledColor: AppColors.textFaint,
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: svc.hasPrevious ? () => svc.previous() : null,
              ),
              _playButton(svc, loading, playing),
              IconButton(
                iconSize: 44,
                color: Colors.white,
                disabledColor: AppColors.textFaint,
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: svc.hasNext ? () => svc.next() : null,
              ),
              song.isRadio
                  ? const SizedBox(width: 48)
                  : FavoriteButton(song: song),
            ],
          );
        },
      ),
    );
  }

  Widget _playButton(PlaybackService svc, bool loading, bool playing) {
    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accent,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(229, 51, 46, 0.45),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => playing ? svc.pause() : svc.play(),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: loading
                  ? const SizedBox(
                      key: ValueKey<String>('load'),
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      key: ValueKey<bool>(playing),
                      size: 44,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scroll) {
            return ListenableBuilder(
              listenable: Listenable.merge([pb.queue, pb.index, pb.repeat]),
              builder: (context, _) {
                final q = pb.queue.value;
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'A continuación',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Barajar lo que sigue',
                            icon: const Icon(Icons.shuffle_rounded),
                            onPressed: () =>
                                PlaybackService.instance.queueShuffle(),
                          ),
                          IconButton(
                            tooltip: pb.repeat.value == 0
                                ? 'Repetir: no'
                                : pb.repeat.value == 1
                                    ? 'Repetir la lista'
                                    : 'Repetir esta canción',
                            color: pb.repeat.value == 0
                                ? AppColors.textDim
                                : AppColors.amber,
                            icon: Icon(pb.repeat.value == 2
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded),
                            onPressed: () => PlaybackService.instance
                                .setRepeat((pb.repeat.value + 1) % 3),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mantén pulsada una fila para moverla · desliza para quitarla',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textFaint),
                        ),
                      ),
                    ),
                    Expanded(
                      child: q.isEmpty
                          ? const Center(
                              child: Text(
                                'La cola está vacía',
                                style: TextStyle(color: AppColors.textDim),
                              ),
                            )
                          : ReorderableListView.builder(
                              scrollController: scroll,
                              itemCount: q.length,
                              onReorder: (a, b) =>
                                  PlaybackService.instance.queueMove(a, b),
                              itemBuilder: (context, i) {
                                final card = MusicCard(
                                  song: q[i],
                                  actions: false,
                                  onTap: () {
                                    PlaybackService.instance
                                        .playQueue(List<Song>.of(q), i);
                                    Navigator.of(sheetContext).pop();
                                  },
                                );
                                final k = ValueKey<String>(
                                    '$i|${q[i].videoId}|${q[i].title}');
                                if (i == (pb.index.value ?? -1)) {
                                  return KeyedSubtree(key: k, child: card);
                                }
                                return Dismissible(
                                  key: k,
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) =>
                                      PlaybackService.instance.queueRemove(i),
                                  background: Container(
                                    color: const Color(0x55E5332E),
                                    alignment: Alignment.centerRight,
                                    padding:
                                        const EdgeInsets.only(right: 24),
                                    child: const Icon(
                                        Icons.delete_outline_rounded),
                                  ),
                                  child: card,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}


class _GroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color.fromRGBO(255, 255, 255, 0.07);
    for (var f = 0.52; f < 0.98; f += 0.045) {
      canvas.drawCircle(c, r * f, p);
    }
    final shine = Paint()
      ..shader = SweepGradient(colors: const [
        Color.fromRGBO(255, 255, 255, 0.0),
        Color.fromRGBO(255, 255, 255, 0.10),
        Color.fromRGBO(255, 255, 255, 0.0),
        Color.fromRGBO(255, 255, 255, 0.10),
        Color.fromRGBO(255, 255, 255, 0.0),
      ]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.98, shine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _EqPainter extends CustomPainter {
  _EqPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 24;
    final gap = 4.0;
    final bw = (size.width - gap * (n - 1)) / n;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFFE5332E), Color(0xFFFFB02E)],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final a = math.sin(2 * math.pi * (t * (1 + (i % 3)) + i * 0.17));
      final b = math.sin(2 * math.pi * (t * 2 + i * 0.41));
      final h = size.height * (0.18 + 0.82 * ((a + b + 2) / 4));
      final x = i * (bw + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, bw, h),
          Radius.circular(bw / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) => old.t != t;
}
