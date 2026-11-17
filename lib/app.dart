import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/embed_overlay.dart';

class RockPlayApp extends StatelessWidget {
  const RockPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RockPlay IA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) =>
          EmbedOverlay(child: child ?? const SizedBox.shrink()),
      home: const HomeScreen(),
    );
  }
}
