import 'package:flutter/material.dart';

import 'annotations.dart';

/// 宣纸 / 夜读两套配色，沿用网页版的色调。
class Palette {
  final bool night;
  final Color bg;
  final Color paper;
  final Color card;
  final Color ink;
  final Color soft;
  final Color faint;
  final Color line;
  final Color red;
  final Color gold;
  final Color chip;
  final Color selection;

  const Palette({
    required this.night,
    required this.bg,
    required this.paper,
    required this.card,
    required this.ink,
    required this.soft,
    required this.faint,
    required this.line,
    required this.red,
    required this.gold,
    required this.chip,
    required this.selection,
  });

  static const Palette day = Palette(
    night: false,
    bg: Color(0xFFF2ECDF),
    paper: Color(0xFFFBF7ED),
    card: Color(0xFFF7F1E3),
    ink: Color(0xFF2B2620),
    soft: Color(0xFF796E5D),
    faint: Color(0xFFA89B84),
    line: Color(0xFFDED2B9),
    red: Color(0xFF9C3A2C),
    gold: Color(0xFFA58243),
    chip: Color(0xFFECE1C9),
    selection: Color(0xFFC9D9E8),
  );

  static const Palette nightMode = Palette(
    night: true,
    bg: Color(0xFF161A1B),
    paper: Color(0xFF1E2425),
    card: Color(0xFF252C2D),
    ink: Color(0xFFE9E2D3),
    soft: Color(0xFFB6AC99),
    faint: Color(0xFF847C6C),
    line: Color(0xFF374042),
    red: Color(0xFFD0806A),
    gold: Color(0xFFC8A86A),
    chip: Color(0xFF2D3637),
    selection: Color(0xFF3A5A70),
  );

  static Palette of(bool night) => night ? Palette.nightMode : Palette.day;

  /// 标注底色：与白天/夜间都保持足够对比度。
  Color markBackground(int index) =>
      Color(kMarkArgb[normalizeColor(index)]).withOpacity(night ? 0.38 : 0.26);

  Color markBorder(int index) =>
      Color(kMarkArgb[normalizeColor(index)]).withOpacity(night ? 0.95 : 0.85);
}

const TextStyle kaiStyle = TextStyle(
  fontFamily: 'KaiTi',
  fontFamilyFallback: <String>['STKaiti', 'Kaiti SC', 'SimSun', 'serif'],
);

ThemeData buildTheme(Palette p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.red,
    brightness: p.night ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: p.red,
    surface: p.paper,
    onSurface: p.ink,
    outline: p.line,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: p.night ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.paper,
    dividerColor: p.line,
    textSelectionTheme: TextSelectionThemeData(
      selectionColor: p.selection,
      selectionHandleColor: p.red,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    iconTheme: IconThemeData(color: p.soft),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: p.red),
      ),
      hintStyle: TextStyle(color: p.faint, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}
