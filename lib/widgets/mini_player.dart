import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/playback_service.dart';
import '../theme/app_theme.dart';
import 'cover_art.dart';
import 'player_route.dart';
import 'playback_ui.dart';

/// Mini-reproductor persistente; aparece solo si hay canción.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: PlaybackUi.instance.song,
      builder: (context, song, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: song == null
              ? const SizedBox(width: double.infinity)
              : _MiniBody(song: song),
        );
      },
    );
  }
}

class _MiniBody extends StatelessWidget {
  final Song song;
  const _MiniBody({required this.song});

  @override
  Widget build(BuildContext context) {
    final pb = PlaybackUi.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            final svc = PlaybackService.instance;
            if (v < -300 && svc.hasNext) svc.next();
            if (v > 300 && svc.hasPrevious) svc.previous();
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -300) openPlayer(context);
          },
          child: InkWell(
          onTap: () => openPlayer(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                child: Row(
                  children: [
                    CoverArt(url: song.image, size: 44, radius: 8),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<String?>(
                            valueListenable: pb.error,
                            builder: (context, err, _) {
                              final hasErr = err != null && err.isNotEmpty;
                              return Text(
                                hasErr ? err : song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasErr
                                      ? AppColors.amber
                                      : AppColors.textDim,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    ListenableBuilder(
                      listenable: Listenable.merge(
                          [pb.playing, pb.loading, pb.index, pb.queue]),
                      builder: (context, _) {
                        final svc = PlaybackService.instance;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pb.loading.value)
                              const SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                iconSize: 32,
                                color: Colors.white,
                                icon: Icon(
                                  pb.playing.value
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                                onPressed: () => pb.playing.value
                                    ? svc.pause()
                                    : svc.play(),
                              ),
                            IconButton(
                              iconSize: 28,
                              color: Colors.white,
                              disabledColor: AppColors.textFaint,
                              icon: const Icon(Icons.skip_next_rounded),
                              onPressed: svc.hasNext ? () => svc.next() : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([pb.position, pb.duration]),
                builder: (context, _) {
                  final total = pb.duration.value?.inMilliseconds ?? 0;
                  final pos = pb.position.value.inMilliseconds;
                  final v = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
                  return LinearProgressIndicator(
                    value: v,
                    minHeight: 2.5,
                    color: AppColors.red,
                    backgroundColor: const Color.fromRGBO(255, 255, 255, 0.08),
                  );
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
