import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/player_route.dart';
import '../widgets/state_views.dart';

/// Lista de canciones con botones Aleatorio / En orden. Sirve para mixes
/// (llegan por [stream]) y para listas propias ([songs] + [onRemove]).
class SongListScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final Stream<List<Song>>? stream;
  final List<Song>? songs;
  final Future<void> Function(Song song)? onRemove;
  final VoidCallback? onDeleteList;
  final String emptyMessage;

  const SongListScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.colors = const [Color(0xFF7A1411), Color(0xFF14141A)],
    this.stream,
    this.songs,
    this.onRemove,
    this.onDeleteList,
    this.emptyMessage = 'No hay canciones todavía.',
  });

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  List<Song> _songs = <Song>[];
  bool _loading = false;
  StreamSubscription<List<Song>>? _sub;

  @override
  void initState() {
    super.initState();
    final st = widget.stream;
    if (st != null) {
      _loading = true;
      _sub = st.listen(
        (l) {
          if (mounted) setState(() => _songs = l);
        },
        onError: (Object _) {
          if (mounted) setState(() => _loading = false);
        },
        onDone: () {
          if (mounted) setState(() => _loading = false);
        },
      );
    } else {
      _songs = List<Song>.of(widget.songs ?? const <Song>[]);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _shuffle() {
    if (_songs.isEmpty) return;
    final l = List<Song>.of(_songs)..shuffle();
    playSongs(context, l, 0);
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.colors.first, AppColors.bg],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (widget.onDeleteList != null)
                  IconButton(
                    tooltip: 'Borrar lista',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: widget.onDeleteList,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.title,
                style: Theme.of(context).textTheme.displaySmall),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style: const TextStyle(color: AppColors.textDim)),
            ],
            const SizedBox(height: 6),
            Text(
              _loading
                  ? '${_songs.length} canciones · cargando más…'
                  : '${_songs.length} canciones',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _songs.isEmpty ? null : _shuffle,
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatorio'),
                ),
                OutlinedButton.icon(
                  onPressed: _songs.isEmpty
                      ? null
                      : () => playSongs(context, _songs, 0),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _songs.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _header();
          if (i == _songs.length + 1) {
            if (_songs.isEmpty && _loading) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 3),
                      SizedBox(height: 16),
                      Text('Armando tu mix…',
                          style: TextStyle(color: AppColors.textDim)),
                    ],
                  ),
                ),
              );
            }
            if (_songs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }
          final idx = i - 1;
          final song = _songs[idx];
          return FadeIn(
            order: idx < 12 ? idx : 0,
            child: MusicCard(
              song: song,
              onTap: () => playSongs(context, _songs, idx),
              trailing: widget.onRemove == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: AppColors.textFaint),
                      onPressed: () async {
                        await widget.onRemove!(song);
                        if (mounted) setState(() => _songs.removeAt(idx));
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
