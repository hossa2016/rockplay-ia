import 'package:flutter/material.dart';

import '../services/ai_settings.dart';
import '../services/block_service.dart';
import '../services/data_saver.dart';
import '../theme/app_theme.dart';
import 'ai_settings_screen.dart';
import 'data_settings_screen.dart';
import 'taste_screen.dart';

/// Un solo lugar para todos los ajustes (agrupados).
class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AiSettings.instance.load();
    await DataSaver.instance.load();
    await BlockService.instance.ensureLoaded();
    await BadVideos.load();
    final b = await DataSaver.instance.sizeBytes();
    if (mounted) setState(() => _bytes = b);
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    _load();
  }

  String _size(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _group(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.amber)),
      );

  Widget _box(List<Widget> rows) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.outline),
            rows[i],
          ],
        ]),
      );

  Widget _row(IconData icon, String title, String value, VoidCallback onTap,
      {String? badge}) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDim)),
                ],
              ),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(badge,
                    style: const TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w800)),
              ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDim),
          ]),
        ),
      ),
    );
  }

  void _showSkipped() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Canciones que no sonaron'),
        content: SizedBox(
          width: double.maxFinite,
          child: SkipLog.entries.isEmpty
              ? const Text('Todavía no se ha saltado ninguna.')
              : ListView(shrinkWrap: true, children: [
                  for (final e in SkipLog.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(e, style: const TextStyle(fontSize: 12.5)),
                    ),
                ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showBlocked() {
    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        final names = BlockService.instance.names;
        return AlertDialog(
          title: const Text('Artistas que no quiero'),
          content: SizedBox(
            width: double.maxFinite,
            child: names.isEmpty
                ? const Text('No has ocultado ningún artista.')
                : ListView(shrinkWrap: true, children: [
                    for (final n in names)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(n),
                        trailing: TextButton(
                          onPressed: () async {
                            await BlockService.instance.remove(n);
                            set(() {});
                          },
                          child: const Text('Quitar'),
                        ),
                      ),
                  ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cerrar')),
          ],
        );
      }),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final ai = AiSettings.instance;
    final ds = DataSaver.instance;
    final aiOn = ai.groqKey.trim().isNotEmpty || ai.geminiKey.trim().isNotEmpty;
    final aiLabel = ai.geminiKey.trim().isNotEmpty
        ? 'Activada con Gemini'
        : ai.groqKey.trim().isNotEmpty
            ? 'Activada con Groq'
            : 'Sin claves · usa reglas simples';
    final bad = BadVideos.ids.length;
    final blocked = BlockService.instance.names.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _group('ASISTENTE'),
          _box([
            _row(Icons.vpn_key_rounded, 'Activar la IA', aiLabel,
                () => _go(const AiSettingsScreen()),
                badge: aiOn ? null : '!'),
            _row(Icons.format_list_numbered_rounded, 'Canciones por lista',
                '${ai.maxSongs} como máximo',
                () => _go(const AiSettingsScreen())),
            _row(Icons.insights_rounded, 'Tu gusto',
                'Aprende de lo que escuchas', () => _go(const TasteScreen())),
          ]),
          _group('DATOS'),
          _box([
            _row(Icons.storage_rounded, 'Almacenamiento',
                '${_size(_bytes)} en uso',
                () => _go(const DataSettingsScreen())),
            _row(Icons.tune_rounded, 'Tamaño de los mixes',
                'Hasta ${ds.mixSongs} canciones y ${ds.mixArtists} artistas',
                () => _go(const DataSettingsScreen())),
          ]),
          _group('REPRODUCCIÓN'),
          _box([
            _row(Icons.bug_report_outlined, 'Canciones que no sonaron',
                bad == 0
                    ? 'Ninguna por ahora'
                    : 'YouTube bloquea $bad de tus canciones',
                _showSkipped,
                badge: bad == 0 ? null : '$bad'),
            _row(Icons.block_rounded, 'Artistas que no quiero',
                blocked == 0
                    ? 'Ninguno oculto'
                    : '$blocked ${blocked == 1 ? "artista oculto" : "artistas ocultos"}',
                _showBlocked),
          ]),
        ],
      ),
    );
  }
}
