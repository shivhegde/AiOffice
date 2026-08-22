import 'package:flutter/material.dart';

/// Design tokens carried over from `docs/prototype.html`'s CSS custom
/// properties that have no direct Material 3 [ColorScheme] role (status
/// colors, ink scale, chart tokens). See [AppTheme] for how these combine
/// with [ColorScheme] into the app's light/dark [ThemeData].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.ink900,
    required this.ink800,
    required this.ink700,
    required this.accentDark,
    required this.accentSoft,
    required this.onAccent,
    required this.textMuted,
    required this.good,
    required this.warning,
    required this.serious,
    required this.chartSurface,
    required this.chartGrid,
    required this.chartAxis,
    required this.chartText2,
    required this.seriesIn,
    required this.seriesOut,
  });

  final Color ink900;
  final Color ink800;
  final Color ink700;
  final Color accentDark;
  final Color accentSoft;
  final Color onAccent;
  final Color textMuted;
  final Color good;
  final Color warning;
  final Color serious;
  final Color chartSurface;
  final Color chartGrid;
  final Color chartAxis;
  final Color chartText2;
  final Color seriesIn;
  final Color seriesOut;

  static const light = AppColors(
    ink900: Color(0xFF1B2A44),
    ink800: Color(0xFF223655),
    ink700: Color(0xFF2C4468),
    accentDark: Color(0xFF96611A),
    accentSoft: Color(0xFFF3E4C8),
    onAccent: Color(0xFF1B1200),
    textMuted: Color(0xFF8C876F),
    good: Color(0xFF0CA30C),
    warning: Color(0xFFFAB219),
    serious: Color(0xFFEC835A),
    chartSurface: Color(0xFFFCFCFB),
    chartGrid: Color(0xFFE1E0D9),
    chartAxis: Color(0xFFC3C2B7),
    chartText2: Color(0xFF52514E),
    seriesIn: Color(0xFF2A78D6),
    seriesOut: Color(0xFFEB6834),
  );

  static const dark = AppColors(
    ink900: Color(0xFF0E1622),
    ink800: Color(0xFF16202F),
    ink700: Color(0xFF1E2C40),
    accentDark: Color(0xFFB8791E),
    accentSoft: Color(0xFF3A2C15),
    onAccent: Color(0xFF1B1200),
    textMuted: Color(0xFF948F79),
    good: Color(0xFF0CA30C),
    warning: Color(0xFFFAB219),
    serious: Color(0xFFEC835A),
    chartSurface: Color(0xFF1A1A19),
    chartGrid: Color(0xFF2C2C2A),
    chartAxis: Color(0xFF383835),
    chartText2: Color(0xFFC3C2B7),
    seriesIn: Color(0xFF3987E5),
    seriesOut: Color(0xFFD95926),
  );

  @override
  AppColors copyWith({
    Color? ink900,
    Color? ink800,
    Color? ink700,
    Color? accentDark,
    Color? accentSoft,
    Color? onAccent,
    Color? textMuted,
    Color? good,
    Color? warning,
    Color? serious,
    Color? chartSurface,
    Color? chartGrid,
    Color? chartAxis,
    Color? chartText2,
    Color? seriesIn,
    Color? seriesOut,
  }) {
    return AppColors(
      ink900: ink900 ?? this.ink900,
      ink800: ink800 ?? this.ink800,
      ink700: ink700 ?? this.ink700,
      accentDark: accentDark ?? this.accentDark,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      textMuted: textMuted ?? this.textMuted,
      good: good ?? this.good,
      warning: warning ?? this.warning,
      serious: serious ?? this.serious,
      chartSurface: chartSurface ?? this.chartSurface,
      chartGrid: chartGrid ?? this.chartGrid,
      chartAxis: chartAxis ?? this.chartAxis,
      chartText2: chartText2 ?? this.chartText2,
      seriesIn: seriesIn ?? this.seriesIn,
      seriesOut: seriesOut ?? this.seriesOut,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ink900: Color.lerp(ink900, other.ink900, t)!,
      ink800: Color.lerp(ink800, other.ink800, t)!,
      ink700: Color.lerp(ink700, other.ink700, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      good: Color.lerp(good, other.good, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      serious: Color.lerp(serious, other.serious, t)!,
      chartSurface: Color.lerp(chartSurface, other.chartSurface, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      chartAxis: Color.lerp(chartAxis, other.chartAxis, t)!,
      chartText2: Color.lerp(chartText2, other.chartText2, t)!,
      seriesIn: Color.lerp(seriesIn, other.seriesIn, t)!,
      seriesOut: Color.lerp(seriesOut, other.seriesOut, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
