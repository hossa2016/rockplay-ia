import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/alarm_service.dart';
import 'services/data_saver.dart';
import 'services/block_service.dart';
import 'services/eq_service.dart';
import 'services/playback_service.dart';
import 'widgets/playback_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF14141A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  try {
    await DataSaver.instance.load();
  } catch (_) {}
  try {
    await BlockService.instance.ensureLoaded();
  } catch (_) {}
  try {
    await PlaybackService.instance.init();
    PlaybackUi.instance.start();
    unawaited(EqService.instance.init());
  } catch (_) {
    // La interfaz debe abrir aunque el audio falle al iniciar.
  }
  try {
    await AlarmService.instance.init();
    unawaited(AlarmService.instance.scheduleAll());
  } catch (_) {}
  runApp(const RockPlayApp());
}
