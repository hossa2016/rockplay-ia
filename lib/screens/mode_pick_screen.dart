import 'package:flutter/material.dart';

import '../services/music_mode.dart';
import '../theme/app_theme.dart';
import '../widgets/rock_decor.dart';

/// Primera vez: «¿Qué vas a escuchar?». Decide cómo opera la app.
class ModePickScreen extends StatefulWidget {
  const ModePickScreen({super.key});

  @override
  State<ModePickScreen> createState() => _ModePickScreenState();
}

class _ModePickScreenState extends State<ModePickScreen> {
  MusicMode _pick = MusicMode.rock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B12),
      body: SafeArea(
        child: Dense(
          max: 1.2,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              const Row(children: [
                _PulseBadge(size: 36),
                SizedBox(width: 10),
                Text('Bienvenido',
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontVariations: [FontVariation('wght', 700)])),
              ]),
              const SizedBox(height: 28),
              const Text('¿Qué vas a escuchar?',
                  style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 34,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      fontVariations: [FontVariation('wght', 700)])),
              const SizedBox(height: 8),
              const Text(
                  'La app se adapta: géneros, mixes, asistente, conciertos, colores y textos. Puedes cambiarlo cuando quieras en Ajustes.',
                  style: TextStyle(
                      fontSize: 15, height: 1.45, color: Color(0xFFA9A9BC))),
              const SizedBox(height: 22),
              ModeOption(
                mode: MusicMode.rock,
                selected: _pick == MusicMode.rock,
                onTap: () => setState(() => _pick = MusicMode.rock),
              ),
              const SizedBox(height: 12),
              ModeOption(
                mode: MusicMode.general,
                selected: _pick == MusicMode.general,
                onTap: () => setState(() => _pick = MusicMode.general),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _pick == MusicMode.rock
                        ? const Color(0xFFC92B26)
                        : const Color(0xFF5B3FE0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => MusicModeService.set(_pick),
                  child: const Text('Continuar',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de un modo, con sus propios colores (no los del tema actual).
class ModeOption extends StatelessWidget {
  final MusicMode mode;
  final bool selected;
  final VoidCallback onTap;
  const ModeOption(
      {super.key,
      required this.mode,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rock = mode == MusicMode.rock;
    final ring = rock ? const Color(0xFFFFB02E) : const Color(0xFFB8A8FF);
    final chips = rock
        ? const ['Grunge', 'Heavy metal', 'Rock en español']
        : const ['Pop', 'Salsa', 'Reguetón', 'Vallenato', 'Rock'];
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: const Color(0xFF15151F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
              color: selected ? ring : const Color(0xFF2E2E40),
              width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  rock ? const _RockBadge(size: 56) : const _PulseBadge(size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rock ? 'SOLO ROCK' : 'Todos los géneros',
                            style: TextStyle(
                                fontFamily: rock ? 'Oswald' : 'SpaceGrotesk',
                                fontSize: 22,
                                letterSpacing: rock ? 0.5 : -0.2,
                                fontWeight: FontWeight.w700,
                                fontVariations: const [
                                  FontVariation('wght', 700)
                                ])),
                        const SizedBox(height: 2),
                        Text(
                            rock
                                ? 'RockPlay como la conoces: rock, metal, punk y más'
                                : 'Pulso: pop, salsa, urbano, vallenato, electrónica y más',
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Color(0xFFA9A9BC))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: selected ? ring : const Color(0xFF55556A),
                          width: 2),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle, color: ring))
                        : null,
                  ),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F2C),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFF2E2E40)),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RockBadge extends StatelessWidget {
  final double size;
  const _RockBadge({required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC92B26), Color(0xFF3A0A08)]),
        ),
        child: Icon(Icons.bolt_rounded,
            color: const Color(0xFFFFB02E), size: size * 0.55),
      );
}

class _PulseBadge extends StatelessWidget {
  final double size;
  const _PulseBadge({required this.size});
  @override
  Widget build(BuildContext context) => PulseLogo(size: size);
}

/// Ajustes → Modo de música, con vista previa de cada modo.
class MusicModeScreen extends StatelessWidget {
  const MusicModeScreen({super.key});

  Widget _preview(MusicMode m, bool active) {
    final rock = m == MusicMode.rock;
    final font = rock ? 'Oswald' : 'SpaceGrotesk';
    return Expanded(
      child: Column(children: [
        Container(
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: rock ? const Color(0xFF0A0A0D) : const Color(0xFF0B0B12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active
                    ? (rock ? const Color(0xFFFFB02E) : const Color(0xFFB8A8FF))
                    : const Color(0xFF262636),
                width: active ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rock ? 'ROCKPLAY' : 'Pulso',
                  style: TextStyle(
                      fontFamily: font,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)])),
              const SizedBox(height: 8),
              Text(rock ? 'ARRANCA\nCON RIFFS' : 'Empieza con\nlo tuyo',
                  maxLines: 2,
                  style: TextStyle(
                      fontFamily: font,
                      fontSize: 16,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)])),
              const SizedBox(height: 10),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                      colors: rock
                          ? const [Color(0xFFB3201B), Color(0xFF5A0F0D)]
                          : const [Color(0xFF6A4CF0), Color(0xFF2EC5D3)]),
                ),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
            active ? 'Activo · ${rock ? 'Rock' : 'Todos'}' : (rock ? 'Rock' : 'Todos'),
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? AppColors.redText : AppColors.textDim)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MusicMode>(
      valueListenable: MusicModeService.mode,
      builder: (context, mode, _) => Scaffold(
        appBar: AppBar(title: const Text('Modo de música')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Dense(
              child: SegmentedButton<MusicMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: MusicMode.rock, label: Text('Solo rock')),
                  ButtonSegment(
                      value: MusicMode.general,
                      label: Text('Todos los géneros')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => _confirm(context, s.first),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _preview(MusicMode.rock, mode == MusicMode.rock),
              const SizedBox(width: 10),
              _preview(MusicMode.general, mode == MusicMode.general),
            ]),
            const SizedBox(height: 14),
            Text(
                'Al cambiar se ajustan los géneros, mixes, asistente, conciertos, ecualizador, tono del despertador y colores. Tus favoritas, listas e historial no se tocan.',
                style: TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, MusicMode m) async {
    if (m == MusicModeService.mode.value) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(m == MusicMode.general
            ? '¿Cambiar a Todos los géneros?'
            : '¿Volver a Solo rock?'),
        content: const Text(
            'La app se recarga con los nuevos colores y géneros y vuelve a Inicio. La música que suena no se detiene.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cambiar')),
        ],
      ),
    );
    if (ok == true) await MusicModeService.set(m);
  }
}
