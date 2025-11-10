import 'dart:math';
import '../data/db/user_dao.dart';
import 'notification_service.dart';

class _CodeEntry {
  final String code;
  final DateTime expiresAt;
  _CodeEntry(this.code, this.expiresAt);
}

/// Simple in-memory password reset code service used to simulate an email
/// verification flow for local testing.
///
/// Usage:
/// - call `sendCode(email)` to generate a 4-digit code and send it as a
///   local notification (requires NotificationService.init() beforehand).
/// - call `verifyCode(email, code)` to check the submitted code.
/// - codes expire after [codeTtlMinutes].
class PasswordResetService {
  PasswordResetService._();
  static final PasswordResetService instance = PasswordResetService._();

  final Map<String, _CodeEntry> _codes = {};
  final int codeTtlMinutes = 10;

  Future<void> sendCode(String email) async {
    // ensure the user exists locally
    final user = await UserDao.instance.getByEmail(email);
    if (user == null) throw Exception('User not found');

    final rnd = Random();
    final code = (rnd.nextInt(9000) + 1000).toString(); // 4 digits
    final expires = DateTime.now().add(Duration(minutes: codeTtlMinutes));
    _codes[email] = _CodeEntry(code, expires);

    // send as a local notification so we can simulate email delivery.
    await NotificationService.instance.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'GeoTask — Código de verificação',
      body: 'Código: $code',
    );
  }

  /// Verify code for [email]. Returns true if valid and not expired.
  bool verifyCode(String email, String code) {
    final e = _codes[email];
    if (e == null) return false;
    if (DateTime.now().isAfter(e.expiresAt)) {
      _codes.remove(email);
      return false;
    }
    final ok = e.code == code;
    if (ok) _codes.remove(email);
    return ok;
  }

  void clearCode(String email) => _codes.remove(email);
}
