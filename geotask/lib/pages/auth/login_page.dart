import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_store.dart';
import '../../data/categories_store.dart';
import '../../data/task_store.dart';
import '../../widgets/app_snackbar.dart';
import 'package:go_router/go_router.dart';
import '../../utils/validators.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

/*
  Ficheiro: login_page.dart
  Propósito: Página de login do utilizador.

  Resumo:
  - Valida e submete credenciais para `AuthStore`.
  - Suporta início de sessão por convidado e navegação para registo/recuperação.
  - Recarrega stores dependentes (categorias e tarefas) após login bem-sucedido.
*/

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthStore>();
      final cats = context.read<CategoriesStore>();
      final tasks = context.read<TaskStore>();
      final user = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      // recarregar armazenamentos com escopo de usuário
      await cats.load(user.id);
      await tasks.loadFromDb(ownerId: user.id);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        if (msg.contains('User not found')) {
          showAppSnackBar(context, 'Utilizador não encontrado.');
        } else if (msg.contains('Invalid credentials')) {
          showAppSnackBar(context, 'Credenciais inválidas. Verifique o email e a password.');
        } else {
          showAppSnackBar(context, 'Erro: ${msg.split('\n').first}');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthStore>();
      final cats = context.read<CategoriesStore>();
      final tasks = context.read<TaskStore>();
      final user = await auth.createGuest();
      await cats.load(user.id);
      await tasks.loadFromDb(ownerId: user.id);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      final msg = e.toString();
      if (mounted) showAppSnackBar(context, 'Erro ao criar convidado: ${msg.split('\n').first}');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  theme.colorScheme.primaryContainer.withAlpha((0.14 * 255).round()),
                  theme.colorScheme.primary.withAlpha((0.06 * 255).round()),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logótipo grande arredondado
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha((0.25 * 255).round()), blurRadius: 18, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('GeoTask', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Lembre-se quando importa — tarefas baseadas na sua localização',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Cartão de formulário translúcido
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
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading ? null : () => context.push('/reset-password'),
                                style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                                child: const Text('Esqueci a palavra-passe?'),
                              ),
                            ),
                            const SizedBox(height: 14),
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
                                onPressed: _loading
                                    ? null
                                    : () {
                                        if (_formKey.currentState?.validate() ?? false) _submit();
                                      },
                                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: theme.colorScheme.primary, width: 1.6),
                                  foregroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                                onPressed: _loading ? null : _guest,
                                child: const Text('Continuar como convidado'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Ainda não tem conta? '),
                                TextButton(
                                  onPressed: () => context.push('/register'),
                                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                                  child: const Text('Criar conta'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
