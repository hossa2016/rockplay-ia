import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/ai_client.dart';
import '../services/ai_settings.dart';
import '../services/assistant_service.dart';
import '../services/deezer_service.dart';
import '../widgets/cover_art.dart';
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
    _loadCovers(r);
  }

  /// Busca las portadas reales de las primeras canciones de la lista.
  Future<void> _loadCovers(AssistantResult r) async {
    final dz = DeezerService();
    for (var i = 0; i < r.songs.length && i < 8; i++) {
      final s = r.songs[i];
      if (s.image.isNotEmpty) continue;
      try {
        final c = await dz.coverFor('${s.artist} ${s.title}');
        if (c.isEmpty) continue;
        r.songs[i] = Song(
          title: s.title,
          artist: s.artist,
          album: s.album,
          image: c,
          url: s.url,
          videoId: s.videoId,
          query: s.query,
        );
        if (mounted) setState(() {});
      } catch (_) {}
    }
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
        SnackBar(
            duration: const Duration(seconds: 3),
            content: Text('Guardada como "${p.name}" en Mi música.')));
  }

  Widget _chip(String label, VoidCallback onTap) => Material(
        color: AppColors.surfaceHigh,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: _busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _avatar(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: AppColors.accent),
        child: Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: size * 0.5),
      );

  Widget _bubble(_Msg m, bool last) {
    final r = m.result;
    final user = m.fromUser;
    final box = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: user
            ? const LinearGradient(
                colors: [Color(0xFFD42B27), Color(0xFFB3201B)])
            : null,
        color: user ? null : AppColors.surface,
        border: user ? null : Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(user ? 20 : 6),
          bottomRight: Radius.circular(user ? 6 : 20),
        ),
      ),
      child: Text(m.text, style: const TextStyle(fontSize: 14.5, height: 1.45)),
    );
    if (user) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Align(alignment: Alignment.centerRight, child: box),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(alignment: Alignment.centerLeft, child: box),
                if (r != null && r.songs.isNotEmpty) _playlistCard(r),
                if (r != null && r.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(r.note!,
                        style: const TextStyle(
                            color: AppColors.textFaint, fontSize: 12)),
                  ),
                if (r != null && last && r.songs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final t in _tweaks)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _chip(t, () => _send(t)),
                          ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<List<Color>> _grads = [
    [Color(0xFF3A4A8A), Color(0xFF0D1030)],
    [Color(0xFF2A6F8A), Color(0xFF08202A)],
    [Color(0xFF8A5A2A), Color(0xFF241608)],
    [Color(0xFFC2331A), Color(0xFF2C0A05)],
    [Color(0xFF7A1411), Color(0xFF1A1014)],
  ];

  BoxDecoration _grad(int i) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _grads[i % _grads.length],
        ),
      );

  Widget _mosaic(double size, List<Song> songs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Column(children: [
          for (var r = 0; r < 2; r++)
            Expanded(
              child: Row(children: [
                for (var c = 0; c < 2; c++)
                  Expanded(
                    child: Container(
                        margin: EdgeInsets.only(
                            right: c == 0 ? 1 : 0, bottom: r == 0 ? 1 : 0),
                        decoration: _grad(r * 2 + c),
                        child: (r * 2 + c) < songs.length &&
                                songs[r * 2 + c].image.isNotEmpty
                            ? CoverArt(url: songs[r * 2 + c].image, radius: 0)
                            : null),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _playlistCard(AssistantResult r) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _mosaic(68, r.songs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('${r.songs.length} canciones',
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      border: Border.all(color: AppColors.outline),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(r.source,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber)),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (var i = 0; i < r.songs.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CoverArt(url: r.songs[i].image, radius: 9),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.songs[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(r.songs[i].artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                      ]),
                ),
              ]),
            ),
          if (r.songs.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text('y ${r.songs.length - 3} más',
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 12.5)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.bg,
                    minimumSize: const Size(0, 46),
                    shape: const StadiumBorder()),
                onPressed: () => playSongs(context, r.songs, 0),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Reproducir'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Guardar lista',
              style: IconButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3A3A46)),
                  minimumSize: const Size(46, 46)),
              onPressed: () => _save(r),
              icon: const Icon(Icons.bookmark_border_rounded),
            ),
          ]),
        ],
      ),
    );
  }

  static const List<List<Object>> _moodTiles = [
    ['Con energía', Color(0xFFC2331A), Color(0xFF2C0A05)],
    ['Melancólico', Color(0xFF3A4A8A), Color(0xFF0D1030)],
    ['Para concentrarme', Color(0xFF2A6F8A), Color(0xFF08202A)],
    ['De carretera', Color(0xFFB8420F), Color(0xFF2A1005)],
    ['Quiero algo nuevo', Color(0xFF8A5A2A), Color(0xFF241608)],
  ];

  Widget _moodTile(List<Object> t) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t[1] as Color, t[2] as Color],
          ),
        ),
        child: InkWell(
          onTap: _busy ? null : () => _send(t[0] as String),
          child: Container(
            height: 84,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(14),
            child: Text(t[0] as String,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _welcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x38FFB02E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿QUÉ SUENA HOY?',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber)),
              const SizedBox(height: 6),
              const Text('Cuéntame cómo estás\ny armo tu lista',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 14),
              Text('Escribe abajo, por ejemplo: rock para estudiar de noche.',
                  style: TextStyle(
                      color: const Color(0xBFFFFFFF),
                      fontSize: 13.5,
                      height: 1.4)),
            ],
          ),
        ),
        if (_noKeys) ...[
          const SizedBox(height: 14),
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.outline),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              onTap: _openSettings,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.key_rounded,
                        color: AppColors.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activa la IA gratis',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Sin clave funciona con reglas simples',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textDim),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('ELIGE UN ÁNIMO',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.amber)),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
          children: [for (final t in _moodTiles) _moodTile(t)],
        ),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(children: [
                _avatar(44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ASISTENTE',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 22)),
                      const Text('Tu guía de rock',
                          style: TextStyle(
                              color: AppColors.textDim, fontSize: 12.5)),
                    ],
                  ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        _avatar(32),
                        const SizedBox(width: 10),
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.amber)),
                        const SizedBox(width: 10),
                        const Text('Armando tu lista…',
                            style: TextStyle(color: AppColors.textDim)),
                      ]),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: 'Escribe lo que quieras escuchar',
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.red),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, gradient: AppColors.accent),
                    child: InkWell(
                      onTap: _busy ? null : () => _send(_input.text),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
