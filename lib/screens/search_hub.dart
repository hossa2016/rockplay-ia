import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dj_screen.dart';
import 'search_screen.dart';

/// Pestaña Buscar: canciones o emisora de un artista.
class SearchHub extends StatefulWidget {
  const SearchHub({super.key});

  @override
  State<SearchHub> createState() => _SearchHubState();
}

class _SearchHubState extends State<SearchHub> {
  int _mode = 0;

  Widget _seg(String label, int i) {
    final on = _mode == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = i),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: on ? Colors.white : AppColors.textDim)),
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
