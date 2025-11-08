import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Utility functions for password hashing and verification.
///
/// Exposes a PBKDF2-HMAC-SHA256 based hasher and verifier using the `crypto`
/// package so there is no native dependency. The stored format is:
///
///   pbkdf2:iterations:saltBase64:hashBase64
///
/// Note: only the PBKDF2 format is supported. Legacy SHA-256 hex strings are
/// no longer accepted; they should have been migrated previously.

Uint8List _randomBytes(int length) {
  final rnd = Random.secure();
  final b = Uint8List(length);
  for (var i = 0; i < length; i++) {
    b[i] = rnd.nextInt(256);
  }
  return b;
}

Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations, int dkLen) {
  const hLen = 32; // SHA256 output bytes
  final l = (dkLen + hLen - 1) ~/ hLen;
  final out = Uint8List(l * hLen);
  final passwordBytes = password;
  for (var i = 1; i <= l; i++) {
    final block = <int>[
      ...salt,
      (i >> 24) & 0xff,
      (i >> 16) & 0xff,
      (i >> 8) & 0xff,
      i & 0xff,
    ];
    var u = Hmac(sha256, passwordBytes).convert(block).bytes;
    final t = Uint8List.fromList(u);
    for (var j = 1; j < iterations; j++) {
      u = Hmac(sha256, passwordBytes).convert(u).bytes;
      for (var k = 0; k < hLen; k++) {
        t[k] ^= u[k];
      }
    }
    out.setRange((i - 1) * hLen, i * hLen, t);
  }
  return out.sublist(0, dkLen);
}

/// Create a PBKDF2 hash string for [password].
///
/// Parameters:
/// - [iterations]: number of iterations (default 100000).
/// - [saltLen]: salt length in bytes (default 16).
/// - [dkLen]: derived key length in bytes (default 32).
String hashPasswordPbkdf2(String password, {int iterations = 100000, int saltLen = 16, int dkLen = 32}) {
  final salt = _randomBytes(saltLen);
  final key = _pbkdf2(Uint8List.fromList(utf8.encode(password)), salt, iterations, dkLen);
  final saltB64 = base64.encode(salt);
  final keyB64 = base64.encode(key);
  return 'pbkdf2:$iterations:$saltB64:$keyB64';
}

bool _isPbkdf2(String stored) => stored.startsWith('pbkdf2:');

/// Verify [password] against the stored hash string. Supports both the new
/// PBKDF2 format and legacy SHA-256 hex strings.
bool verifyPassword(String password, String stored) {
  if (!_isPbkdf2(stored)) return false;
  final parts = stored.split(':');
  if (parts.length != 4) return false;
  final iterations = int.tryParse(parts[1]);
  if (iterations == null) return false;
  final salt = base64.decode(parts[2]);
  final expected = base64.decode(parts[3]);
  final key = _pbkdf2(Uint8List.fromList(utf8.encode(password)), Uint8List.fromList(salt), iterations, expected.length);
  if (key.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < key.length; i++) {
    diff |= key[i] ^ expected[i];
  }
  return diff == 0;
}
