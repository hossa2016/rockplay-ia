import 'package:flutter/services.dart';

import 'music_mode.dart';

/// Cambia el nombre e ícono del escritorio: «RockPlay IA» o «Pulso».
/// Android puede tardar unos segundos en mostrar el cambio y, en algunos
/// launchers, el ícono desaparece un momento.
class LauncherAlias {
  LauncherAlias._();
  static const _ch = MethodChannel('rockplay/launcher');

  static Future<void> sync() async {
    try {
      await _ch.invokeMethod('setMode', {'pulso': MusicModeService.general});
    } catch (_) {}
  }
}
