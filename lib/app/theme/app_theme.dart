import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';

/// Light/dark [ThemeData], built from explicit [ColorScheme]s (rather than
/// `ColorScheme.fromSeed`) so the exact hex values approved in
/// `docs/prototype.html` survive the translation to Flutter.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(brightness: Brightness.light, tokens: AppColors.light);

  static ThemeData get dark => _build(brightness: Brightness.dark, tokens: AppColors.dark);

  static ThemeData _build({required Brightness brightness, required AppColors tokens}) {
    final isLight = brightness == Brightness.light;

    const accentLight = Color(0xFFB8791E);
    const accentDarkMode = Color(0xFFD99A3E);
    const paperLight = Color(0xFFF6F3EA);
    const paperDark = Color(0xFF14120D);
    const cardLight = Color(0xFFFFFFFF);
    const cardDark = Color(0xFF1C1A14);
    const lineLight = Color(0xFFE3DDCB);
    const lineDark = Color(0xFF322C1E);
    const textPrimaryLight = Color(0xFF201D17);
    const textPrimaryDark = Color(0xFFF4F1E7);
    const textSecondaryLight = Color(0xFF5C5748);
    const textSecondaryDark = Color(0xFFC7C2AF);
    const focusLight = Color(0xFF2A78D6);
    const focusDark = Color(0xFF3987E5);
    const criticalLight = Color(0xFFD03B3B);
    const criticalDark = Color(0xFFE66767);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? accentLight : accentDarkMode,
      onPrimary: tokens.onAccent,
      secondary: isLight ? focusLight : focusDark,
      onSecondary: Colors.white,
      error: isLight ? criticalLight : criticalDark,
      onError: Colors.white,
      surface: isLight ? cardLight : cardDark,
      onSurface: isLight ? textPrimaryLight : textPrimaryDark,
      surfaceContainerLowest: isLight ? paperLight : paperDark,
      surfaceContainer: isLight ? paperLight : paperDark,
      outlineVariant: isLight ? lineLight : lineDark,
      outline: isLight ? lineLight : lineDark,
    );

    final textPrimary = isLight ? textPrimaryLight : textPrimaryDark;
    final textSecondary = isLight ? textSecondaryLight : textSecondaryDark;
    final paper = isLight ? paperLight : paperDark;
    final line = isLight ? lineLight : lineDark;
    final card = isLight ? cardLight : cardDark;

    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper,
      textTheme: buildAppTextTheme(base.textTheme, textPrimary),
      extensions: [tokens],
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: colorScheme.secondary, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.ink900,
        contentTextStyle: const TextStyle(color: Color(0xFFEDE7D6)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: paper,
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
