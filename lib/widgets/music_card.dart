import 'package:flutter/material.dart';
import '../services/playback_service.dart';
import 'package:flutter/services.dart';

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
        // Sin ▶ redundante (toda la fila ya reproduce): la que suena muestra
        // el ecualizador; el menú ⋮ va aparte.
        final Widget end = trailing ??
            (isCurrent
                // Ecualizador: ámbar si suena, gris si está en pausa (antes
                // un ícono de pausa que contradecía al mini player).
                ? Semantics(
                    label: pb.playing.value ? 'Sonando' : 'En pausa',
                    child: Icon(Icons.graphic_eq_rounded,
                        color: pb.playing.value
                            ? AppColors.amber
                            : AppColors.textFaint))
                : const SizedBox.shrink());
        final card = Material(
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
                            fontSize: AppType.body,
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
                          style: TextStyle(
                            fontSize: AppType.label,
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
                        icon: Icon(Icons.more_vert_rounded,
                            color: AppColors.textDim),
                        onPressed: () => showSongActions(context, song),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        if (!actions) return card;
        return Dismissible(
          key: ValueKey<String>('mc-${song.videoId}-${song.title}-${song.artist}'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            HapticFeedback.mediumImpact();
            PlaybackService.instance.queuePlayNext(song);
            ScaffoldMessenger.maybeOf(context)
              ?..clearSnackBars()
              ..showSnackBar(const SnackBar(
                  content: Text('Sonará a continuación'),
                  duration: Duration(seconds: 2)));
            return false;
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            color: AppColors.red.withValues(alpha: 0.18),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.queue_play_next_rounded, color: AppColors.amber),
              SizedBox(width: 10),
              Text('A continuación',
                  style: TextStyle(
                      color: AppColors.amber, fontWeight: FontWeight.w700)),
            ]),
          ),
          child: card,
        );
      },
    );
  }
}
