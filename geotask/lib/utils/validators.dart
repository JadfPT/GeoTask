// Small, reusable validators used across the app.

bool isValidEmail(String email) {
  final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
  return emailRegex.hasMatch(email);
}

bool isNonEmpty(String s) => s.trim().isNotEmpty;
