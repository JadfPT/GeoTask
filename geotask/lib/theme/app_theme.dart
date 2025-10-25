import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData _base(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        colorSchemeSeed: const Color(0xFF4F46E5),
        appBarTheme: const AppBarTheme(centerTitle: true),
        cardTheme: CardThemeData(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      );

  static final light = _base(Brightness.light);
  static final dark = _base(Brightness.dark);
}
