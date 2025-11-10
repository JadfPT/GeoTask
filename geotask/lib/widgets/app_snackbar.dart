import 'package:flutter/material.dart';
/*
  Ficheiro: app_snackbar.dart
  Propósito: Helpers para mostrar SnackBars de forma consistente na aplicação.
  - Use `showAppSnackBar(context, 'texto')` para mensagens curtas.
*/

/// Simple helper to show SnackBars consistently across the app.
///
/// Usage:
///   showAppSnackBar(context, 'Saved');
///   showAppSnackBar(context, Text('Saved'), actionLabel: 'Undo', onAction: () { ... });
void showAppSnackBar(
  BuildContext context,
  Object content, {
  Duration? duration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final widgetContent = content is Widget ? content : Text(content.toString());
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final background = isDark ? Colors.black87 : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final snack = SnackBar(
    backgroundColor: background,
    content: DefaultTextStyle(
      style: theme.textTheme.bodyMedium?.copyWith(color: textColor) ?? TextStyle(color: textColor),
      child: widgetContent,
    ),
    duration: duration ?? const Duration(seconds: 3),
    action: actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, onPressed: onAction, textColor: theme.colorScheme.primary)
        : null,
  );
  messenger.showSnackBar(snack);
}
