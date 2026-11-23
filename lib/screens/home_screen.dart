import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../services/artist_info_service.dart';
import '../services/block_service.dart';
import '../services/library_service.dart';
import '../services/mix_service.dart';
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
import 'search_screen.dart';
import '../widgets/concerts_card.dart';
import 'library_screen.dart';
import 'search_hub.dart';
import '../services/help_settings.dart';
import 'onboarding_screen.dart';
import 'settings_hub_screen.dart';

/// Contenedor principal: pestañas + mini-reproductor sobre la navegación.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    HelpSettings.load();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await HelpSettings.onboardingSeen();
      if (!seen && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const OnboardingScreen()));
      }
    });
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
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
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: NavigationBar(
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
            )),
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PlaybackUi.instance.libraryRevision.addListener(_load);
    StopLog.load();
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
    setState(() {
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
            _stopNotice(),
            _personalMix(),
            _quickAccess(),
            const SizedBox(height: 4),
            SectionTitle(
              'Seguir escuchando',
              actionLabel: _recent.isEmpty ? null : 'Ver historial',
              onAction: () {
                widget.onNavigate(2);
                libraryWantTab.value = 2;
              },
            ),
            _recentSection(),
            const SectionTitle('Conciertos'),
            ConcertsCard(onListen: _listenBand),
            const SectionTitle('Descubrir'),
            _discoverChips(),
            const SizedBox(height: 14),
            _discoverBody(),
          ],
        ),
      ),
    );
  }

  int _disc = 0;

  Widget _discoverChips() {
    const labels = ['Bandas', 'Lanzamientos', 'Mixes'];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = _disc == i;
          return Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
            onTap: () {
              if (!on) HapticFeedback.selectionClick();
              setState(() => _disc = i);
            },
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.redBtn : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
                border: on ? null : Border.all(color: AppColors.outline),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.textDim)),
            ),
          ));
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
                Text('ROCKPLAY', style: AppType.oswald(AppType.headline)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const SettingsHubScreen())),
          ),
        ],
      ),
    );
  }

  Widget _stopNotice() {
    return ValueListenableBuilder<String?>(
      valueListenable: StopLog.last,
      builder: (context, v, _) {
        if (v == null || !v.contains('|')) return const SizedBox.shrink();
        final i = v.indexOf('|');
        final hora = v.substring(0, i);
        final motivo = v.substring(i + 1);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 176, 46, 0.10),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color.fromRGBO(255, 176, 46, 0.35)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('La música se detuvo a las $hora',
                        style: const TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(motivo,
                        style: const TextStyle(fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: 'Cerrar aviso',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: StopLog.clear,
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _quickAccess() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _QuickTile(
        icon: Icons.sensors_rounded,
        label: 'Radio en vivo',
        subtitle: 'Radioacktiva, La Ochentera y más',
        onTap: () {
          widget.onNavigate(1);
          searchHubWantMode.value = 2;
        },
      ),
    );
  }

  /// «Escuchar banda» desde Conciertos: la busca en la pestaña Buscar.
  void _listenBand(String band) {
    widget.onNavigate(1);
    searchHubWantMode.value = 0;
    searchWantQuery.value = band;
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
            return const SkeletonRow();
          }
          final list = snap.data ?? const <ReleaseItem>[];
          if (list.isEmpty) {
            return Align(
              alignment: Alignment.topCenter,
              child: StateMessage(
                compact: true,
                icon: Icons.album_outlined,
                title: 'Sin lanzamientos recientes',
                message: 'No encontré discos nuevos de tus artistas.',
                actionLabel: 'Reintentar',
                onAction: () => setState(() => _releasesFuture = null),
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
                      CoverArt(
                          url: r.album.cover,
                          size: 140,
                          radius: 12,
                          seed: r.artist),
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
            return const SkeletonRow(
                itemWidth: 96, coverHeight: 88, circle: true);
          }
          final list = snap.data ?? const <ArtistInfo>[];
          if (list.isEmpty) {
            return Align(
              alignment: Alignment.topCenter,
              child: StateMessage(
                compact: true,
                icon: Icons.cloud_off_rounded,
                title: 'No pude cargar bandas',
                message: 'Revisa tu conexión.',
                actionLabel: 'Reintentar',
                isError: true,
                onAction: () => setState(() => _emergingFuture = null),
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
                              ? const ColoredBox(color: AppColors.surfaceWarm)
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
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.borderAccent),
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
                      child: CustomPaint(
                          painter: WavesPainter(AppColors.borderAccent)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TU MIX', style: AppType.overline),
                      const SizedBox(height: 6),
                      Text('SUENA COMO\nTÚ ERES',
                          style: AppType.oswald(AppType.display)),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 230),
                        child: const Text(
                            'Armado con tus favoritos y lo último que escuchaste.',
                            style: TextStyle(
                                fontSize: AppType.label,
                                height: 1.35,
                                color: Color(0xE6FFFFFF))),
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

  Widget _recentSection() {
    if (_loading) {
      return const SizedBox(height: 200, child: SkeletonRow());
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
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(
              children: [
                Icon(icon, color: AppColors.redText, size: 26),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: AppType.body,
                              fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: AppType.label,
                              color: AppColors.textDim)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textDim),
              ],
            ),
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
            CoverArt(
                url: song.image,
                size: 140,
                radius: 14,
                shadow: true,
                seed: song.artist),
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


