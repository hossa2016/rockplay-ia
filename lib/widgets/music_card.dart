import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'cover_art.dart';
import 'playback_ui.dart';
import 'song_actions.dart';

/// Fila de canción con portada, resaltada si es la que suena.
class MusicCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool actions;

  const MusicCard({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.actions = true,
  });

  @override
  Widget build(BuildContext context) {
    final pb = PlaybackUi.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([pb.song, pb.playing]),
      builder: (context, _) {
        final cur = pb.song.value;
        final isCurrent =
            cur != null && cur.title == song.title && cur.artist == song.artist;
        final Widget end = trailing ??
            Icon(
              isCurrent && pb.playing.value
                  ? Icons.graphic_eq_rounded
                  : Icons.play_arrow_rounded,
              color: isCurrent ? AppColors.amber : AppColors.textFaint,
            );
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress:
                actions ? () => showSongActions(context, song) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  CoverArt(url: song.image, size: 56, radius: 8, seed: song.artist),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: isCurrent ? AppColors.amber : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  end,
                  if (actions && trailing == null)
                    SizedBox(
                      width: 40,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Más opciones',
                        icon: const Icon(Icons.more_vert_rounded,
                            color: AppColors.textDim),
                        onPressed: () => showSongActions(context, song),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
