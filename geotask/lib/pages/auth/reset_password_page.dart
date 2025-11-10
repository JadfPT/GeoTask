import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_store.dart';
import '../../services/password_reset_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/validators.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;

  // UI state
  bool _showNew = false;
  bool _showConfirm = false;

  // resend cooldown
  Timer? _resendTimer;
  int _resendRemaining = 0;
  static const int _resendCooldownSeconds = 30;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!isValidEmail(_emailCtrl.text.trim())) {
      showAppSnackBar(context, 'Introduza um email válido.');
      return;
    }
    setState(() => _sending = true);
    try {
      await PasswordResetService.instance.sendCode(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _startResendTimer();
        });
        showAppSnackBar(context, 'Código enviado como notificação. Verifique as notificações da app.');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('User not found') || msg.toLowerCase().contains('user not found')) {
          showAppSnackBar(context, 'Utilizador não encontrado. Confirme o email ou crie uma conta.');
        } else {
          showAppSnackBar(context, 'Erro ao enviar código: ${msg.split('\n').first}');
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendRemaining = _resendCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _resendRemaining -= 1;
        if (_resendRemaining <= 0) {
          _resendTimer?.cancel();
          _resendRemaining = 0;
        }
      });
    });
  }

  Future<void> _confirmAndReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _verifying = true);
    try {
      final email = _emailCtrl.text.trim();
      final code = _codeCtrl.text.trim();
      final ok = PasswordResetService.instance.verifyCode(email, code);
      if (!ok) {
        showAppSnackBar(context, 'Código inválido ou expirado. Peça um novo código.');
        return;
      }

      final auth = context.read<AuthStore>();
      await auth.resetPassword(email, _newCtrl.text);
      if (mounted) {
        showAppSnackBar(context, 'Password atualizada com sucesso. Faça login com a nova password.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Erro: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/login'),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + title like login page
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset('assets/icon.png', width: 120, height: 120),
                    ),
                    const SizedBox(height: 12),
                    Text('GeoTask', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Recuperar password', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 18),

                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Email + send/resend UI
                              if (!_codeSent) ...[
                                TextFormField(
                                  controller: _emailCtrl,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Email é obrigatório.';
                                    if (!isValidEmail(v.trim())) return 'Email inválido.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _sending ? null : _sendCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      elevation: 4,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    ),
                                    child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enviar código'),
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _emailCtrl,
                                        readOnly: true,
                                        decoration: const InputDecoration(labelText: 'Email'),
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Email é obrigatório.';
                                          if (!isValidEmail(v.trim())) return 'Email inválido.';
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: (_resendRemaining == 0 && !_sending) ? () async {
                                        // resend code, restart cooldown
                                        await _sendCode();
                                      } : null,
                                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                                      child: Text(_resendRemaining > 0 ? 'Reenviar (${_resendRemaining}s)' : 'Reenviar'),
                                    ),
                                  ],
                                ),
                              ],

                              if (_codeSent) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _codeCtrl,
                                  decoration: const InputDecoration(labelText: 'Código (4 dígitos)'),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Código obrigatório.';
                                    if (v.trim().length != 4) return 'Código deve ter 4 dígitos.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _newCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Nova password',
                                    suffixIcon: IconButton(
                                      icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _showNew = !_showNew),
                                    ),
                                  ),
                                  obscureText: !_showNew,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password é obrigatória.';
                                    if (v.length < 4) return 'Password demasiado curta.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _confirmCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Confirmar password',
                                    suffixIcon: IconButton(
                                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                                    ),
                                  ),
                                  obscureText: !_showConfirm,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Confirma a password.';
                                    if (v != _newCtrl.text) return 'As passwords não coincidem.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      elevation: 4,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    ),
                                    onPressed: _verifying ? null : _confirmAndReset,
                                    child: _verifying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Alterar password'),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
