import 'package:flutter/material.dart';
import '../services/block_service.dart';

import '../services/data_saver.dart';
import '../theme/app_theme.dart';

/// Ajustes de datos y caché.
class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  final DataSaver _ds = DataSaver.instance;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _ds.load();
    final b = await _ds.sizeBytes();
    if (mounted) setState(() => _bytes = b);
  }

  Future<void> _apply() async {
    await _ds.save();
    await _ds.prune();
    await _refresh();
  }

  String _size(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _option(CacheMode m, String title, String sub) {
    final on = _ds.mode == m;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: on ? AppColors.red : AppColors.outline),
      ),
      child: InkWell(
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        onTap: () {
          setState(() => _ds.mode = m);
          _apply();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_off,
                color: on ? AppColors.redText : AppColors.textDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: AppType.body)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          color: AppColors.textDim, fontSize: AppType.caption)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Almacenamiento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('En uso: ${_size(_bytes)}',
                      maxLines: 1,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: AppType.body)),
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  await _ds.clear();
                  await _refresh();
                },
                child: const Text('Borrar caché'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(_ds.debugInfo(),
                style: TextStyle(
                    color: AppColors.textFaint, fontSize: AppType.caption)),
          ),
          const SizedBox(height: 14),
          Text(
            'El caché guarda portadas y datos de artistas en tu teléfono para no '
            'bajarlos otra vez. No guarda música.',
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 16),
          _option(CacheMode.unlimited, 'Sin límite',
              'Guarda todo lo que se baje.'),
          const SizedBox(height: 10),
          _option(CacheMode.limit, 'Hasta una cantidad de espacio',
              'Cuando se llena, borra lo más viejo.'),
          if (_ds.mode == CacheMode.limit)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mb in DataSaver.limitsMb)
                    ChoiceChip(
                      label: Text(mb >= 1000 ? '1 GB' : '$mb MB'),
                      selected: _ds.limitMb == mb,
                      onSelected: (_) {
                        setState(() => _ds.limitMb = mb);
                        _apply();
                      },
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _option(CacheMode.favorites, 'Solo favoritas y más escuchadas',
              'Guarda solo las portadas de tus favoritos y de tus 100 más oídas.'),
          const SizedBox(height: 10),
          _option(CacheMode.off, 'No guardar nada',
              'Siempre baja todo de nuevo. Gasta más datos.'),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Con datos móviles, no bajar portadas nuevas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Las que ya están guardadas sí se ven. Las nuevas esperan al WiFi.',
                style: TextStyle(color: AppColors.textDim)),
            value: _ds.noMobileImages,
            onChanged: (v) {
              setState(() => _ds.noMobileImages = v);
              _apply();
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Registro de canciones saltadas'),
            subtitle: Text('Motivo técnico de las últimas canciones que no sonaron.',
                style: TextStyle(color: AppColors.textDim, fontSize: AppType.caption)),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Canciones saltadas'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SkipLog.entries.isEmpty
                      ? const Text('Todavía no se ha saltado ninguna.')
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final e in SkipLog.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(e, style: const TextStyle(fontSize: AppType.caption)),
                              ),
                          ],
                        ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cerrar')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
