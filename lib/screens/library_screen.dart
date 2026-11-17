import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/playback_ui.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'stats_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Song> _favs = [];
  List<Song> _hist = [];
  bool _loading = true;
  bool _failed = false;

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
    try {
      final f = await LibraryService.instance.favorites();
      final h = await LibraryService.instance.history();
      if (!mounted) return;
      setState(() {
        _favs = f;
        _hist = h;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _unfavorite(Song s) async {
    try {
      await LibraryService.instance.toggleFavorite(s);
    } catch (_) {}
    PlaybackUi.instance.bumpLibrary();
  }

  Widget _list(List<Song> songs, {required bool favorites}) {
    if (_loading) return const SkeletonList();
    if (_failed) {
      return StateMessage(
        icon: Icons.error_outline_rounded,
        title: 'No se pudo cargar',
        message: 'Hubo un problema al leer tu biblioteca.',
        actionLabel: 'Reintentar',
        onAction: _load,
        isError: true,
      );
    }
    if (songs.isEmpty) {
      return favorites
          ? const StateMessage(
              icon: Icons.favorite_border_rounded,
              title: 'Aún no tienes favoritos',
              message: 'Toca el corazón en el reproductor para guardar tus temas.',
            )
          : const StateMessage(
              icon: Icons.history_rounded,
              title: 'Nada por aquí todavía',
              message: 'Lo que escuches aparecerá en tu historial.',
            );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: songs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () => playSongs(context, songs, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                ),
              ],
            ),
          );
        }
        final idx = i - 1;
        final song = songs[idx];
        return FadeIn(
          order: idx,
          child: MusicCard(
            song: song,
            onTap: () => playSongs(context, songs, idx),
            trailing: favorites
                ? IconButton(
                    tooltip: 'Quitar de favoritos',
                    icon: const Icon(Icons.favorite_rounded,
                        color: AppColors.red),
                    onPressed: () => _unfavorite(song),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Mi música',
                trailing: IconButton(
                  tooltip: 'Tus estadísticas',
                  icon: const Icon(Icons.insights_rounded),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const StatsScreen())),
                ),
              ),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorColor: AppColors.red,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textFaint,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                padding: EdgeInsets.symmetric(horizontal: 12),
                tabs: [
                  Tab(text: 'Favoritos'),
                  Tab(text: 'Historial'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(_favs, favorites: true),
                    _list(_hist, favorites: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
