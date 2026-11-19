import 'package:flutter/material.dart';

/// Paleta RockPlay: negro profundo con acento rojo y ámbar.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF0A0A0D);
  static const Color surface = Color(0xFF14141A);
  static const Color surfaceHigh = Color(0xFF1E1E26);
  static const Color outline = Color(0xFF2B2B35);
  static const Color red = Color(0xFFE5332E);
  /// Rojo para botones con texto blanco (contraste ≥ 4,5:1).
  static const Color redBtn = Color(0xFFC92B26);
  static const Color redDeep = Color(0xFF7A1411);
  static const Color amber = Color(0xFFFFB02E);
  static const Color text = Color(0xFFF4F4F6);
  static const Color textDim = Color(0xFFA6A6B2);
  static const Color textFaint = Color(0xFF8E8E9C);

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5332E), Color(0xFFFF8A1F)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB3201B), Color(0xFF5A0F0D), Color(0xFF1A1014)],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.red,
      onPrimary: Colors.white,
      secondary: AppColors.amber,
      onSecondary: Colors.black,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: Color(0xFFFF6B5E),
      outline: AppColors.outline,
    );

    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true)
        .textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text);

    TextStyle? osw(TextStyle? t, double ls) => t?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: ls,
        );

    final textTheme = base.copyWith(
      displaySmall: osw(base.displaySmall, 0.5),
      headlineMedium: osw(base.headlineMedium, 0.5),
      headlineSmall: osw(base.headlineSmall, 0.3),
      titleLarge: osw(base.titleLarge, 1.2),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: const Color.fromRGBO(255, 176, 46, 0.20),
        indicatorShape: const StadiumBorder(),
        height: 66,
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: const TextStyle(color: AppColors.textFaint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.red, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.redBtn,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        side: const BorderSide(color: AppColors.outline),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: Colors.white,
        inactiveTrackColor: Color.fromRGBO(255, 255, 255, 0.18),
        thumbColor: Colors.white,
        overlayColor: Color.fromRGBO(255, 255, 255, 0.12),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.red,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: AppColors.outline,
    );
  }
}
