import 'package:flutter/material.dart';

import '../screens/concerts_screen.dart';
import '../services/concert_service.dart';
import '../services/music_mode.dart';
import '../theme/app_theme.dart';

/// Tarjeta de Inicio con los próximos conciertos. Al tocarla abre la lista
/// completa. [onListen] recibe la banda cuando eliges «Escuchar banda».
class ConcertsCard extends StatefulWidget {
  final ValueChanged<String> onListen;
  const ConcertsCard({super.key, required this.onListen});

  @override
  State<ConcertsCard> createState() => _ConcertsCardState();
}

class _ConcertsCardState extends State<ConcertsCard> {
  @override
  void initState() {
    super.initState();
    ConcertService.instance.ensureLoaded();
  }

  Future<void> _open() async {
    final band = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => const ConcertsScreen()));
    if (band != null && band.isNotEmpty && mounted) widget.onListen(band);
  }

  Widget _row(Concert c) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: Row(children: [
        ConcertDateBox(date: c.date, size: 46),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.band,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppType.body, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(concertPlace(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: AppType.label,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDim)),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConcertState>(
      valueListenable: ConcertService.instance.state,
      builder: (context, s, _) {
        final items = s.items.take(3).toList();
        String? msg;
        if (items.isEmpty) {
          if (s.loading) {
            msg = byMode('Buscando conciertos de rock en Colombia…', 'Buscando conciertos en Colombia…');
          } else if (s.noKey) {
            msg =
                'Para ver conciertos, pon tu clave gratis en Ajustes → Activar la IA.';
          } else if (s.error != null) {
            msg = s.error;
          } else {
            msg = 'No se encontraron conciertos en los próximos 12 meses.';
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              side: BorderSide(color: AppColors.borderAccent),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _open,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.lg, AppSpace.md, AppSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.confirmation_number_outlined,
                          color: AppColors.amber, size: 20),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text('PRÓXIMOS CONCIERTOS',
                            style: AppType.overline),
                      ),
                      if (s.loading)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textDim),
                    ]),
                    if (msg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.md),
                        child: Text(msg,
                            style: TextStyle(
                                fontSize: AppType.bodySm,
                                height: 1.35,
                                color: AppColors.textDim)),
                      )
                    else
                      for (final c in items) _row(c),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      items.isEmpty
                          ? 'Toca para ver todos y tus bares'
                          : 'Ver todos · ${concertsUpdatedLabel(s.updatedAt)}',
                      style: TextStyle(
                          fontSize: AppType.caption,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textFaint),
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
}
