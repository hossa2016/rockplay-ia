import 'package:flutter/material.dart';

import '../models/song.dart';
import '../screens/player_screen.dart';
import '../services/playback_service.dart';

/// Ruta que sube desde abajo hacia la pantalla de reproducción.
Route<void> playerRoute() {
  return PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondary) => const PlayerScreen(),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(curved),
        child: child,
      );
    },
  );
}

void openPlayer(BuildContext context) {
  Navigator.of(context).push(playerRoute());
}

Future<void> _safePlay(List<Song> songs, int index) async {
  try {
    await PlaybackService.instance.playQueue(songs, index);
  } catch (_) {
    // El error se refleja en PlaybackService.error.
  }
}

/// Arranca la cola y abre la pantalla de reproducción.
void playSongs(BuildContext context, List<Song> songs, int index) {
  if (songs.isEmpty || index < 0 || index >= songs.length) return;
  _safePlay(List<Song>.of(songs), index);
  openPlayer(context);
}
