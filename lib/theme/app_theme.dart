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
  /// Texto de cuerpo un poco más suave que [text].
  static const Color textBody = Color(0xFFD0D0D8);
  static const Color textDim = Color(0xFFA6A6B2);
  /// Texto terciario. Sigue pasando AA (≈4,6:1 sobre [bg]).
  static const Color textFaint = Color(0xFF7A7A88);
  /// Rojo para texto e iconos sobre superficies oscuras (≈6:1, AA).
  static const Color redText = Color(0xFFFF5A52);
  static const Color redSoft = Color(0xFFF08A7E);
  static const Color surfaceWarm = Color(0xFF1A1014);
  static const Color borderAccent = Color(0x33FFB02E);
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color scrim = Color(0x66000000);
  static const Color amberTint = Color(0x1AFFB02E);
  static const Color amberLine = Color(0x59FFB02E);
  /// Línea roja sobre la barra de navegación.
  static const Color navLine = Color(0x66E5332E);

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE5332E), Color(0xFFB3201B)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB3201B), Color(0xFF5A0F0D), Color(0xFF1A1014)],
    stops: [0, 0.55, 1],
  );

  /// Velo inferior para que el texto se lea sobre degradados de color.
  static const LinearGradient bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0x40000000)],
  );
}

/// Única paleta de tarjetas (mixes, géneros, ánimos): rojo, ámbar y grafito.
class AppPalettes {
  AppPalettes._();
  static const List<Color> fire = [Color(0xFFC2331A), Color(0xFF2C0A05)];
  static const List<Color> graphite = [Color(0xFF4A4A56), Color(0xFF16161C)];
  static const List<Color> wine = [Color(0xFF7A1411), Color(0xFF1A1014)];
  static const List<Color> amber = [Color(0xFF8A5A2A), Color(0xFF241608)];
  static const List<Color> rust = [Color(0xFF8A2A24), Color(0xFF2A0D0B)];
  static const List<Color> steel = [Color(0xFF5A5A66), Color(0xFF1C1C22)];
  static const List<Color> burgundy = [Color(0xFF6B2A3A), Color(0xFF220A12)];
  static const List<Color> brass = [Color(0xFF7A6A2A), Color(0xFF241E08)];

  static const List<List<Color>> cards = [
    fire, graphite, wine, amber, rust, steel, burgundy, brass,
  ];
}

/// Escala tipográfica: Oswald en títulos, Roboto en cuerpo.
class AppType {
  AppType._();
  static const double display = 32;
  static const double headline = 26;
  static const double title = 22;
  static const double titleSm = 18;
  static const double body = 15;
  static const double bodySm = 14;
  static const double label = 13;
  static const double caption = 12;
  static const double micro = 11;

  /// Título grande de marca (Oswald).
  static TextStyle oswald(double size,
          {Color color = AppColors.text, double height = 1.05}) =>
      TextStyle(
        fontFamily: 'Oswald',
        fontSize: size,
        height: height,
        color: color,
        fontWeight: FontWeight.w700,
        fontVariations: const [FontVariation('wght', 700)],
        letterSpacing: 0.5,
      );

  /// Etiqueta en mayúsculas espaciadas (ej. TU MIX).
  static const TextStyle overline = TextStyle(
    fontSize: caption,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w800,
    color: AppColors.amber,
  );
}

class AppSpace {
  AppSpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 20, xxl = 24, xxxl = 32;
}

class AppRadius {
  AppRadius._();
  /// Carátula en lista = sm, tarjetas = lg, hero y banners = xl.
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
}

class AppShadow {
  AppShadow._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x73E5332E), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 500);

  /// true si el sistema pidió reducir animaciones.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
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
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700)],
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
      materialTapTargetSize: MaterialTapTargetSize.padded,
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
        height: 68,
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
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerColor: AppColors.outline,
    );
  }
}
