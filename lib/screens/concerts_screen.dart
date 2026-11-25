import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/concert_service.dart';
import '../services/music_mode.dart';
import '../theme/app_theme.dart';

/// Cuadrito con mes y día.
class ConcertDateBox extends StatelessWidget {
  final DateTime? date;
  final double size;
  const ConcertDateBox({super.key, required this.date, this.size = 54});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 1.15,
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: date == null
          ? Center(
              child: Text('POR\nCONF.',
                  textAlign: TextAlign.center,
                  textScaler: TextScaler.linear(1.0),
                  style: TextStyle(
                      fontSize: AppType.micro,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: AppColors.redSoft)),
            )
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kMonthsShort[date!.month - 1].toUpperCase(),
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                  fontSize: AppType.caption,
                  fontWeight: FontWeight.w800,
                  color: AppColors.redSoft)),
          Text('${date!.day}',
              textScaler: const TextScaler.linear(1.0),
              style: TextStyle(
                  fontSize: AppType.title, fontFamily: AppType.head, fontVariations: [FontVariation('wght', 700)], fontWeight: FontWeight.w700, height: 1.1)),
        ],
      ),
    );
  }
}

String concertPlace(Concert c) =>
    [c.venue, c.city].where((e) => e.isNotEmpty).join(' · ');

