import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
  Ficheiro: app_theme.dart
  Propósito: Definições de tema e controlador de tema persistente por utilizador.

  Conteúdo:
  - `AppTheme`: fornece as instâncias de `ThemeData` para modos claro/escuro.
  - `ThemeController`: controla a preferência de tema (light/dark/system) e
    persiste a escolha por utilizador em `SharedPreferences`.

  Observações:
  - A persistência é feita apenas se houver um `userId` associado; para
    utilizadores anónimos mantém-se o valor por omissão (dark).
  - Escritas em disco são assíncronas e não bloqueiam a UI (fire-and-forget).
*/

class AppTheme {
  static ThemeData _base(Brightness b) => ThemeData(
        useMaterial3: true,
        brightness: b,
        colorSchemeSeed: const Color(0xFF4F46E5),
        appBarTheme: const AppBarTheme(centerTitle: true),
      );

  static final light = _base(Brightness.light);
  static final dark = _base(Brightness.dark);
}

/// Controlador do tema com toggle “inteligente”
class ThemeController extends ChangeNotifier {
  // Valor por omissão: escuro
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  String? _userId;

  static const _prefsKey = 'theme.v1.';

  Future<void> loadForUser(String? userId) async {
    // Carrega preferência de tema persistida para [userId]. Se for null, usa
    // o valor por omissão (dark) e não persiste.
    _userId = userId;
    if (userId == null) {
      _mode = ThemeMode.dark;
      notifyListeners();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefsKey$userId';
    final val = prefs.getString(key);
    if (val == null) {
      _mode = ThemeMode.dark; // valor por omissão
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

  /// Verdadeiro se o tema efetivo visível é escuro.
  bool isDarkEffective(BuildContext context) {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    final platformDark =
        MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
    return platformDark;
  }

  /// Alterna entre claro/escuro. Se estiver em `system`, escolhe o oposto
  /// do tema efetivo para garantir alteração no primeiro toque.
  void toggle(BuildContext context) {
    if (_mode == ThemeMode.system) {
      final effectiveDark = isDarkEffective(context);
      _mode = effectiveDark ? ThemeMode.light : ThemeMode.dark;
    } else {
      _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    }
    notifyListeners();
    // Persistir a preferência associada ao utilizador (escrita em background).
    Future.microtask(() => _save());
  }
}
