import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ai_settings_screen.dart';
import 'data_settings_screen.dart';
import 'stats_screen.dart';

/// Un solo lugar para todos los ajustes.
class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  Widget _row(BuildContext context, IconData icon, String title, String sub,
      Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: InkWell(
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: AppColors.red),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textDim),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _row(context, Icons.data_saver_on_rounded, 'Datos y almacenamiento',
              'Caché, tamaño de los mixes y registro de canciones saltadas.',
              const DataSettingsScreen()),
          _row(context, Icons.auto_awesome_rounded, 'Asistente de IA',
              'Claves de Gemini y Groq, y canciones por lista.',
              const AiSettingsScreen()),
          _row(context, Icons.insights_rounded, 'Tus estadísticas',
              'Lo que más escuchas.', const StatsScreen()),
        ],
      ),
    );
  }
}
