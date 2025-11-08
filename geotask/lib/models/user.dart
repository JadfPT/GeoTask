class User {
  final String id;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'email': email,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
      };

  static User fromRow(Map<String, Object?> r) {
    return User(
      id: r['id'] as String,
      email: r['email'] as String,
      passwordHash: r['passwordHash'] as String,
      createdAt: DateTime.tryParse(r['createdAt'] as String) ?? DateTime.now(),
    );
  }
}
