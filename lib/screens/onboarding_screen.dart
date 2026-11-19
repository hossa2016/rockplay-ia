import 'package:flutter/material.dart';

import '../services/help_settings.dart';
import '../theme/app_theme.dart';

/// Guía de bienvenida: pantallas deslizables con lo que hace la app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Page {
  final IconData icon;
  final String title;
  final String text;
  const _Page(this.icon, this.title, this.text);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _i = 0;

  static const List<_Page> _pages = [
    _Page(Icons.music_note_rounded, 'Bienvenido a RockPlay IA',
        'Tu música rock en un solo lugar, con un asistente que te ayuda a elegir qué escuchar.'),
    _Page(Icons.home_rounded, 'Inicio: tu mix',
        'Arriba está Tu mix, armado con los artistas que más escuchas. Un toque y suena. Debajo sigues donde lo dejaste y descubres música nueva.'),
    _Page(Icons.search_rounded, 'Buscar',
        'Busca por artista o canción, explora por género, arma una emisora con un artista o sintoniza radios de rock en vivo.'),
    _Page(Icons.auto_awesome_rounded, 'Asistente',
        'Elige un ánimo o escribe lo que quieres, por ejemplo «rock para estudiar de noche», y el asistente arma la lista por ti.'),
    _Page(Icons.library_music_rounded, 'Mi música',
        'Guarda tus favoritas con el corazón, crea tus listas y revisa tu historial. En el reproductor puedes ver la letra y programar que se apague sola.'),
    _Page(Icons.info_outline_rounded, 'Si una canción no suena',
        'A veces YouTube no permite reproducir una canción en apps. La app la salta sola y te avisa. Todo se configura en Ajustes, con el engranaje.'),
  ];

  Future<void> _finish() async {
    await HelpSettings.markOnboarding(true);
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_i >= _pages.length - 1) {
      _finish();
    } else {
      _pc.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: _finish,
              child: Text(last ? '' : 'Saltar'),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _pages.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (context, k) {
                final p = _pages[k];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE5332E), Color(0xFF7A1411)],
                          ),
                        ),
                        child: Icon(p.icon, size: 68, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text(p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Text(p.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: AppColors.textDim)),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < _pages.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: k == _i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: k == _i ? AppColors.red : const Color(0xFF3A3A44),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: _next,
                child: Text(last ? 'Empezar' : 'Siguiente'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
