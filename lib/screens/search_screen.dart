import 'package:flutter/material.dart';
import '../widgets/tip_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../services/music_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/music_card.dart';
import '../widgets/player_route.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import '../services/concert_service.dart';
import 'concerts_screen.dart';

class SearchScreen extends StatefulWidget {
  final String title;
  final String hint;
  final String intro;
  final String querySuffix;

  const SearchScreen({
    super.key,
    this.title = 'Buscar',
    this.hint = 'Artista o canción',
    this.intro = 'Encuentra artistas, álbumes y canciones de rock',
    this.querySuffix = '',
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const List<String> _suggestions = [
    'Rock clásico',
    'Hard rock',
    'Heavy metal',
    'Grunge',
    'Punk rock',
    'Rock alternativo',
    'Indie rock',
    'Rock en español',
  ];

  final TextEditingController _controller = TextEditingController();
  final MusicApiService _api = MusicApiService();
  List<Song> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;
  int _searchId = 0;
  bool _more = false;
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    ConcertService.instance.ensureLoaded();
  }

  String get _histKey => 'search_hist_${widget.title}';

  Future<void> _loadHistory() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final l = sp.getStringList(_histKey) ?? [];
      if (mounted) setState(() => _history = l);
    } catch (_) {}
  }

  Future<void> _saveHistory(String q) async {
    final l = [q, ..._history.where((e) => e.toLowerCase() != q.toLowerCase())]
        .take(10)
        .toList();
    _history = l;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_histKey, l);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_histKey);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    _saveHistory(q);
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
    });
    final id = ++_searchId;
    _results = [];
    _more = true;
    try {
      var first = true;
      await for (final r
          in _api.searchStream('$q${widget.querySuffix}', max: 300)) {
        if (!mounted || id != _searchId) return;
        setState(() {
          _results = r;
          if (first) _loading = false;
          first = false;
        });
      }
      if (!mounted || id != _searchId) return;
      setState(() {
        _loading = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _loading = false;
        _more = false;
        if (_results.isEmpty) {
          _error =
              'No se pudo buscar. Revisa tu conexión e inténtalo de nuevo.';
        }
      });
    }
  }

  void _useSuggestion(String q) {
    _controller.text = q;
    _search();
  }

  static const List<List<Object>> _tiles = [
    ['Grunge', Color(0xFFC2331A), Color(0xFF2C0A05)],
    ['Rock en español', Color(0xFF4A4A56), Color(0xFF16161C)],
    ['Heavy metal', Color(0xFF7A1411), Color(0xFF1A1014)],
    ['Rock clásico', Color(0xFF8A5A2A), Color(0xFF241608)],
    ['Hard rock', Color(0xFF8A2A24), Color(0xFF2A0D0B)],
    ['Punk rock', Color(0xFF5A5A66), Color(0xFF1C1C22)],
    ['Rock alternativo', Color(0xFF6B2A3A), Color(0xFF220A12)],
    ['Indie rock', Color(0xFF7A6A2A), Color(0xFF241E08)],
  ];

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppColors.amber)),
      );

  Widget _genreTile(List<Object> t) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t[1] as Color, t[2] as Color],
          ),
        ),
        child: InkWell(
          onTap: () => _useSuggestion(t[0] as String),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(14),
            child: Text(t[0] as String,
                textAlign: TextAlign.center,
                textScaler: const TextScaler.linear(1.0),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, height: 1.1)),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _label('RECIENTES')),
              TextButton(
                  onPressed: _clearHistory, child: const Text('Borrar')),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _history)
                Material(
                  color: AppColors.surfaceHigh,
                  shape: const StadiumBorder(
                      side: BorderSide(color: AppColors.outline)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => _useSuggestion(h),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(h,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _label('EXPLORAR POR GÉNERO'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [for (final t in _tiles) _genreTile(t)],
        ),
        const SizedBox(height: 22),
        _concerts(),
      ],
    );
  }

  Future<void> _openConcerts() async {
    final band = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => const ConcertsScreen()));
    if (band != null && band.isNotEmpty && mounted) _useSuggestion(band);
  }

  Widget _concertTile(Concert c) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: _openConcerts,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ConcertDateBox(date: c.date, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.band,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(concertPlace(c),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDim)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _concerts() {
    return ValueListenableBuilder<ConcertState>(
      valueListenable: ConcertService.instance.state,
      builder: (context, s, _) {
        final items = s.items.take(5).toList();
        String? msg;
        if (items.isEmpty) {
          if (s.loading) {
            msg = 'Buscando conciertos de rock en Colombia…';
          } else if (s.noKey) {
            msg = 'Agrega tu clave de Gemini o Groq en Ajustes del asistente para ver los próximos conciertos.';
          } else if (s.error != null) {
            msg = s.error;
          } else {
            msg = 'No se encontraron conciertos en los próximos 12 meses.';
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _label('PRÓXIMOS CONCIERTOS')),
              TextButton(
                  onPressed: _openConcerts, child: const Text('Ver todos')),
            ]),
            if (msg != null)
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.outline),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onTap: s.loading ? null : ConcertService.instance.refresh,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      s.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.confirmation_number_outlined,
                              color: AppColors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(msg,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDim)),
                      ),
                    ]),
                  ),
                ),
              )
            else
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _concertTile(items[i]),
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                s.loading && items.isNotEmpty
                    ? 'Actualizando…'
                    : '${concertsUpdatedLabel(s.updatedAt)} · búsqueda en internet con IA',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textFaint),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body() {
    if (_loading) return const SkeletonList();
    if (_error != null) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Sin conexión',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _search,
        isError: true,
      );
    }
    if (!_searched) return _intro();
    if (_results.isEmpty) {
      return const StateMessage(
        icon: Icons.search_off_rounded,
        title: 'Sin resultados',
        message: 'Prueba con otro nombre o revisa la ortografía.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _more
                      ? '${_results.length} canciones · cargando más…'
                      : '${_results.length} canciones',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: () {
                        final list = List<Song>.of(_results)..shuffle();
                        playSongs(context, list, 0);
                      },
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Aleatorio'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48)),
                      onPressed: () => playSongs(context, _results, 0),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Reproducir'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        }
        final idx = i - 1;
        final song = _results[idx];
        return FadeIn(
          order: idx,
          child: MusicCard(
            song: song,
            onTap: () => playSongs(context, _results, idx),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(title: widget.title),
            AppSearchField(
              controller: _controller,
              hint: widget.hint,
              onSubmit: _search,
            ),
            const TipCard(
                id: 'buscar',
                text:
                    'Escribe un artista o una canción. Con los tres puntos de cada canción la guardas en una lista o la agregas a la cola.'),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey<String>(
                      '$_loading-$_searched-${_error != null}-$_searchId-${_results.isEmpty}'),
                  child: _body(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
