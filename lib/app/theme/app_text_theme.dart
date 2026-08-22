import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font pairing translated from the prototype: Georgia-style serif for
/// headings/brand (`Source Serif 4` is the closest open-license match to
/// Georgia's transitional proportions), platform default for body text, and
/// a tabular monospace for IDs/amounts (`.mono`/`.num`/`.id-cell` in the CSS).
class AppFonts {
  AppFonts._();

  static TextStyle serif({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.sourceSerif4(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

TextTheme buildAppTextTheme(TextTheme base, Color primaryText) {
  return base
      .copyWith(
        headlineSmall: AppFonts.serif(fontWeight: FontWeight.w700, color: primaryText),
        titleLarge: AppFonts.serif(fontWeight: FontWeight.w700, color: primaryText),
        titleMedium: AppFonts.serif(fontWeight: FontWeight.w600, color: primaryText),
      )
      .apply(bodyColor: primaryText, displayColor: primaryText);
}
