import 'package:flutter/material.dart';

import '../services/radio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/playback_ui.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';

/// Logo de emisora con placeholder (inicial en ámbar) si falta o falla.
class StationLogo extends StatelessWidget {
  final RadioStation station;
  final double size;
  final double radius;
  const StationLogo(
      {super.key, required this.station, this.size = 48, this.radius = 10});

  Widget _placeholder() {
    final c = station.name.trim().isEmpty
        ? '♪'
        : String.fromCharCode(station.name.trim().runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A34), Color(0xFF14141A)],
        ),
      ),
      child: Text(c,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: AppColors.amber)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (station.favicon.isEmpty) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        station.favicon,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (c, child, p) => p == null ? child : _placeholder(),
      ),
    );
  }
}

/// ¿Está sonando esta emisora ahora?
bool stationIsCurrent(RadioStation s) =>
    PlaybackUi.instance.song.value?.query == 'radio:${s.id}';

void playStation(BuildContext context, RadioStation s) =>
    playSongs(context, [s.toSong()], 0);

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final RadioService _svc = RadioService.instance;
  final TextEditingController _q = TextEditingController();
  List<RadioStation> _saved = [];
  List<RadioStation> _results = [];
  bool _colombia = true;
  bool _loading = true;
  bool _offline = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _svc.revision.addListener(_loadSaved);
    _loadSaved();
    _search();
  }

  @override
  void dispose() {
    _svc.revision.removeListener(_loadSaved);
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final s = await _svc.saved();
    if (mounted) setState(() => _saved = s);
  }

  Future<void> _search() async {
    final query = _q.text.trim();
    setState(() {
      _loading = true;
      _offline = false;
      _lastQuery = query;
    });
    try {
      final r = await _svc.search(query, colombiaOnly: _colombia);
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
        _offline = true;
      });
    }
  }

  Future<void> _toggleSave(RadioStation s, bool saved) async {
    if (saved) {
      await _svc.remove(s.id);
    } else {
      await _svc.save(s);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        content: Text(saved ? 'Quitada de tus emisoras' : 'Guardada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => saved ? _svc.save(s) : _svc.remove(s.id),
        ),
      ));
  }

  Future<void> _addByLink() async {
    final r = await showModalBottomSheet<RadioStation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddSheet(),
    );
    if (r != null) {
      await _svc.save(r);
      if (mounted) playStation(context, r);
    }
  }

  Widget _tile(RadioStation s) {
    final saved = _saved.any((x) => x.id == s.id);
    return ListenableBuilder(
      listenable: Listenable.merge(
          [PlaybackUi.instance.song, PlaybackUi.instance.playing]),
      builder: (context, _) {
        final current = stationIsCurrent(s);
        final playing = current && PlaybackUi.instance.playing.value;
        final failed = current &&
            (PlaybackUi.instance.error.value ?? '').contains('emisora');
        return Semantics(
          label: '${s.name}, ${s.subtitle}. Toca para reproducir',
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
              color: current ? AppColors.surfaceHigh : AppColors.surface,
              border: Border.all(
                  color: current || failed ? AppColors.red : AppColors.outline,
                  width: current ? 1.5 : 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => playStation(context, s),
              child: SizedBox(
                height: 72,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        StationLogo(station: s),
                        if (playing)
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(0, 0, 0, 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.graphic_eq_rounded,
                                color: AppColors.amber),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: current
                                      ? AppColors.red
                                      : AppColors.text)),
                          const SizedBox(height: 2),
                          Text(
                              failed
                                  ? 'No se pudo reproducir · toca para reintentar'
                                  : (current ? 'EN VIVO' : s.subtitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: failed
                                      ? AppColors.amber
                                      : AppColors.textDim)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: saved
                          ? 'Quitar de mis emisoras'
                          : 'Guardar en mis emisoras',
                      icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: saved ? AppColors.amber : AppColors.textDim),
                      onPressed: () => _toggleSave(s, saved),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.textDim)),
      );

  @override
  Widget build(BuildContext context) {
    final savedIds = {for (final s in _saved) s.id};
    final shown = [for (final s in _results) if (!savedIds.contains(s.id)) s];
    return Scaffold(
      appBar: AppBar(title: const Text('Radio')),
      bottomNavigationBar: const MiniPlayer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.redBtn,
        foregroundColor: Colors.white,
        onPressed: _addByLink,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Agregar por enlace'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const PageHeader(
              title: 'Radio en vivo',
              subtitle: 'Emisoras de internet, sin pausa'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Buscar emisora (ej. Radioacktiva)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _q.clear();
                          _search();
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Colombia')),
                ButtonSegment(value: false, label: Text('Todo el mundo')),
              ],
              selected: {_colombia},
              onSelectionChanged: (v) {
                setState(() => _colombia = v.first);
                _search();
              },
            ),
          ),
          if (_saved.isNotEmpty) ...[
            _label('MIS EMISORAS'),
            for (final s in _saved) _tile(s),
          ],
          _label(_lastQuery.isEmpty
              ? (_colombia ? 'POPULARES EN COLOMBIA' : 'ROCK EN EL MUNDO')
              : 'RESULTADOS'),
          if (_loading)
            for (var i = 0; i < 5; i++)
              Container(
                height: 72,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16)),
              )
          else if (_offline)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 40, color: AppColors.textFaint),
                const SizedBox(height: 10),
                const Text('Sin conexión con el directorio',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Tus emisoras guardadas siguen funcionando.',
                    style: TextStyle(color: AppColors.textDim)),
                TextButton(onPressed: _search, child: const Text('Reintentar')),
              ]),
            )
          else if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Icon(Icons.search_off_rounded,
                    size: 40, color: AppColors.textFaint),
                const SizedBox(height: 10),
                Text(
                    _lastQuery.isEmpty
                        ? 'No hay emisoras para mostrar'
                        : 'Sin resultados para «$_lastQuery»',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Prueba otro nombre o cambia a Todo el mundo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim)),
              ]),
            )
          else
            for (final s in shown) _tile(s),
        ],
      ),
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String? get _nameErr {
    if (_name.text.isEmpty) return null;
    if (_name.text.trim().length > 40) return 'Máximo 40 letras';
    return null;
  }

  String? get _urlErr {
    final u = _url.text.trim();
    if (u.isEmpty) return null;
    if (!(u.startsWith('http://') || u.startsWith('https://'))) {
      return 'Debe empezar con http:// o https://';
    }
    return null;
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _name.text.trim().length <= 40 &&
      _url.text.trim().isNotEmpty &&
      _urlErr == null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agregar emisora',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: 'Nombre', errorText: _nameErr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                labelText: 'Enlace de la transmisión',
                hintText: 'https://…',
                errorText: _urlErr),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 14),
            child: Text(
                'Pega el enlace directo del audio (suele estar en la web de la emisora).',
                style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(context,
                      RadioService.instance.custom(_name.text, _url.text))
                  : null,
              child: const Text('Guardar y escuchar'),
            ),
          ),
        ],
      ),
    );
  }
}
