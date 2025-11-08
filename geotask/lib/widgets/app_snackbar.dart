import 'package:flutter/material.dart';

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
  final snack = SnackBar(
    content: widgetContent,
    duration: duration ?? const Duration(seconds: 3),
    action: actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, onPressed: onAction)
        : null,
  );
  messenger.showSnackBar(snack);
}
