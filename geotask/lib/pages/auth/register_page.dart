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

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

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
      final username = _usernameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      if (!isValidEmail(email)) {
        if (mounted) {
          showAppSnackBar(context, 'Por favor introduz um email válido.');
        }
        return;
      }
      if (!isNonEmpty(username)) {
        if (mounted) {
          showAppSnackBar(context, 'Por favor introduz um username.');
        }
        return;
      }
      final user = await auth.register(username, email, _passCtrl.text);
      // initialize user-scoped stores
      await cats.load(user.id);
      await tasks.loadFromDb(ownerId: user.id);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const CircularProgressIndicator() : const Text('Registar'),
            ),
          ],
        ),
      ),
    );
  }
}
