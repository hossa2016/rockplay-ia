import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/playlist_service.dart';
import '../widgets/add_to_playlist.dart';
import '../widgets/cover_art.dart';
import 'stats_screen.dart';
import '../widgets/undo.dart';
import 'song_list_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/playback_ui.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Song> _favs = [];
  List<Song> _hist = [];
  List<Playlist> _lists = [];
  bool _loading = true;
  String _q = '';
  int _sort = 0;
  final TextEditingController _qc = TextEditingController();
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
    _qc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final f = await LibraryService.instance.favorites();
      final h = await LibraryService.instance.history();
      final pl = await PlaylistService.instance.all();
      if (!mounted) return;
      setState(() {
        _favs = f;
        _hist = h;
        _lists = pl;
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
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      persist: false,
      content: const Text('Quitada de favoritos'),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () async {
          try {
            await LibraryService.instance.toggleFavorite(s);
          } catch (_) {}
          PlaybackUi.instance.bumpLibrary();
        },
      ),
    ));
  }

  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
            'Se borrarán todas las canciones que has escuchado. Tus favoritos no se tocan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LibraryService.instance.clearHistory();
    } catch (_) {}
    PlaybackUi.instance.bumpLibrary();
    if (mounted) _load();
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
    final all = songs;
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      songs = songs
          .where((x) =>
              x.title.toLowerCase().contains(q) ||
              x.artist.toLowerCase().contains(q))
          .toList();
    }
    if (_sort == 1) {
      songs = List<Song>.of(songs)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sort == 2) {
      songs = List<Song>.of(songs)
        ..sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: songs.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (all.length > 6)
                  TextField(
                    controller: _qc,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar en esta lista',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                    _qc.clear();
                                    _q = '';
                                  }),
                            ),
                    ),
                  ),
                if (all.length > 6) const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const [
                      [0, 'Recientes'],
                      [1, 'A–Z'],
                      [2, 'Artista']
                    ])
                      ChoiceChip(
                        label: Text(e[1] as String),
                        selected: _sort == e[0],
                        onSelected: (_) => setState(() => _sort = e[0] as int),
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        if (i == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'}',
                    style: TextStyle(color: AppColors.textDim),
                  ),
                ),
                if (!favorites)
                  IconButton(
                    tooltip: 'Borrar historial',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _confirmClearHistory,
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
        final idx = i - 2;
        final song = songs[idx];
        return FadeIn(
          order: idx,
          child: MusicCard(
            song: song,
            onTap: () => playSongs(context, songs, idx),
            trailing: favorites
                ? IconButton(
                    tooltip: 'Quitar de favoritos',
                    icon: Icon(Icons.favorite_rounded,
                        color: AppColors.redText),
                    onPressed: () => _unfavorite(song),
                  )
                : null,
          ),
        );
      },
    );
  }

  /// Borra la lista y ofrece «Deshacer».
  Future<void> _deleteList(Playlist p) async {
    final r = await PlaylistService.instance.delete(p.id);
    PlaybackUi.instance.bumpLibrary();
    if (r == null || !mounted) return;
    showUndo(context, 'Lista «${p.name}» borrada', () async {
      await PlaylistService.instance.restore(r.$1, r.$2);
      PlaybackUi.instance.bumpLibrary();
    });
  }

  Future<void> _newList() async {
    final name = await askPlaylistName(context);
    if (name == null || name.trim().isEmpty) return;
    await PlaylistService.instance.create(name);
    PlaybackUi.instance.bumpLibrary();
  }

  Widget _listsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 8,
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.redText),
            ),
            child: Icon(Icons.add_rounded, color: AppColors.redText),
          ),
          title: const Text('Nueva lista',
              style: TextStyle(fontWeight: FontWeight.w700)),
          onTap: _newList,
        ),
        if (_lists.isEmpty)
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aún no tienes listas. Crea una o guarda la que arme el asistente.',
              style: TextStyle(color: AppColors.textDim, height: 1.4),
            ),
          ),
        for (final p in _lists)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: SizedBox(
              width: 52,
              height: 52,
              child: CoverArt(
                  url: p.songs.isEmpty ? '' : p.songs.first.image, radius: AppRadius.sm),
            ),
            title: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${p.songs.length} canciones',
                style: TextStyle(color: AppColors.textDim)),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textDim),
              onSelected: (v) async {
                if (v == 'rename') {
                  final n = await askPlaylistName(context);
                  if (n == null || n.trim().isEmpty) return;
                  await PlaylistService.instance.rename(p.id, n);
                } else {
                  await _deleteList(p);
                  return;
                }
                PlaybackUi.instance.bumpLibrary();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                PopupMenuItem(value: 'delete', child: Text('Borrar lista')),
              ],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => SongListScreen(
                title: p.name,
                subtitle: 'Tu lista',
                songs: p.songs,
                emptyMessage:
                    'Lista vacía. Guarda canciones desde el reproductor.',
                playlistId: p.id,
                onRemove: (s) async {
                  await PlaylistService.instance.removeSong(p.id, s.videoId);
                  PlaybackUi.instance.bumpLibrary();
                },
                onDeleteList: () async {
                  Navigator.of(context).pop();
                  await _deleteList(p);
                },
              ),
            )),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: _TabJump(child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Mi música',
                trailing: TextButton.icon(
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.amber),
                  icon: const Icon(Icons.insights_rounded),
                  label: const Text('Tus números'),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const StatsScreen())),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Dense(child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.redBtn,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textDim,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: AppType.bodySm),
                  onTap: (_) => HapticFeedback.selectionClick(),
                  tabs: const [
                    Tab(height: 48, text: 'Favoritos'),
                    Tab(height: 48, text: 'Listas'),
                    Tab(height: 48, text: 'Historial'),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(_favs, favorites: true),
                    _listsTab(),
                    _list(_hist, favorites: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

/// Pide abrir una pestaña de Mi música desde fuera (0 favoritos, 1 listas,
/// 2 historial).
final ValueNotifier<int> libraryWantTab = ValueNotifier<int>(-1);

class _TabJump extends StatefulWidget {
  final Widget child;
  const _TabJump({required this.child});

  @override
  State<_TabJump> createState() => _TabJumpState();
}

class _TabJumpState extends State<_TabJump> {
  @override
  void initState() {
    super.initState();
    libraryWantTab.addListener(_jump);
  }

  void _jump() {
    final i = libraryWantTab.value;
    if (i < 0) return;
    libraryWantTab.value = -1;
    try {
      DefaultTabController.of(context).animateTo(i);
    } catch (_) {}
  }

  @override
  void dispose() {
    libraryWantTab.removeListener(_jump);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
