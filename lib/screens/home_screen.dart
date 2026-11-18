import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/artist_info_service.dart';
import '../services/block_service.dart';
import '../services/library_service.dart';
import '../services/mix_service.dart';
import '../services/playlist_service.dart';
import '../widgets/add_to_playlist.dart';
import 'song_list_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_art.dart';
import '../widgets/mini_player.dart';
import '../widgets/playback_ui.dart';
import '../widgets/player_route.dart';
import '../widgets/rock_decor.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'artist_screen.dart';
import 'assistant_screen.dart';
import 'radio_screen.dart';
import '../services/radio_service.dart';
import 'dj_screen.dart';
import 'library_screen.dart';
import 'search_hub.dart';

/// Contenedor principal: pestañas + mini-reproductor sobre la navegación.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _go(int i) {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeTab(onNavigate: _go),
            const SearchHub(),
            const LibraryScreen(),
            const AssistantScreen(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0x66E5332E), width: 1),
                ),
              ),
              child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _go,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Mi música',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_awesome_outlined),
                  selectedIcon: Icon(Icons.auto_awesome_rounded),
                  label: 'Asistente',
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const _HomeTab({required this.onNavigate});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Song> _recent = [];
  List<Playlist> _lists = [];
  List<String> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PlaybackUi.instance.libraryRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    PlaybackUi.instance.libraryRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    List<Song> h = [];
    try {
      h = await LibraryService.instance.history();
    } catch (_) {}
    if (!mounted) return;
    List<Playlist> pl = [];
    try {
      pl = await PlaylistService.instance.all();
    } catch (_) {}
    if (!mounted) return;
    try {
      await BlockService.instance.ensureLoaded();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _blocked = BlockService.instance.names;
      _lists = pl;
      _recent = h.take(12).toList();
      _loading = false;
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 12) return 'Buenos días';
    if (h >= 12 && h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _header(context),
            _personalMix(),
            SectionTitle(
              'Seguir escuchando',
              actionLabel: _recent.isEmpty ? null : 'Ver todo',
              onAction: () => widget.onNavigate(2),
            ),
            _recentSection(),
            const SectionTitle('Descubrir'),
            _discoverChips(),
            const SizedBox(height: 14),
            _discoverBody(),
            if (_blocked.isNotEmpty) ...[
              const SectionTitle('Artistas bloqueados'),
              _blockedChips(),
            ],
          ],
        ),
      ),
    );
  }

  int _disc = 0;

  Widget _discoverChips() {
    const labels = ['Bandas', 'Lanzamientos', 'Radio', 'Mixes'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = _disc == i;
          return GestureDetector(
            onTap: () => setState(() => _disc = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.red : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: on ? null : Border.all(color: AppColors.outline),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.textDim)),
            ),
          );
        },
      ),
    );
  }

  Widget _discoverBody() {
    switch (_disc) {
      case 0:
        return _emergingRow();
      case 1:
        return _releasesRow();
      case 2:
        return Column(children: [
          _radioRow(),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const RadioScreen())),
                child: const Text('Ver todas las emisoras'),
              ),
            ),
          ),
        ]);
      default:
        return _mixRow(MixService.genre);
    }
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/icon/logo.png',
                width: 44, height: 44, filterQuality: FilterQuality.medium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 13),
                ),
                const Text('ROCKPLAY',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1.1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.search_rounded,
              label: 'Buscar',
              onTap: () => widget.onNavigate(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.radio_rounded,
              label: 'DJ',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DjScreen())),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickTile(
              icon: Icons.favorite_rounded,
              label: 'Mi música',
              onTap: () => widget.onNavigate(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _djBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x33FFB02E)),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DjScreen())),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 70,
                  child: CustomPaint(
                      painter: const WavesPainter(Color(0x22FFB02E))),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DJ ROCKPLAY',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TU MÚSICA.\nTU ESTILO.',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(height: 1.05, fontSize: 30),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Crea una emisora a partir de tu banda favorita.',
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.75),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('ENTRAR',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    fontSize: 13)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMix(String title, String subtitle, List<Color> colors,
      Stream<List<Song>> stream) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SongListScreen(
        title: title,
        subtitle: subtitle,
        colors: colors,
        stream: stream,
        emptyMessage:
            'No se pudo armar el mix. Revisa tu conexión e inténtalo de nuevo.',
      ),
    ));
  }

  Future<void> _newList() async {
    final name = await askPlaylistName(context);
    if (name == null || name.trim().isEmpty) return;
    await PlaylistService.instance.create(name);
    PlaybackUi.instance.bumpLibrary();
  }

  Widget _radioRow() {
    return ValueListenableBuilder<int>(
      valueListenable: RadioService.instance.revision,
      builder: (context, _, __) => FutureBuilder<List<RadioStation>>(
        future: RadioService.instance.saved(),
        builder: (context, snap) {
          final list = snap.data ?? const <RadioStation>[];
          void openAll() => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RadioScreen()));
          if (snap.connectionState == ConnectionState.done && list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: openAll,
                child: Container(
                  height: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.outline),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(children: [
                    Icon(Icons.radio_rounded, color: AppColors.amber, size: 32),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aún no tienes emisoras',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text('Agrega Radioacktiva, La Ochentera y más',
                              style: TextStyle(
                                  color: AppColors.textDim, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.textDim),
                  ]),
                ),
              ),
            );
          }
          return SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                if (i == list.length) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: openAll,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.outline),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: AppColors.amber),
                          SizedBox(height: 4),
                          Text('Agregar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                final s = list[i];
                return GestureDetector(
                  onTap: () => playStation(context, s),
                  child: SizedBox(
                    width: 104,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StationLogo(station: s, size: 104, radius: 14),
                        const SizedBox(height: 6),
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<List<ReleaseItem>>? _releasesFuture;

  Future<List<ReleaseItem>> _loadReleases() async {
    var names = <String>[];
    try {
      names = await MixService.personalArtists();
    } catch (_) {}
    names = (names.toSet().toList()..shuffle()).take(12).toList();
    return ArtistInfoService.instance.recentReleases(names);
  }

  Widget _releasesRow() {
    _releasesFuture ??= _loadReleases();
    return SizedBox(
      height: 214,
      child: FutureBuilder<List<ReleaseItem>>(
        future: _releasesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <ReleaseItem>[];
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No encontré lanzamientos recientes.',
                    style: TextStyle(color: AppColors.textDim)),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final r = list[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SongListScreen(
                      title: r.album.title,
                      subtitle: r.artist,
                      stream: ArtistInfoService.instance
                          .albumTracks(r.album, r.artist)
                          .asStream(),
                      emptyMessage: 'No pude cargar este disco.',
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverArt(url: r.album.cover, size: 140, radius: 12),
                      const SizedBox(height: 8),
                      Text(r.album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(r.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<ArtistInfo>>? _emergingFuture;

  Future<List<ArtistInfo>> _loadEmerging() async {
    var seeds = <String>[];
    try {
      seeds = await MixService.personalArtists();
    } catch (_) {}
    if (seeds.length < 3) {
      seeds = [
        ...seeds,
        'Nirvana',
        'Foo Fighters',
        'Soda Stereo',
        'Pearl Jam',
        'Green Day',
        'Metallica',
      ];
    }
    seeds = (seeds.toSet().toList()..shuffle()).take(6).toList();
    return ArtistInfoService.instance.emerging(seeds);
  }

  Widget _emergingRow() {
    _emergingFuture ??= _loadEmerging();
    return SizedBox(
      height: 150,
      child: FutureBuilder<List<ArtistInfo>>(
        future: _emergingFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <ArtistInfo>[];
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No pude cargar sugerencias ahora.',
                    style: TextStyle(color: AppColors.textDim)),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final a = list[i];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => ArtistScreen(name: a.name))),
                child: SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: a.picture.isEmpty
                              ? const ColoredBox(color: Color(0xFF1A1014))
                              : Image.network(a.picture, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(a.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _playMix() async {
    final artists = await MixService.personalArtists();
    if (!mounted) return;
    if (artists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Marca algunas canciones como favoritas o escucha música y armo tu mix.'),
      ));
      return;
    }
    _openMix(
      'Tu mix',
      'Con tus artistas favoritos',
      const [Color(0xFF7A1411), Color(0xFF14141A)],
      MixService.buildMix(artists, pick: 30, perArtist: 10),
    );
  }

  Widget _personalMix() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _playMix,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB3201B),
                  Color(0xFF5A0F0D),
                  Color(0xFF1A1014)
                ],
                stops: [0, 0.55, 1],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x38FFB02E)),
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.5,
                    child: SizedBox(
                      width: 260,
                      height: 90,
                      child: CustomPaint(painter: _WavePainter()),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TU MIX',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: AppColors.amber,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text('SUENA COMO\nTÚ ERES',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.05)),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 230),
                        child: const Text(
                            'Armado con tus favoritos y lo último que escuchaste.',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xBFFFFFFF))),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 22, color: AppColors.bg),
                            SizedBox(width: 6),
                            Text('Reproducir',
                                style: TextStyle(
                                    color: AppColors.bg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mixRow(List<MixDef> mixes) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: mixes.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final m = mixes[i];
          return _MixCard(
            def: m,
            onTap: () => _openMix(m.title, m.subtitle, m.colors,
                MixService.buildMix(MixService.pool(m),
                    pick: 70, perArtist: 4, keepOrder: true)),
          );
        },
      ),
    );
  }

  Widget _blockedChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.amber,
            title: const Text('Mostrar artistas bloqueados'),
            subtitle: const Text('Apagado: no salen en búsquedas, emisora ni mixes.',
                style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
            value: BlockService.instance.showBlocked,
            onChanged: (v) async {
              await BlockService.instance.setShowBlocked(v);
              if (mounted) setState(() {});
              PlaybackUi.instance.bumpLibrary();
            },
          ),
          Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final n in _blocked)
            InputChip(
              label: Text(n),
              onDeleted: () async {
                await BlockService.instance.remove(n);
                PlaybackUi.instance.bumpLibrary();
              },
            ),
        ],
      ),
        ],
      ),
    );
  }

  Widget _listsRow() {
    if (_lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Text(
            'Crea una lista con «Nueva» y guarda canciones desde el reproductor (icono de lista).',
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
        ),
      );
    }
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _lists.length,
        separatorBuilder: (context, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = _lists[i];
          return _MixCard(
            def: MixDef(p.name, '${p.songs.length} canciones',
                Icons.queue_music_rounded,
                const [Color(0xFF8A1A16), Color(0xFF1A1014)], const []),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SongListScreen(
                  title: p.name,
                  subtitle: 'Tu lista',
                  songs: p.songs,
                  emptyMessage:
                      'Lista vacía. Guarda canciones desde el reproductor.',
                  onRemove: (s) async {
                    await PlaylistService.instance
                        .removeSong(p.id, s.videoId);
                    PlaybackUi.instance.bumpLibrary();
                  },
                  onDeleteList: () async {
                    await PlaylistService.instance.delete(p.id);
                    PlaybackUi.instance.bumpLibrary();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ));
            },
          );
        },
      ),
    );
  }

  Widget _recentSection() {
    if (_loading) {
      return const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
      );
    }
    if (_recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Row(
            children: [
              Icon(Icons.headphones_rounded, color: AppColors.amber, size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Aún no has escuchado nada. Busca una canción y empieza el ruido.',
                  style: TextStyle(color: AppColors.textDim, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recent.length,
        separatorBuilder: (context, i) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = _recent[i];
          return FadeIn(
            order: i,
            child: _RecentCard(
              song: s,
              onTap: () => playSongs(context, _recent, i),
            ),
          );
        },
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.red, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _RecentCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(url: song.image, size: 140, radius: 14, shadow: true),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}


class _MixCard extends StatelessWidget {
  final MixDef def;
  final VoidCallback onTap;

  const _MixCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: def.colors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                      painter: const PickPatternPainter(Color(0x0FFFFFFF))),
                ),
                Positioned(
                  right: -14,
                  top: -10,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: Icon(def.icon,
                        size: 92, color: const Color(0x2EFFFFFF)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(
                        def.title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 19, height: 1.05, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        def.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color.fromRGBO(255, 255, 255, 0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _WavePainter extends CustomPainter {
  const _WavePainter();
  @override
  void paint(Canvas canvas, Size size) {
    void wave(double y, double amp, double alpha) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < 280; x += 40) {
        path.quadraticBezierTo(x + 20, y - amp, x + 40, y);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.amber.withValues(alpha: alpha));
    }

    wave(60, 80, 0.5);
    wave(72, 64, 0.3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
