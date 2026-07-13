import 'package:flutter/material.dart';

class AppTheme {
  static const pink = Color(0xFFE83E8C);
  static const softPink = Color(0xFFF7C8DA);
  static const cream = Color(0xFFFFF8F5);
  static const ink = Color(0xFF171717);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: pink,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: ink,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: pink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      );
}
