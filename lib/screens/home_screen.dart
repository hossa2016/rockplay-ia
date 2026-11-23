import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:quick_actions/quick_actions.dart';

import '../services/concert_service.dart';
import '../services/stats_service.dart';
import 'concerts_screen.dart';

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
import '../widgets/pressable.dart';
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

  /// Atajos al mantener pulsado el ícono de la app.
  void _setupShortcuts() {
    try {
      const qa = QuickActions();
      qa.initialize((type) {
        if (!mounted) return;
        if (type == 'mix') {
          _go(0);
          homeWantAction.value = 'mix';
        } else if (type == 'radio') {
          _go(1);
          searchHubWantMode.value = 2;
        } else if (type == 'asistente') {
          _go(3);
        }
      });
      qa.setShortcutItems(const [
        ShortcutItem(type: 'mix', localizedTitle: 'Tu mix'),
        ShortcutItem(type: 'radio', localizedTitle: 'Radio en vivo'),
        ShortcutItem(type: 'asistente', localizedTitle: 'Asistente'),
      ]);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _setupShortcuts();
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
                  top: BorderSide(color: AppColors.navLine, width: 1),
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

/// Acción pedida desde un atajo del ícono (ej. 'mix').
final ValueNotifier<String?> homeWantAction = ValueNotifier<String?>(null);

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
    homeWantAction.addListener(_wantAction);
    StopLog.load();
    _load();
  }

  @override
  void dispose() {
    PlaybackUi.instance.libraryRevision.removeListener(_load);
    homeWantAction.removeListener(_wantAction);
    super.dispose();
  }

  void _wantAction() {
    final a = homeWantAction.value;
    if (a == null) return;
    homeWantAction.value = null;
    if (a == 'mix') _playMix();
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

  /// Frase grande de portada según la hora (estilo revista).
  String _coverLine() {
    final now = DateTime.now();
    final h = now.hour;
    final weekend = now.weekday >= DateTime.saturday;
    if (h >= 5 && h < 12) return weekend ? 'MAÑANA DE\nCARRETERA' : 'ARRANCA\nCON RIFFS';
    if (h >= 12 && h < 19) return weekend ? 'TARDE DE\nCARRETERA' : 'TARDE\nDE GUITARRAS';
    if (h >= 19 && h < 23) return 'NOCHE\nDE RIFFS';
    return 'MADRUGADA\nEN CALMA';
  }

  /// Mixes de ánimo ordenados para esta hora: tranquilo de noche, con
  /// energía de mañana, de carretera el fin de semana.
  List<MixDef> _hourMixes() {
    final now = DateTime.now();
    final h = now.hour;
    final weekend = now.weekday >= DateTime.saturday;
    String first;
    if (h >= 22 || h < 5) {
      first = 'Tranquilo';
    } else if (weekend && h >= 8 && h < 19) {
      first = 'Para manejar';
    } else if (h >= 5 && h < 12) {
      first = 'Energía';
    } else if (h >= 17 && h < 22) {
      first = 'Para entrenar';
    } else {
      first = 'Nostalgia';
    }
    final l = List<MixDef>.of(MixService.mood);
    l.sort((x, y) => (x.title == first ? 0 : 1) - (y.title == first ? 0 : 1));
    return l;
  }

  String _hourTitle() {
    final h = DateTime.now().hour;
    if (h >= 22 || h < 5) return 'Para esta noche';
    if (h < 12) return 'Para esta mañana';
    if (h < 19) return 'Para esta tarde';
    return 'Para esta noche';
  }

  Future<List<MixDef>>? _dailyFuture;

  /// 3 o 4 mixes diarios que se renuevan solos cada mañana (5 a. m.).
  Future<List<MixDef>> _loadDaily() async {
    var arts = <String>[];
    try {
      arts = await MixService.personalArtists();
    } catch (_) {}
    final uniq = <String>[];
    final seen = <String>{};
    for (final a in arts) {
      if (seen.add(a.toLowerCase())) uniq.add(a);
    }
    if (uniq.length < 3) return const <MixDef>[];
    final d = DateTime.now().subtract(const Duration(hours: 5));
    final seed = d.year * 400 + d.month * 32 + d.day;
    uniq.shuffle(math.Random(seed));
    final n = uniq.length >= 12 ? 4 : (uniq.length >= 6 ? 3 : 1);
    final per = (uniq.length / n).ceil().clamp(3, 10).toInt();
    return [
      for (var i = 0; i < n; i++)
        if (uniq.skip(i * per).isNotEmpty)
          MixDef(
            'Mix diario ${i + 1}',
            '${uniq[i * per]} y afines',
            const [Icons.today_rounded, Icons.bolt_rounded, Icons.album_rounded, Icons.graphic_eq_rounded][i % 4],
            AppPalettes.cards[i % AppPalettes.cards.length],
            uniq.skip(i * per).take(per).toList(),
          ),
    ];
  }

  Widget _dailyRow() {
    _dailyFuture ??= _loadDaily();
    return FutureBuilder<List<MixDef>>(
      future: _dailyFuture,
      builder: (context, snap) {
        final l = snap.data ?? const <MixDef>[];
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 176, child: SkeletonRow(itemWidth: 150, coverHeight: 150));
        }
        if (l.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: l.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final m = l[i];
              return _MixCard(
                def: m,
                onTap: () => _openMix(m.title, m.subtitle, m.colors,
                    MixService.buildMix(m.artists, pick: 40, perArtist: 6)),
              );
            },
          ),
        );
      },
    );
  }

  Future<_Nudge?>? _nudgeFuture;

  /// Tarjeta del asistente que toma la iniciativa: concierto de una banda
  /// que escuchas, o algo parecido a lo que más suena esta semana.
  Future<_Nudge?> _loadNudge() async {
    try {
      final plays = await StatsService.instance.plays(days: 7);
      final top = StatsService.topArtists(plays, n: 5);
      if (top.isEmpty) return null;
      await ConcertService.instance.ensureLoaded();
      final concerts = ConcertService.instance.state.value.items;
      for (final a in top) {
        final k = a.name.toLowerCase();
        for (final c in concerts) {
          if (c.band.toLowerCase().contains(k)) {
            return _Nudge(
              '${a.name} toca en ${c.city.isEmpty ? 'Colombia' : c.city}',
              '${c.date != null ? '${c.date!.day} de ${kMonthsLong[c.date!.month - 1]}' : (c.when.isEmpty ? 'Fecha por confirmar' : c.when)}${c.venue.isEmpty ? '' : ' · ${c.venue}'}. Toca para ver el concierto.',
              Icons.confirmation_number_outlined,
              concert: true,
            );
          }
        }
      }
      final a = top.first;
      if (a.count < 5) return null;
      return _Nudge(
        'Llevas una semana con ${a.name}',
        '¿Te armo algo parecido pero de bandas que no conoces?',
        Icons.auto_awesome_rounded,
        prompt:
            'Llevo una semana escuchando mucho ${a.name}. Arma una lista parecida pero con bandas que probablemente no conozco.',
      );
    } catch (_) {
      return null;
    }
  }

  Widget _nudgeCard() {
    _nudgeFuture ??= _loadNudge();
    return FutureBuilder<_Nudge?>(
      future: _nudgeFuture,
      builder: (context, snap) {
        final n = snap.data;
        if (n == null || _nudgeClosed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: const BorderSide(color: AppColors.borderAccent),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (n.concert) {
                  Navigator.of(context).push(MaterialPageRoute<String>(
                      builder: (_) => const ConcertsScreen())).then((band) {
                    if (band != null && band.isNotEmpty) _listenBand(band);
                  });
                } else {
                  widget.onNavigate(3);
                  assistantWantPrompt.value = n.prompt;
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, gradient: AppColors.accent),
                    child: Icon(n.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title,
                            style: const TextStyle(
                                fontSize: AppType.body,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(n.text,
                            style: const TextStyle(
                                fontSize: AppType.label,
                                height: 1.3,
                                color: AppColors.textDim)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ocultar sugerencia',
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textDim, size: 20),
                    onPressed: () => setState(() => _nudgeClosed = true),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _nudgeClosed = false;

  /// Cabecera que se encoge al hacer scroll: frase grande + última portada.
  Widget _sliverHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    const minH = 64.0, maxH = 190.0;
    final cover = _recent.isEmpty ? '' : _recent.first.image;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: minH,
      collapsedHeight: minH,
      expandedHeight: maxH,
      titleSpacing: 16,
      title: Row(children: [
        const PickLogo(size: 34),
        const SizedBox(width: 10),
        Text('ROCKPLAY', style: AppType.oswald(AppType.title)),
      ]),
      actions: [
        IconButton(
          tooltip: 'Ajustes',
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const SettingsHubScreen())),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: LayoutBuilder(builder: (context, box) {
        final t = ((box.maxHeight - minH - top) / (maxH - minH))
            .clamp(0.0, 1.0);
        return Stack(fit: StackFit.expand, children: [
          if (cover.isNotEmpty)
            Positioned(
              right: 20,
              bottom: 16,
              child: Opacity(
                opacity: t,
                child: Transform.rotate(
                  angle: 0.06,
                  child: CoverArt(
                      url: cover,
                      size: 92,
                      radius: AppRadius.md,
                      shadow: true,
                      seed: _recent.first.artist),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: cover.isEmpty ? 20 : 128,
            bottom: 16,
            child: Opacity(
              opacity: t,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_greeting().toUpperCase(), style: AppType.overline),
                  const SizedBox(height: 4),
                  Text(_coverLine(),
                      maxLines: 2,
                      style: AppType.oswald(AppType.display, height: 1.0)),
                ],
              ),
            ),
          ),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.red,
        onRefresh: () async {
          setState(() {
            _dailyFuture = null;
            _nudgeFuture = null;
            _nudgeClosed = false;
            _releasesFuture = null;
            _emergingFuture = null;
          });
          await _load();
        },
        child: CustomScrollView(
          slivers: [
            _sliverHeader(context),
            SliverPadding(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _stopNotice(),
                  _nudgeCard(),
                  _personalMix(),
                  const SectionTitle('Tus mixes diarios'),
                  _dailyRow(),
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
                  SectionTitle(_hourTitle()),
                  _mixRow(_hourMixes()),
                  const SectionTitle('Conciertos'),
                  ConcertsCard(onListen: _listenBand),
                  const SectionTitle('Descubrir'),
                  _discoverChips(),
                  const SizedBox(height: 14),
                  _discoverBody(),
                ]),
              ),
            ),
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
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: on ? null : Border.all(color: AppColors.outline),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: AppType.label,
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
              color: AppColors.amberTint,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border:
                  Border.all(color: AppColors.amberLine),
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
                            fontSize: AppType.label)),
                    const SizedBox(height: 2),
                    Text(motivo,
                        style: const TextStyle(fontSize: AppType.label, height: 1.3)),
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
                              fontWeight: FontWeight.w600, fontSize: AppType.label)),
                      Text(r.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: AppType.caption)),
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
                              fontSize: AppType.caption, fontWeight: FontWeight.w600)),
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
      AppPalettes.wine,
      MixService.buildMix(artists, pick: 30, perArtist: 10),
    );
  }

  Widget _personalMix() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                          borderRadius: BorderRadius.circular(AppRadius.pill),
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
                                    fontSize: AppType.body)),
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
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
    return Pressable(child: _card());
  }

  Widget _card() {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(
                url: song.image,
                size: 140,
                radius: AppRadius.md,
                shadow: true,
                seed: song.artist),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.bodySm),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textDim, fontSize: AppType.caption),
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
    return Pressable(child: _card(context));
  }

  Widget _card(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: def.colors,
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.borderSubtle),
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
                const Positioned.fill(
                  child: DecoratedBox(
                      decoration: BoxDecoration(gradient: AppColors.bottomScrim)),
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
                            fontSize: AppType.titleSm, height: 1.05, letterSpacing: 0.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        def.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: AppType.caption,
                            color: Color(0xE6FFFFFF)),
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

class _Nudge {
  final String title;
  final String text;
  final IconData icon;
  final bool concert;
  final String prompt;
  const _Nudge(this.title, this.text, this.icon,
      {this.concert = false, this.prompt = ''});
}
