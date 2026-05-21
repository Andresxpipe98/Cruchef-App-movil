import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CruchefColors {
  const CruchefColors._();

  static const Color page = Color(0xFF111111);
  static const Color pageEnd = Color(0xFF161616);
  static const Color surface = Color(0xCC1D1D1F);
  static const Color sidebar = Color(0xFF2A2A2D);
  static const Color subtleSurface = Color(0x14FFFFFF);
  static const Color border = Color(0x1FFFFFFF);
  static const Color strongBorder = Color(0x38FFFFFF);
  static const Color text = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFFA7A7A7);
  static const Color dim = Color(0xFF777777);
  static const Color red = Color(0xFFFF4B2F);
  static const Color redDark = Color(0xFFD83B27);
  static const Color redSoft = Color(0x2EFF4B2F);
  static const Color gold = Color(0xFFF5B942);
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
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      CruchefColors.page,
      Color(0xFF171717),
      CruchefColors.pageEnd,
    ],
    stops: <double>[0, 0.55, 1],
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
        height: 78,
        backgroundColor: const Color(0xF21D1D1F),
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
          elevation: 0,
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
          minimumSize: const Size(0, 48),
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
          end: Alignment.bottomLeft,
          colors: <Color>[
            Color(0x33FF4B2F),
            Color(0x18F5B942),
            Color(0x00111111),
          ],
          stops: <double>[0, 0.42, 1],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: CruchefColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: CruchefColors.border),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
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
