import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData _base(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        colorSchemeSeed: const Color(0xFF4F46E5),
        appBarTheme: const AppBarTheme(centerTitle: true),
      );

  static final light = _base(Brightness.light);
  static final dark  = _base(Brightness.dark);
}

/// Controlador do tema com toggle “inteligente”
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Verdadeiro se o tema **efetivo** visível é escuro.
  bool isDarkEffective(BuildContext context) {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    final platformDark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    return platformDark;
  }

  /// Alterna entre claro/escuro. Se estiver em `system`, escolhe o oposto
  /// do tema **efetivo** para garantir alteração no primeiro toque.
  void toggle(BuildContext context) {
    if (_mode == ThemeMode.system) {
      final effectiveDark = isDarkEffective(context);
      _mode = effectiveDark ? ThemeMode.light : ThemeMode.dark;
    } else {
      _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    }
    notifyListeners();
  }
}
