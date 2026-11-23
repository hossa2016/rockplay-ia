import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mix_service.dart';
import '../services/data_saver.dart';

import '../models/song.dart';
import '../services/music_api_service.dart';
import '../services/deezer_service.dart';
import '../theme/app_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class DjScreen extends StatefulWidget {
  const DjScreen({super.key});

  @override
  State<DjScreen> createState() => _DjScreenState();
}

class _DjScreenState extends State<DjScreen> {
  static const List<String> _defaults = [
    'Metallica',
    'Linkin Park',
    'Nirvana',
    'Queen',
    'AC/DC',
    'Foo Fighters',
    'Guns N\' Roses',
    'Soda Stereo',
  ];

  static const List<String> _suffixes = [
    'official audio',
    'lyrics',
    'official video',
    'audio',
  ];

  final TextEditingController _controller = TextEditingController();
  final DeezerService _deezer = DeezerService();
  RadioResult? _radio;
  bool _loading = false;
  String? _message;
  bool _isError = false;
  bool _filling = false;

  static const String _pinKey = 'dj_pinned_v1';
  List<String> _pinned = <String>[];
  List<String> _auto = <String>[];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _pinned = prefs.getStringList(_pinKey) ?? <String>[];
    } catch (_) {}
    var mine = <String>[];
    try {
      mine = await MixService.personalArtists();
    } catch (_) {}
    final pinnedLower = _pinned.map((e) => e.toLowerCase()).toSet();
    final pool = <String>[
      for (final n in (mine.toSet().toList()..shuffle()))
        if (!pinnedLower.contains(n.toLowerCase())) n,
    ];
    final auto = pool.take(8).toList();
    if (auto.length + _pinned.length < 8) {
      for (final d in (List<String>.of(_defaults)..shuffle())) {
        if (auto.length + _pinned.length >= 8) break;
        if (!pinnedLower.contains(d.toLowerCase()) &&
            !auto.any((a) => a.toLowerCase() == d.toLowerCase())) {
          auto.add(d);
        }
      }
    }
    if (mounted) setState(() => _auto = auto);
  }

  Future<void> _savePinned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pinKey, _pinned);
    } catch (_) {}
  }

  Future<void> _addPinned() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar artista'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre del artista'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Agregar')),
        ],
      ),
    );
    final n = (name ?? '').trim();
    if (n.isEmpty) return;
    if (!_pinned.any((e) => e.toLowerCase() == n.toLowerCase())) {
      _pinned.add(n);
      await _savePinned();
    }
    await _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _isError = false;
      _filling = false;
      _radio = null;
    });
    try {
      RadioResult? r;
      // 1) Artistas parecidos (Deezer, rápido). Si falla, solo el artista.
      var artistName = name;
      var similar = <String>[];
      try {
        final base = await _deezer
            .similarOnly(name)
            .timeout(const Duration(seconds: 10));
        if (base != null) {
          artistName = base.artistName;
          similar = base.similar;
        }
      } catch (_) {}

      // 2) Canciones directamente de YouTube (ya traen el video listo).
      // ~100 artistas, pocas canciones de cada uno (~500 en total).
      // Los 40 más parecidos siempre; el resto de la lista, al azar (hasta 99).
      final similarPicked = <String>[
        ...similar.take(40),
        ...(List<String>.of(similar.skip(40).toList())..shuffle()).take(59),
      ];
      final maxA = DataSaver.instance.mixArtists;
      if (similarPicked.length > maxA - 1) {
        similarPicked.removeRange(maxA - 1, similarPicked.length);
      }
      final queries = <String>[
        '$artistName ${_suffixes[DateTime.now().millisecond % _suffixes.length]}',
        for (final sn in similarPicked)
          '$sn ${_suffixes[DateTime.now().microsecond % _suffixes.length]}',
      ];
      final got = List<List<Song>>.filled(queries.length, <Song>[]);
      final api = MusicApiService();

      Future<void> job(int i) async {
        try {
          var last = <Song>[];
          await for (final l in api.searchStream(queries[i],
              max: i == 0 ? 90 : 15,
              maxPages: i == 0 ? 4 : 2,
              mustMention: i == 0 ? artistName : similarPicked[i - 1])) {
            last = l;
            got[i] = l.take(i == 0 ? 30 : 5).toList();
          }
          final pool = List<Song>.of(last)..shuffle();
          got[i] = pool.take(i == 0 ? 30 : 5).toList();
        } catch (_) {}
      }

      // Máximo 14 búsquedas a la vez.
      var nextJob = 0;
      Future<void> worker() async {
        while (true) {
          final i = nextJob++;
          if (i >= queries.length) return;
          await job(i);
        }
      }

      var finished = false;
      Future<void> runAll() async {
        try {
          await Future.wait([for (var w = 0; w < 16; w++) worker()])
              .timeout(const Duration(seconds: 75));
        } catch (_) {}
        finished = true;
      }

      runAll();

      // Muestra la lista en cuanto hay una buena base y sigue llenándola.
      final t0 = DateTime.now();
      var revealed = false;
      var lastUpdate = DateTime.now();
      while (!finished) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) {
          api.dispose();
          return;
        }
        final partial = _assemble(got);
        final secs = DateTime.now().difference(t0).inSeconds;
        if (!revealed && partial.length >= 60 && secs >= 5) {
          revealed = true;
          lastUpdate = DateTime.now();
          setState(() {
            _loading = false;
            _filling = true;
            _radio = RadioResult(
                artistName: artistName, similar: similar, tracks: partial);
          });
        } else if (revealed &&
            DateTime.now().difference(lastUpdate).inSeconds >= 4) {
          lastUpdate = DateTime.now();
          setState(() {
            _radio = RadioResult(
                artistName: artistName, similar: similar, tracks: partial);
          });
        }
      }
      api.dispose();
      final tracks = _assemble(got);
      if (tracks.isNotEmpty) {
        r = RadioResult(
            artistName: artistName, similar: similar, tracks: tracks);
      } else {
        // 3) Respaldo: lista de Deezer (sin video; se busca al reproducir).
        r = await _deezer
            .artistRadio(name)
            .timeout(const Duration(seconds: 25));
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _filling = false;
        if (r == null || r.tracks.isEmpty) {
          _message = 'No encontré ese artista. Prueba con otro nombre.';
        } else {
          _radio = r;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = true;
        _message = 'No se pudo crear la emisora. Revisa tu conexión.';
      });
    }
  }

  /// Primero el artista; luego los parecidos intercalados (1 de cada uno).
  List<Song> _assemble(List<List<Song>> got) {
    final seen = <String>{};
    final tracks = <Song>[];
    for (final t in got[0]) {
      if (seen.add(t.videoId)) tracks.add(t);
    }
    var k = 0;
    var any = true;
    while (any && tracks.length < DataSaver.instance.mixSongs) {
      any = false;
      for (var i = 1; i < got.length; i++) {
        if (k < got[i].length) {
          any = true;
          final t = got[i][k];
          if (seen.add(t.videoId)) tracks.add(t);
        }
      }
      k++;
    }
    return tracks;
  }

  void _useSuggestion(String name) {
    _controller.text = name;
    _create();
  }

  void _play(int index) {
    final r = _radio;
    if (r == null) return;
    playSongs(context, r.tracks, index);
  }

  void _shuffle() {
    final r = _radio;
    if (r == null) return;
    final list = List<Song>.of(r.tracks)..shuffle();
    playSongs(context, list, 0);
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.radio_rounded, color: AppColors.amber, size: 34),
              SizedBox(height: 14),
              Text(
                'Elige un artista',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Escribe un artista y armo una emisora con sus canciones y las de bandas parecidas.',
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.78),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text('Prueba con',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Otras sugerencias',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadSuggestions,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _pinned)
              InputChip(
                avatar: const Icon(Icons.push_pin_rounded,
                    size: 16, color: AppColors.amber),
                label: Text(s),
                onPressed: () => _useSuggestion(s),
                onDeleted: () async {
                  _pinned.remove(s);
                  await _savePinned();
                  await _loadSuggestions();
                },
              ),
            for (final s in _auto)
              ActionChip(label: Text(s), onPressed: () => _useSuggestion(s)),
            ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar'),
              onPressed: _addPinned,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Los fijados (con chincheta) los eliges tú. Los demás salen de lo que más escuchas.',
          style: TextStyle(color: AppColors.textDim, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _radioView(RadioResult r) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: r.tracks.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _radioHeader(r);
        final idx = i - 1;
        return FadeIn(
          order: idx,
          child: MusicCard(song: r.tracks[idx], onTap: () => _play(idx)),
        );
      },
    );
  }

  Widget _radioHeader(RadioResult r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EMISORA',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.artistName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (r.similar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Con artistas como ${r.similar.take(5).join(', ')}',
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.72),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _filling
                  ? '${r.tracks.length} canciones · cargando más…'
                  : '${r.tracks.length} canciones',
              style: const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.72),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _shuffle,
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatorio'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => _play(0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('En orden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const SkeletonList();
    final r = _radio;
    if (r != null) return _radioView(r);
    if (_message != null) {
      return StateMessage(
        icon: _isError ? Icons.cloud_off_rounded : Icons.person_search_rounded,
        title: _isError ? 'Algo salió mal' : 'Artista no encontrado',
        message: _message!,
        actionLabel: _isError ? 'Reintentar' : null,
        onAction: _isError ? _create : null,
        isError: _isError,
      );
    }
    return _intro();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(title: 'Emisora de artista'),
            AppSearchField(
              controller: _controller,
              hint: 'Artista, ej: Linkin Park',
              icon: Icons.radio_rounded,
              onSubmit: _create,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey<String>(
                      '$_loading-${_radio?.artistName}-$_message'),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
