import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CruchefColors {
  const CruchefColors._();

  static const Color page = Color(0xFF121212);
  static const Color pageEnd = Color(0xFF171717);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color sidebar = Color(0xFF2A2A2D);
  static const Color subtleSurface = Color(0x0AFFFFFF);
  static const Color border = Color(0x14FFFFFF);
  static const Color strongBorder = Color(0x1FFFFFFF);
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFBDBDBD);
  static const Color dim = Color(0xFF828282);
  static const Color red = Color(0xFFE65151);
  static const Color redDark = Color(0xFFB73D3D);
  static const Color redSoft = Color(0x1FE65151);
  static const Color gold = Color(0xFFFFD166);
  static const Color green = Color(0xFFA7EFC1);
  static const Color greenSoft = Color(0x1F52C483);
  static const Color error = Color(0xFFFFB0B0);
}

class CruchefRadii {
  const CruchefRadii._();

  static const double field = 16;
  static const double card = 24;
  static const double authCard = 28;
  static const double pill = 999;
}

class CruchefSpacing {
  const CruchefSpacing._();

  static const double pageMobile = 20;
  static const double pageTablet = 24;
  static const double pageDesktop = 38;
  static const double section = 32;
}

class CruchefDesign {
  const CruchefDesign._();

  static LinearGradient get pageGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[CruchefColors.page, CruchefColors.pageEnd],
  );

  static LinearGradient get redGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[CruchefColors.red, CruchefColors.redDark],
  );

  static LinearGradient get surfaceGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0x0AFFFFFF), Color(0x00FFFFFF)],
    stops: <double>[0, 0.35],
  );

  static ThemeData get theme {
    final TextTheme textTheme = GoogleFonts.interTextTheme(
      Typography.whiteMountainView,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CruchefColors.page,
      colorScheme: const ColorScheme.dark(
        primary: CruchefColors.red,
        secondary: CruchefColors.gold,
        surface: CruchefColors.surface,
        error: CruchefColors.error,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: CruchefColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CruchefRadii.card),
          side: const BorderSide(color: CruchefColors.border),
        ),
      ),
      dividerColor: CruchefColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CruchefColors.subtleSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: CruchefColors.dim),
        labelStyle: const TextStyle(
          color: Color(0xFFECECEC),
          fontWeight: FontWeight.w600,
        ),
        border: _fieldBorder(CruchefColors.strongBorder),
        enabledBorder: _fieldBorder(CruchefColors.strongBorder),
        focusedBorder: _fieldBorder(CruchefColors.red),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: CruchefColors.subtleSurface,
        selectedColor: CruchefColors.red,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: CruchefColors.surface,
        indicatorColor: CruchefColors.redSoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? CruchefColors.text
                : CruchefColors.muted,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CruchefColors.red,
          foregroundColor: CruchefColors.text,
          disabledBackgroundColor: CruchefColors.red.withValues(alpha: 0.45),
          disabledForegroundColor: CruchefColors.text.withValues(alpha: 0.72),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CruchefRadii.field),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CruchefColors.text,
          side: const BorderSide(color: CruchefColors.strongBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CruchefRadii.field),
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(CruchefRadii.field),
      borderSide: BorderSide(color: color),
    );
  }
}

class CruchefPageBackground extends StatelessWidget {
  const CruchefPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x1FE65151), Color(0x00121212)],
          stops: <double>[0, 0.24],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: CruchefDesign.pageGradient),
        child: child,
      ),
    );
  }
}

class CruchefSurface extends StatelessWidget {
  const CruchefSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = CruchefRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CruchefColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CruchefColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 38,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EyebrowText extends StatelessWidget {
  const EyebrowText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: CruchefColors.dim,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 8),
                DefaultTextStyle(
                  style: const TextStyle(
                    color: CruchefColors.muted,
                    height: 1.5,
                  ),
                  child: subtitle!,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}
