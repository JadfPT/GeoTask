/*
  Ficheiro: user.dart
  Propósito: Modelo `User` com serialização mínima para armazenamento local.

  Descrição:
  - Representa um utilizador com id, email, username opcional, hash da
    password e timestamp de criação.
  - Métodos `toRow` / `fromRow` convertem para/desde um mapa compatível com
    persistência em base de dados local (ex.: SQLite) ou armazenamento similar.
*/

class User {
  final String id;
  final String email;
  final String? username;
  final String passwordHash;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.username,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'email': email,
    // Campos guardados como tipos primitivos; DateTime armazenado como ISO string
    'username': username,
    'passwordHash': passwordHash,
    'createdAt': createdAt.toIso8601String(),
      };

  static User fromRow(Map<String, Object?> r) {
    return User(
      id: r['id'] as String,
      email: r['email'] as String,
      username: r['username'] as String?,
      passwordHash: r['passwordHash'] as String,
      // Em caso de dados corrompidos, fallback para DateTime.now() evita falhas
      createdAt: DateTime.tryParse(r['createdAt'] as String) ?? DateTime.now(),
    );
  }
}
