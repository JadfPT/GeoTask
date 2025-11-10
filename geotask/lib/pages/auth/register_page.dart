import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_store.dart';
import '../../data/categories_store.dart';
import '../../data/task_store.dart';
import '../../utils/validators.dart';
import '../../widgets/app_snackbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

/*
  Ficheiro: register_page.dart
  Propósito: Formulário de registo de novo utilizador.

  Resumo:
  - Valida username, email e password; cria conta via `AuthStore`.
  - Inicializa stores dependentes (categorias e tarefas) após registo.
  - Mostra mensagens de erro curtas e apropriadas para avaliação académica.
*/

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthStore>();
      final cats = context.read<CategoriesStore>();
      final tasks = context.read<TaskStore>();
      final username = _usernameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final user = await auth.register(username, email, pass);
      // inicializa stores dependentes do utilizador
      await cats.load(user.id);
      await tasks.loadFromDb(ownerId: user.id);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('UNIQUE constraint failed') || msg.toLowerCase().contains('unique')) {
          showAppSnackBar(context, 'Já existe uma conta com este email.');
        } else {
          // Mostra um erro curto, numa única linha, para evitar grandes despejos de BD na UI
          showAppSnackBar(context, 'Erro: ${msg.split('\n').first}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Fundo em gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withAlpha((0.12 * 255).round()),
                  theme.colorScheme.primary.withAlpha((0.05 * 255).round()),
                ],
              ),
            ),
          ),
          SafeArea(
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.22 * 255).round()), blurRadius: 12, offset: const Offset(0,6))],
                          ),
                          child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Image.asset('assets/icon.png', fit: BoxFit.cover)),
                        ),
                        const SizedBox(height: 18),
                        Text('GeoTask', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Crie a sua conta e comece a receber alertas por localização', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withAlpha((0.06 * 255).round()),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.surfaceContainerHighest.withAlpha((0.08 * 255).round())),
                          ),
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _usernameCtrl,
                                  decoration: const InputDecoration(labelText: 'Username'),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Username é obrigatório.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
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
                                TextFormField(
                                  controller: _passCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _showPass = !_showPass),
                                    ),
                                  ),
                                  obscureText: !_showPass,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password é obrigatória.';
                                    if (v.length < 4) return 'Password demasiado curta.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Confirmar Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _showConfirm = !_showConfirm),
                                    ),
                                  ),
                                  obscureText: !_showConfirm,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Confirme a password.';
                                    if (v != _passCtrl.text) return 'As passwords não coincidem.';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      elevation: 6,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                    ),
                                    onPressed: _loading ? null : _submit,
                                    child: _loading ? const SizedBox(width:20, height:20, child:CircularProgressIndicator(strokeWidth:2)) : const Text('Registar'),
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }
}
