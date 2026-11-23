import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';
import 'artist_screen.dart';
import 'taste_screen.dart';
import '../widgets/state_views.dart';

/// Lo que más escuchas: artistas y canciones por semana, mes o siempre.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _range = 0; // 0 semana, 1 mes, 2 siempre
  List<PlayEntry> _plays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final days = _range == 0 ? 7 : (_range == 1 ? 30 : null);
    final p = await StatsService.instance.plays(days: days);
    if (!mounted) return;
    setState(() {
      _plays = p;
      _loading = false;
    });
  }

  Song _song(PlayEntry p) {
    final s = Song(
        title: p.title,
        artist: p.artist,
        image: p.image,
        query: '${p.artist} ${p.title}');
    return p.videoId.isEmpty ? s : s.withVideoId(p.videoId);
  }

  Widget _bar(String label, int count, int max, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Text('$count',
                    style: const TextStyle(color: AppColors.textDim)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : count / max,
                minHeight: 6,
                color: AppColors.redText,
                backgroundColor: const Color.fromRGBO(255, 255, 255, 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final artists = StatsService.topArtists(_plays);
    final songs = StatsService.topSongs(_plays);
    final label = ['Esta semana', 'Este mes', 'Desde siempre'][_range];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const PageHeader(
                title: 'Tus números',
                subtitle: 'Lo que más escuchas y lo que la app sabe de tu gusto'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.amber),
                  title: const Text('Tu gusto',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Lo que aprendí de lo que escuchas',
                      style: TextStyle(color: AppColors.textDim)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textDim),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const TasteScreen())),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      label: Text(['Semana', 'Mes', 'Siempre'][i]),
                      selected: _range == i,
                      onSelected: (_) {
                        _range = i;
                        _load();
                      },
                    ),
                ],
              ),
            ),
            if (_loading)
              const SkeletonList(count: 6, shrinkWrap: true)
            else if (_plays.isEmpty)
              const StateMessage(
                icon: Icons.insights_rounded,
                title: 'Todavía sin datos',
                message:
                    'No hay canciones en este período. Escucha música y vuelve aquí.',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Text('$label: ${_plays.length} canciones escuchadas',
                    style: const TextStyle(color: AppColors.amber)),
              ),
              const SectionTitle('Artistas más escuchados'),
              for (final a in artists)
                _bar(a.name, a.count, artists.first.count,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ArtistScreen(name: a.name)))),
              const SectionTitle('Canciones más escuchadas'),
              for (final s in songs)
                _bar(s.name, s.count, songs.first.count,
                    onTap: s.sample == null
                        ? null
                        : () => playSongs(
                            context, [for (final x in songs) _song(x.sample!)],
                            songs.indexOf(s))),
            ],
          ],
        ),
      ),
    );
  }
}
