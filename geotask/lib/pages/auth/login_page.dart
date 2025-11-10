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
      // reload user-scoped stores
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/icon.png', width: 120, height: 120),
                ),
                const SizedBox(height: 16),
                Text('GeoTask', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Gerencie as suas tarefas por localização', style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 24),

                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                          const SizedBox(height: 20),
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
                              onPressed: _loading
                                  ? null
                                  : () {
                                      if (_formKey.currentState?.validate() ?? false) _submit();
                                    },
                              child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
