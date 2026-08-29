import 'package:flutter/material.dart';

/// Palette sampled from sadapay.pk rather than approximated: coral is the brand
/// accent, deep navy carries text, and blush is the tint that keeps large surfaces
/// from being flat white.
abstract final class MeowColors {
  static const coral = Color(0xFFFF7B66);
  static const coralInk = Color(0xFF8C2E1E);
  static const navy = Color(0xFF072333);
  static const steel = Color(0xFF164A64);
  static const slate = Color(0xFF5A6063);
  static const muted = Color(0xFF849199);
  static const blush = Color(0xFFFFF2F0);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFFAFAFA);
  static const line = Color(0xFFE8EAEC);
  static const positive = Color(0xFF0E9F6E);
}

/// SadaPay pairs Gilroy with Inter. Gilroy is not freely distributable, so the app
/// ships Inter alone rather than approximating a licensed face with something that
/// looks nearly-but-not-quite right.
ThemeData meowTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

  return base.copyWith(
    scaffoldBackgroundColor: MeowColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MeowColors.coral,
      brightness: Brightness.light,
      primary: MeowColors.coral,
      onPrimary: Colors.white,
      surface: MeowColors.surface,
      onSurface: MeowColors.navy,
      error: MeowColors.coralInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MeowColors.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: MeowColors.navy,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: MeowColors.navy,
      displayColor: MeowColors.navy,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MeowColors.coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: MeowColors.line,
        disabledForegroundColor: MeowColors.muted,
        minimumSize: const Size.fromHeight(54),
        // 12px matches the radius SadaPay uses on its own calls to action.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// Headline style: heavy weight with negative tracking, the treatment SadaPay uses
/// on its own large type.
const meowHeadline = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.8,
  color: MeowColors.navy,
  height: 1.15,
);

const meowLabel = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
  color: MeowColors.muted,
);

/// Account numbers are read aloud and compared digit by digit, so they are grouped
/// and set in tabular figures -- `1000 0001` rather than `10000001`.
String formatAccountNumber(String raw) {
  if (raw.length != 8) return raw;
  return '${raw.substring(0, 4)} ${raw.substring(4)}';
}
