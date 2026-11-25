import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo opera la app: solo rock (RockPlay) o todos los géneros (Pulso).
enum MusicMode { rock, general }

class MusicModeService {
  MusicModeService._();

  static const _key = 'music_mode';
  static const _chosenKey = 'music_mode_chosen';

  /// Cambia el tema, los textos, los géneros y el asistente al instante.
  static final ValueNotifier<MusicMode> mode = ValueNotifier(MusicMode.rock);

  /// true si la persona ya respondió «¿Qué vas a escuchar?».
  static bool chosen = false;

  static bool get general => mode.value == MusicMode.general;
  static bool get rock => mode.value == MusicMode.rock;

  /// Nombre visible de la app según el modo.
  static String get appName => general ? 'Pulso' : 'RockPlay IA';

  static Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      mode.value =
          sp.getString(_key) == 'general' ? MusicMode.general : MusicMode.rock;
      // Quien ya usaba la app antes de esta versión sigue en rock sin
      // que le pregunten nada.
      chosen = sp.getBool(_chosenKey) ??
          sp.getKeys().any((k) => k != _key && k != _chosenKey);
    } catch (_) {}
  }

  static Future<void> set(MusicMode m) async {
    chosen = true;
    mode.value = m;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, m == MusicMode.general ? 'general' : 'rock');
      await sp.setBool(_chosenKey, true);
    } catch (_) {}
  }
}
