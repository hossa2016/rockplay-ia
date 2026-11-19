import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dj_screen.dart';
import 'search_screen.dart';

/// Pide abrir un modo de Buscar desde fuera (0 canciones, 1 emisora).
final ValueNotifier<int> searchHubWantMode = ValueNotifier<int>(-1);

/// Pestaña Buscar: canciones o emisora de un artista.
class SearchHub extends StatefulWidget {
  const SearchHub({super.key});

  @override
  State<SearchHub> createState() => _SearchHubState();
}

class _SearchHubState extends State<SearchHub> {
  int _mode = 0;

  @override
  void initState() {
    super.initState();
    searchHubWantMode.addListener(_wantMode);
  }

  void _wantMode() {
    final m = searchHubWantMode.value;
    if (m < 0) return;
    searchHubWantMode.value = -1;
    if (mounted) setState(() => _mode = m);
  }

  @override
  void dispose() {
    searchHubWantMode.removeListener(_wantMode);
    super.dispose();
  }

  Widget _seg(String label, int i) {
    final on = _mode == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = i),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.redBtn : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : AppColors.textDim)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(children: [
                _seg('Canciones', 0),
                _seg('Emisora de artista', 1),
              ]),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: const [SearchScreen(), DjScreen()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
