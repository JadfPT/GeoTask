import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Default to dark as requested
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  String? _userId;

  static const _prefsKey = 'theme.v1.';

  Future<void> loadForUser(String? userId) async {
    // Loads persisted theme preference for [userId]. If [userId] is null the
    // controller falls back to a sensible default (dark) and does not persist.
    _userId = userId;
    if (userId == null) {
      // default to dark for anonymous/not-signed users
      _mode = ThemeMode.dark;
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKey$userId';
    final val = prefs.getString(key);
    if (val == null) {
      _mode = ThemeMode.dark; // default
    } else if (val == 'light') {
      _mode = ThemeMode.light;
    } else if (val == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> _save() async {
    if (_userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKey$_userId';
    final v = _mode == ThemeMode.light ? 'light' : 'dark';
    await prefs.setString(key, v);
  }

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
    // persist if associated to a user (background write)
    // Intentionally fire-and-forget the IO to avoid blocking the UI.
    Future.microtask(() => _save());
  }
}