Future<void> openConcertLink(BuildContext context, String url) async {
  final ok = url.isNotEmpty &&
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

/// Lista completa. Al tocar "Escuchar banda" se cierra devolviendo el
/// nombre de la banda para buscarla.
class ConcertsScreen extends StatefulWidget {
  const ConcertsScreen({super.key});

  @override
  State<ConcertsScreen> createState() => _ConcertsScreenState();
}

class _ConcertsScreenState extends State<ConcertsScreen> {
  static const List<String> _cities = [
    'Todas',
    'Bogotá',
    'Medellín',
    'Cali',
    'Bares',
    'Otras'
  ];
  static const List<String> _main = ['bogot', 'medell', 'cali'];
  String _city = 'Todas';

  /// Filtro por género (solo en el modo «Todos los géneros»).
  static const List<String> _genres = [
    'Todos',
    'Pop',
    'Salsa',
    'Urbano',
    'Vallenato',
    'Rock',
    'Electrónica',
    'Otros',
  ];
  static const Map<String, List<String>> _genreWords = {
    'Pop': ['pop', 'balad'],
    'Salsa': ['salsa', 'tropical', 'merengue', 'bachata'],
    'Urbano': ['urban', 'regue', 'trap', 'hip', 'rap'],
    'Vallenato': ['vallenat', 'regional', 'popular'],
    'Rock': ['rock', 'metal', 'punk', 'grunge', 'indie', 'alternativ'],
    'Electrónica': ['electr', 'house', 'techno', 'edm'],
  };
  String _genre = 'Todos';

  bool _inGenre(Concert c, String g) {
    final t = c.genre.toLowerCase();
    if (g == 'Otros') {
      return !_genreWords.values.any((w) => w.any(t.contains));
    }
    return (_genreWords[g] ?? const []).any(t.contains);
  }
  final ConcertService _svc = ConcertService.instance;

  bool _isMain(String city) {
    final c = city.toLowerCase();
    return _main.any(c.contains);
  }

  List<Concert> _filter(List<Concert> all) {
    if (MusicModeService.general && _genre != 'Todos') {
      all = all.where((c) => _inGenre(c, _genre)).toList();
    }
    if (_city == 'Todas') return all;
    if (_city == 'Bares') return all.where(_svc.isBar).toList();
    if (_city == 'Otras') return all.where((c) => !_isMain(c.city)).toList();
    final k = _city.toLowerCase().substring(0, 4);
    return all.where((c) => c.city.toLowerCase().contains(k)).toList();
  }

  Widget _card(Concert c) {
    final hasTickets = c.tickets.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ConcertDateBox(date: c.date),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.band,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  if (c.genre.isNotEmpty)
                    Text(c.genre.toUpperCase(),
                        style: TextStyle(
                            fontSize: AppType.caption,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amber)),
                  if (concertPlace(c).isNotEmpty)
                    Text(concertPlace(c),
                        style: TextStyle(
                            fontSize: AppType.bodySm,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDim)),
                  if (c.date == null)
                    Text('Fecha: ${c.when}',
                        style: TextStyle(
                            fontSize: AppType.label,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber))
                  else if (c.time.isNotEmpty)
                    Text(c.time,
                        style: const TextStyle(
                            fontSize: AppType.label, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: AppColors.redBtn),
                onPressed: () => openConcertLink(
                    context, hasTickets ? c.tickets : c.ticketSearchUrl),
                child: Text(hasTickets ? 'Boletas' : 'Buscar boletas'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(context).pop(_bandQuery(c.band)),
                child: Text(byMode('Escuchar banda', 'Escuchar artista')),
              ),
            ),
          ]),
          if (c.source.isNotEmpty && c.source != c.tickets) ...[
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  foregroundColor: AppColors.textFaint),
              onPressed: () => openConcertLink(context, c.source),
              child: Text('Fuente: ${Uri.tryParse(c.source)?.host ?? c.source}',
                  style: const TextStyle(fontSize: AppType.caption)),
            ),
          ],
        ],
      ),
    );
  }

  /// Para festivales "Festival X (Banda A, Banda B)" busca la primera banda.
  static String _bandQuery(String band) {
    final i = band.indexOf('(');
    if (i < 0) return band;
    final inside = band.substring(i + 1).replaceAll(')', '');
    final first = inside.split(',').first.trim();
    return first.isEmpty ? band.substring(0, i).trim() : first;
  }

  Future<void> _editBars() async {
    final ctrl = TextEditingController(text: _svc.bars.join('\n'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(byMode('Mis bares de rock', 'Mis bares con música en vivo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Uno por línea: nombre del bar y su @usuario de Instagram '
                '(o el enlace del perfil).\n'
                'Ejemplo: Kings Rock @kingsrockbar\n'
                'Con el @usuario y el token de Apify, la app lee sus flyers.',
                style: TextStyle(color: AppColors.textDim, fontSize: AppType.label)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              minLines: 4,
              maxLines: 10,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Nombre del bar @usuario'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar y buscar')),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (ok != true) return;
    await _svc.saveBars(text.split('\n'));
    if (mounted) setState(() => _city = 'Bares');
    _svc.refresh();
  }

  static String _group(Concert c) {
    final d = c.date;
    if (d == null) return 'FECHA POR CONFIRMAR';
    return '${kMonthsLong[d.month - 1]} ${d.year}'.toUpperCase();
  }

  Widget _genreChips() {
    if (!MusicModeService.general) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final g in _genres)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(g),
                selected: _genre == g,
                onSelected: (_) => setState(() => _genre = g),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final c in _cities)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c),
                selected: _city == c,
                showCheckmark: false,
                selectedColor: AppColors.redBtn,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.outline),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _city == c ? Colors.white : AppColors.textDim),
                onSelected: (_) => setState(() => _city = c),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Conciertos en Colombia',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Mis bares',
            onPressed: _editBars,
            icon: const Icon(Icons.local_bar_rounded),
          ),
          ValueListenableBuilder<ConcertState>(
            valueListenable: _svc.state,
            builder: (_, s, __) => IconButton(
              tooltip: 'Buscar de nuevo',
              onPressed: s.loading ? null : _svc.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<ConcertState>(
        valueListenable: _svc.state,
        builder: (context, s, _) {
          final list = _filter(s.items);
          final status = s.loading
              ? 'Buscando conciertos en internet…'
              : s.noKey
                  ? 'Falta una clave de Gemini o Groq (Ajustes → Activar la IA).'
                  : s.error ?? concertsUpdatedLabel(s.updatedAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(children: [
                  if (s.loading) ...[
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text('$status · próximos 12 meses',
                        style: TextStyle(
                            fontSize: AppType.caption,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textFaint)),
                  ),
                ]),
              ),
              _genreChips(),
              _chips(),
              const SizedBox(height: 10),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            s.loading
                                ? 'Esto puede tardar hasta un minuto.'
                                : _city == 'Bares'
                                    ? 'Todavía no hay toques en tus bares.\n\nPara leer sus flyers de Instagram, toca la copa de arriba y escribe el @usuario de cada bar.'
                                    : 'No hay conciertos encontrados${_city == 'Todas' ? '' : ' en esta ciudad'}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textDim),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i == 0 ||
                                _group(list[i]) != _group(list[i - 1]))
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(4, 8, 4, 10),
                                child: Text(_group(list[i]),
                                    style: TextStyle(
                                        fontSize: AppType.caption,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.amber)),
                              ),
                            _card(list[i]),
                          ],
                          ValueListenableBuilder<String>(
                            valueListenable: _svc.lastLog,
                            builder: (_, log, __) => log.isEmpty
                                ? const SizedBox.shrink()
                                : ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                        'Detalles de la última búsqueda',
                                        style: TextStyle(
                                            fontSize: AppType.label,
                                            color: AppColors.textDim)),
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: SelectableText(log,
                                            style: TextStyle(
                                                fontSize: AppType.caption,
                                                height: 1.5,
                                                color: AppColors.textFaint)),
                                      ),
                                    ],
                                  ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Datos buscados en internet con IA. Confirma la fecha en la fuente antes de comprar.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: AppType.caption, color: AppColors.textFaint),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
