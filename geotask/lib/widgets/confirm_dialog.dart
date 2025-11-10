import 'package:flutter/material.dart';
/*
  Ficheiro: confirm_dialog.dart
  Propósito: Diálogos utilitários (confirmação, prompt de password, informação).
  - Fornece funções simples para reutilizar em várias páginas.
*/

/// Simple helpers to show common dialogs used across the app.

/// Show a yes/no confirmation dialog. Returns true if user confirms.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Apagar',
  String cancelLabel = 'Cancelar',
}) {
  return showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(cancelLabel)),
        ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
}

/// Prompt the user for a password and return the entered value or null if
/// cancelled.
Future<String?> showPasswordPrompt(BuildContext context, {String title = 'Confirme com a sua password', String label = 'Password', String confirmLabel = 'Apagar'}) {
  return showDialog<String?>(
    context: context,
    builder: (dctx) {
      final ctrl = TextEditingController();
      return AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: label), obscureText: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(null), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(dctx).pop(ctrl.text), child: Text(confirmLabel)),
        ],
      );
    },
  );
}

/// Show a simple informational dialog with an OK button.
Future<void> showInfoDialog(BuildContext context, {required String title, required String content, String okLabel = 'OK'}) {
  return showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(dctx).pop(), child: Text(okLabel)),
      ],
    ),
  );
}
