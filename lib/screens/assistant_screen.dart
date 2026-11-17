import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/ai_client.dart';
import '../services/ai_settings.dart';
import '../services/assistant_service.dart';
import '../services/playlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_route.dart';
import '../widgets/playback_ui.dart';
import 'ai_settings_screen.dart';
import 'taste_screen.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final AssistantResult? result;
  _Msg(this.fromUser, this.text, [this.result]);
}

/// Chat con el asistente: pide listas por ánimo o con tus propias palabras.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const List<String> _moods = [
    'Con energía',
    'Melancólico',
    'Para concentrarme',
    'De carretera',
    'Quiero algo nuevo',
  ];
  static const List<String> _tweaks = [
    'Más tranquilo',
    'Más pesado',
    'Solo en español',
    'Más canciones nuevas',
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _busy = false;
  bool _noKeys = false;

  @override
  void initState() {
    super.initState();
    AiSettings.instance.load().then((_) {
      final s = AiSettings.instance;
      if (mounted) {
        setState(() =>
            _noKeys = s.groqKey.trim().isEmpty && s.geminiKey.trim().isEmpty);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    final history = [
      for (final m in _msgs)
        AiMessage(m.fromUser, m.fromUser ? m.text : _summary(m)),
    ];
    setState(() {
      _msgs.add(_Msg(true, t));
      _busy = true;
      _input.clear();
    });
    _toBottom();
    AssistantResult r;
    try {
      r = await AssistantService.instance.ask(t, history);
    } catch (_) {
      r = const AssistantResult(
          'No pude armar la lista ahora. Revisa tu conexión e inténtalo de nuevo.',
          '',
          <Song>[],
          'Reglas simples');
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, r.reply, r));
      _busy = false;
    });
    _toBottom();
  }

  /// Resumen de la respuesta anterior para que la IA tenga contexto.
  String _summary(_Msg m) {
    final r = m.result;
    if (r == null || r.songs.isEmpty) return m.text;
    final names = r.songs.take(10).map((s) => '${s.artist} - ${s.title}');
    return '${m.text} Lista "${r.title}": ${names.join('; ')}';
  }

  Future<void> _save(AssistantResult r) async {
    final p = await PlaylistService.instance.create(r.title);
    await PlaylistService.instance.addMany(p.id, r.songs);
    PlaybackUi.instance.bumpLibrary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardada como "${p.name}" en Mi música.')));
  }

  Widget _chip(String label, VoidCallback onTap) => ActionChip(
        label: Text(label),
        onPressed: _busy ? null : onTap,
      );

  Widget _bubble(_Msg m, bool last) {
    final r = m.result;
    final user = m.fromUser;
    return Column(
      crossAxisAlignment:
          user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: user ? AppColors.red : AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(user ? 18 : 6),
              bottomRight: Radius.circular(user ? 6 : 18),
            ),
          ),
          child: Text(m.text, style: const TextStyle(fontSize: 15, height: 1.4)),
        ),
        if (r != null && r.songs.isNotEmpty) _playlistCard(r),
        if (r != null && r.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(r.note!,
                style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        if (r != null && last && r.songs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _tweaks) _chip(t, () => _send(t)),
            ]),
          ),
      ],
    );
  }

  Widget _playlistCard(AssistantResult r) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RESPONDIDO CON ${r.source.toUpperCase()}',
                    style: const TextStyle(
                        fontSize: 11, letterSpacing: 1.4, color: AppColors.amber)),
                const SizedBox(height: 4),
                Text(r.title,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
                Text('${r.songs.length} canciones',
                    style: const TextStyle(
                        color: Color(0xFFD0D0D8), fontSize: 13)),
              ],
            ),
          ),
          for (final s in r.songs.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14.5)),
                        Text(s.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12.5)),
                      ]),
                ),
              ]),
            ),
          if (r.songs.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Text('y ${r.songs.length - 5} más…',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12.5)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => playSongs(context, r.songs, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Reproducir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: const StadiumBorder()),
                  onPressed: () => _save(r),
                  child: const Text('Guardar lista'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
            ),
          ),
          child: const Text(
            'Hola. Soy tu asistente de rock. Dime cómo estás o qué quieres '
            'escuchar y te armo una lista.',
            style: TextStyle(fontSize: 15, height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in _moods) _chip(m, () => _send(m)),
        ]),
        if (_noKeys) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.outline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sin claves de IA, el asistente funciona con reglas simples. '
                  'Agrega una clave gratuita para que entienda frases libres.',
                  style: TextStyle(color: AppColors.textDim, height: 1.4),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _openSettings,
                  child: const Text('Agregar clave'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const AiSettingsScreen()));
    final s = AiSettings.instance;
    if (mounted) {
      setState(() =>
          _noKeys = s.groqKey.trim().isEmpty && s.geminiKey.trim().isEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(children: [
                Expanded(
                  child: Text('ASISTENTE',
                      style: Theme.of(context).textTheme.displaySmall),
                ),
                IconButton(
                  tooltip: 'Tu gusto',
                  icon: const Icon(Icons.insights_rounded),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const TasteScreen())),
                ),
                IconButton(
                  tooltip: 'Claves del asistente',
                  icon: const Icon(Icons.key_rounded),
                  onPressed: _openSettings,
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (_msgs.isEmpty) _welcome(),
                  for (var i = 0; i < _msgs.length; i++)
                    _bubble(_msgs[i], i == _msgs.length - 1 && !_busy),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Pensando…',
                            style: TextStyle(color: AppColors.textDim)),
                      ]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                        hintText: 'Escríbele al asistente…'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.red,
                      minimumSize: const Size(48, 48)),
                  tooltip: 'Enviar',
                  onPressed: _busy ? null : () => _send(_input.text),
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
