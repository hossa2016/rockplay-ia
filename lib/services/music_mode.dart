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
  static final ValueNotifier<bool> chosenN = ValueNotifier(false);
  static bool get chosen => chosenN.value;

  /// Cambia cada vez que cambia el modo: sirve para descartar búsquedas
  /// que empezaron en el otro modo.
  static int generation = 0;

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
      var c = sp.getBool(_chosenKey);
      if (c == null) {
        // Quien ya tenía música guardada de versiones anteriores sigue en
        // rock sin que le pregunten.
        c = const ['favorites', 'history', 'plays_v1'].any(sp.containsKey);
        if (c) await sp.setBool(_chosenKey, true);
      }
      chosenN.value = c;
    } catch (_) {}
  }

  static Future<void> set(MusicMode m) async {
    if (m != mode.value) generation++;
    mode.value = m;
    chosenN.value = true;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_key, m == MusicMode.general ? 'general' : 'rock');
      await sp.setBool(_chosenKey, true);
    } catch (_) {}
  }
}

/// Texto según el modo: `byMode('NOCHE DE RIFFS', 'Tu noche')`.
String byMode(String rock, String general) =>
    MusicModeService.general ? general : rock;
