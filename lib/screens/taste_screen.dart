import 'package:flutter/material.dart';

import '../services/ai_settings.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/section_header.dart';
import 'ai_settings_screen.dart';

/// Lo que el asistente sabe de ti: todo sale de lo que escuchas en la app.
class TasteScreen extends StatefulWidget {
  const TasteScreen({super.key});

  @override
  State<TasteScreen> createState() => _TasteScreenState();
}

class _TasteScreenState extends State<TasteScreen> {
  List<PlayEntry> _plays = [];
  bool _loading = true;
  final AiSettings _s = AiSettings.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _s.load();
    final p = await StatsService.instance.plays(days: 60);
    if (!mounted) return;
    setState(() {
      _plays = p;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Borrar lo aprendido'),
        content: const Text(
            'Se borra el registro de lo que has escuchado. Tus favoritos y listas no se tocan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    await StatsService.instance.clear();
    await _load();
  }

  String _pattern() {
    if (_plays.length < 10) return '';
    var night = 0;
    var day = 0;
    for (final p in _plays) {
      final h = DateTime.fromMillisecondsSinceEpoch(p.ts * 1000).hour;
      if (h >= 20 || h < 6) {
        night++;
      } else {
        day++;
      }
    }
    final total = night + day;
    final pct = (night * 100 / total).round();
    if (pct >= 60) return 'Escuchas sobre todo de noche ($pct %).';
    if (pct <= 30) return 'Escuchas sobre todo de día (${100 - pct} %).';
    return 'Escuchas a lo largo de todo el día.';
  }

  @override
  Widget build(BuildContext context) {
    final top = StatsService.topArtists(_plays, n: 8);
    final pattern = _pattern();
    return Scaffold(
      appBar: AppBar(title: const Text('Tu gusto')),
      body: _loading
          ? const SkeletonList()
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'Esto es lo que el asistente usa para personalizar tus listas. '
                    'Sale de lo que escuchas aquí y no sale de tu teléfono, salvo los '
                    'nombres de artistas que se envían al servicio de IA al pedir una lista.',
                    style: TextStyle(color: AppColors.textDim, height: 1.45),
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Aprender de lo que escucho'),
                  subtitle: const Text('Si lo apagas, el asistente no usa tu historial'),
                  value: _s.learn,
                  onChanged: (v) async {
                    setState(() => _s.learn = v);
                    await _s.save();
                  },
                ),
                const SectionTitle('Artistas de los últimos 60 días'),
                if (top.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Todavía no hay datos. Escucha música y vuelve.',
                        style: TextStyle(color: AppColors.textDim)),
                  )
                else
                  for (final a in top)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            Text('${a.count}',
                                style:
                                    const TextStyle(color: AppColors.textDim)),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            child: LinearProgressIndicator(
                              value: a.count / top.first.count,
                              minHeight: 6,
                              color: AppColors.red,
                              backgroundColor:
                                  const Color.fromRGBO(255, 255, 255, 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                if (pattern.isNotEmpty) ...[
                  const SectionTitle('Patrón'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(pattern,
                        style: const TextStyle(color: AppColors.textBody)),
                  ),
                ],
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const AiSettingsScreen())),
                        icon: const Icon(Icons.key_rounded),
                        label: const Text('Claves del asistente'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _clear,
                        child: const Text('Borrar lo aprendido',
                            style: TextStyle(color: Color(0xFFFF8A80))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
