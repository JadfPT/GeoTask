import 'dart:math';
import '../data/db/user_dao.dart';
import 'notification_service.dart';

/*
  Ficheiro: password_reset_service.dart
  Propósito: Serviço simples em memória para simular envio de códigos de
  recuperação de password para testes locais.

  Funcionamento:
  - `sendCode(email)` gera um código de 4 dígitos e envia como notificação
    local (simula um email). Requer `NotificationService.init()`.
  - `verifyCode(email, code)` valida o código e verifica expiração.
  - Os códigos têm um TTL configurável (por defeito 10 minutos).

  Nota de segurança: este mecanismo é apenas para desenvolvimento/local.
  Em produção, o envio e validação devem ser feitos por um serviço seguro
  (e.g. email real com código temporário no servidor).
*/

class _CodeEntry {
  final String code;
  final DateTime expiresAt;
  _CodeEntry(this.code, this.expiresAt);
}

class PasswordResetService {
  PasswordResetService._();
  static final PasswordResetService instance = PasswordResetService._();

  final Map<String, _CodeEntry> _codes = {};
  final int codeTtlMinutes = 10;

  Future<void> sendCode(String email) async {
    // garantir que o utilizador existe localmente
    final user = await UserDao.instance.getByEmail(email);
    if (user == null) throw Exception('User not found');

    final rnd = Random();
    final code = (rnd.nextInt(9000) + 1000).toString(); // 4 digits
    final expires = DateTime.now().add(Duration(minutes: codeTtlMinutes));
    _codes[email] = _CodeEntry(code, expires);

    // enviar código de verificação como notificação local para simular entrega por email.
    await NotificationService.instance.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'GeoTask — Código de verificação',
      body: 'Código: $code',
    );
  }

  /// Verificar código para [email]. Retorna true se válido e não expirado.
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
