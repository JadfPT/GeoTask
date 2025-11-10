// The original edit_user_page.dart was corrupted during edits. To restore
// a working analyzer and compile state, this file now exports the new
// implementation located in `edit_user_page_new.dart`.

// Consolidated implementation of EditUserPage moved here from edit_user_page_new.dart
// to remove intermediary duplicates and simplify the codebase.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/auth_store.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/confirm_dialog.dart';

class EditUserPage extends StatefulWidget {
	const EditUserPage({super.key});

	@override
	State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
	final _usernameCtrl = TextEditingController();
	final _formKey = GlobalKey<FormState>();
	bool _saving = false;
	File? _avatarFile;
	String? _originalAvatarPath;
	bool _avatarRemovedStaged = false;
	String? _originalUsername;
	bool _hasChanges = false;

	@override
	void initState() {
		super.initState();
		_usernameCtrl.addListener(_onUsernameChanged);
	}

	@override
	void dispose() {
		_usernameCtrl.removeListener(_onUsernameChanged);
		_usernameCtrl.dispose();
		super.dispose();
	}

	void _onUsernameChanged() => _updateHasChanges();

	void _updateHasChanges() {
		final nameChanged = _usernameCtrl.text.trim() != (_originalUsername ?? '');
		final avatarNew = _avatarFile != null && _avatarFile!.path != (_originalAvatarPath ?? '');
		final avatarRemoved = _avatarRemovedStaged;
		final newHas = nameChanged || avatarNew || avatarRemoved;
		if (newHas != _hasChanges) setState(() => _hasChanges = newHas);
	}

	Future<void> _loadAvatarFor(String? userId) async {
		if (userId == null) return;
		try {
			final prefs = await SharedPreferences.getInstance();
			final key = 'avatar_$userId';
			final path = prefs.getString(key);
			_originalAvatarPath = path;
			if (path == null) return;
			final f = File(path);
			if (await f.exists()) {
				if (!mounted) return;
				setState(() {
					_avatarFile = f;
					_avatarRemovedStaged = false;
				});
				_updateHasChanges();
			}
		} catch (_) {}
	}

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		final auth = context.read<AuthStore>();
		final user = auth.currentUser;
		_usernameCtrl.text = user?.username ?? '';
		_originalUsername = user?.username ?? '';
		_loadAvatarFor(user?.id);
		_updateHasChanges();
	}

	Future<void> _pickAvatar(ImageSource source) async {
		try {
			final picker = ImagePicker();
			final xfile = await picker.pickImage(source: source, imageQuality: 85);
			if (xfile == null) return;
			final bytes = await xfile.readAsBytes();

			final dir = await getApplicationDocumentsDirectory();
			final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}${p.extension(xfile.path)}';
			final dest = File(p.join(dir.path, filename));
			await dest.writeAsBytes(bytes);

				// Ensure widget still mounted after awaiting file operations before using context/state
				if (!mounted) return;
				setState(() {
					_avatarFile = dest;
					_avatarRemovedStaged = false;
				});
				_updateHasChanges();
		} catch (e) {
			if (!mounted) return;
			showAppSnackBar(context, 'Erro ao escolher imagem: ${e.toString().split('\n').first}');
		}
	}

	Future<void> _removeAvatar() async {
		if (mounted) {
			setState(() {
				_avatarFile = null;
				_avatarRemovedStaged = true;
			});
			showAppSnackBar(context, 'Avatar removido (aguarda guardar mudanças).');
			_updateHasChanges();
		}
	}

	Future<void> _save() async {
		if (!(_formKey.currentState?.validate() ?? false)) return;
		setState(() => _saving = true);
		try {
			final auth = context.read<AuthStore>();
			final user = auth.currentUser;
			if (user == null) throw Exception('No user');
			await auth.updateUsername(user.id, _usernameCtrl.text.trim());

			try {
				final prefs = await SharedPreferences.getInstance();
				final key = 'avatar_${user.id}';

				// Handle staged removal
				if (_avatarRemovedStaged) {
					final orig = _originalAvatarPath ?? prefs.getString(key);
					if (orig != null) {
						try {
							final f = File(orig);
							if (await f.exists()) await f.delete();
						} catch (_) {}
						await prefs.remove(key);
					}
					_originalAvatarPath = null;
					_avatarRemovedStaged = false;
				}

				// Handle staged new avatar
				if (_avatarFile != null) {
					final current = _originalAvatarPath ?? prefs.getString(key);
					if (current == null || current != _avatarFile!.path) {
						await prefs.setString(key, _avatarFile!.path);
						if (current != null && current != _avatarFile!.path) {
							try {
								final f = File(current);
								if (await f.exists()) await f.delete();
							} catch (_) {}
						}
						_originalAvatarPath = _avatarFile!.path;
					}
				}
			} catch (_) {}

			// Avoid using BuildContext after async gaps if widget was disposed.
			if (!mounted) return;
			_originalUsername = _usernameCtrl.text.trim();
			setState(() {
				_hasChanges = false;
			});
			showAppSnackBar(context, 'Alterações guardadas.');
		} catch (e) {
			if (!mounted) return;
			showAppSnackBar(context, 'Erro ao atualizar: ${e.toString().split('\n').first}');
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	Future<void> _deleteAccount() async {
		final auth = context.read<AuthStore>();
		final user = auth.currentUser;
		if (user == null) return;
	final confirm = await showConfirmDialog(context,
	    title: 'Apagar conta?',
	    content: 'Isto apagará permanentemente a sua conta e todos os dados associados. Continuar?',
	    confirmLabel: 'Apagar',
	    cancelLabel: 'Cancelar');
	if (!mounted) return;
	if (confirm != true) return;
	final password = await showPasswordPrompt(context,
		title: 'Confirme com a sua password', label: 'Password', confirmLabel: 'Apagar');
	if (!mounted) return;
	if (password == null) return;
		try {
			final ok = await auth.deleteAccountWithPassword(password);
			// Ensure we're still mounted before using context-derived APIs
			if (!mounted) return;
			if (ok) {
				GoRouter.of(context).go('/login');
			} else {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password incorreta. Conta não apagada.')));
			}
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString().split('\n').first}')));
		}
	}

	void _changePassword() {
		final auth = context.read<AuthStore>();
		final user = auth.currentUser;
		if (user == null) return;
		GoRouter.of(context).push('/reset-password?email=${Uri.encodeComponent(user.email)}&autoSend=1');
	}

	Future<void> _discardStagedChanges() async {
		try {
			// remove staged file if it is different to original
			if (_avatarFile != null && (_originalAvatarPath == null || _avatarFile!.path != _originalAvatarPath)) {
				try {
					final f = File(_avatarFile!.path);
					if (await f.exists()) await f.delete();
				} catch (_) {}
			}

			// restore original avatar if present
			if (_originalAvatarPath != null) {
				final f = File(_originalAvatarPath!);
				if (await f.exists()) {
					if (mounted) setState(() => _avatarFile = f);
				} else {
					if (mounted) setState(() => _avatarFile = null);
				}
			} else {
				if (mounted) setState(() => _avatarFile = null);
			}

			// restore username
			if (_originalUsername != null) {
				_usernameCtrl.text = _originalUsername!;
			}
			_avatarRemovedStaged = false;
			_updateHasChanges();
		} catch (_) {}
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		return Scaffold(
			appBar: AppBar(title: const Text('Editar conta')),
			// Temporarily keep using WillPopScope for compatibility; PopScope is preferred.
			// ignore: deprecated_member_use
			body: WillPopScope(
				onWillPop: () async {
					if (!_hasChanges) return true;
					final res = await showDialog<String?>(
						context: context,
						builder: (ctx) => AlertDialog(
							title: const Text('Alterações não guardadas'),
							content: const Text('Tem alterações não guardadas. Quer guardar antes de sair?'),
							actions: [
								TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), child: const Text('Cancelar')),
								TextButton(onPressed: () => Navigator.of(ctx).pop('discard'), child: const Text('Descartar')),
								ElevatedButton(onPressed: () => Navigator.of(ctx).pop('save'), child: const Text('Guardar')),
							],
						),
					);

					// Widget may be disposed while the dialog was open. Protect uses of
					// `context` and stateful methods by checking `mounted` after `await`.
					if (!mounted) return false;

					if (res == 'save') {
						await _save();
						return mounted; // if disposed during save, don't pop
					}
					if (res == 'discard') {
						await _discardStagedChanges();
						return mounted;
					}
					return false;
				},
				child: SafeArea(
					child: SingleChildScrollView(
						padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Card(
									elevation: 8,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									child: Padding(
										padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
										child: Column(
											children: [
												Stack(
													alignment: Alignment.center,
													children: [
														CircleAvatar(
															radius: 44,
															backgroundColor: theme.colorScheme.primary.withAlpha((0.16 * 255).round()),
															child: _avatarFile == null
																? const Icon(Icons.person, size: 44, color: Colors.white)
																: ClipOval(child: Image.file(_avatarFile!, width: 88, height: 88, fit: BoxFit.cover)),
														),
														Positioned(
															right: 0,
															bottom: 0,
															child: Material(
																color: theme.colorScheme.surface,
																shape: const CircleBorder(),
																child: IconButton(
																	icon: Icon(Icons.edit, size: 18, color: theme.colorScheme.onSurface),
																	onPressed: () {
																		showModalBottomSheet<void>(
																			context: context,
																			builder: (ctx) => SafeArea(
																				child: Column(
																					mainAxisSize: MainAxisSize.min,
																					children: [
																						ListTile(
																							leading: const Icon(Icons.photo_library),
																							title: const Text('Escolher da galeria'),
																							onTap: () {
																								Navigator.of(ctx).pop();
																								_pickAvatar(ImageSource.gallery);
																							},
																						),
																						ListTile(
																							leading: const Icon(Icons.camera_alt),
																							title: const Text('Tirar foto'),
																							onTap: () {
																								Navigator.of(ctx).pop();
																								_pickAvatar(ImageSource.camera);
																							},
																						),
																						ListTile(
																							leading: const Icon(Icons.delete_forever),
																							title: const Text('Remover avatar'),
																							onTap: () {
																								Navigator.of(ctx).pop();
																								_removeAvatar();
																							},
																						),
																						ListTile(
																							leading: const Icon(Icons.close),
																							title: const Text('Cancelar'),
																							onTap: () => Navigator.of(ctx).pop(),
																						),
																					],
																				),
																			),
																		);
																	},
																),
															),
														),
													],
												),
												const SizedBox(height: 14),
												Form(
													key: _formKey,
													child: TextFormField(
														controller: _usernameCtrl,
														decoration: const InputDecoration(labelText: 'Nome de utilizador'),
														validator: (s) {
															final v = (s ?? '').trim();
															if (v.isEmpty) return 'Insira um nome';
															if (v.length < 3) return 'Nome muito curto';
															return null;
														},
													),
												),
												const SizedBox(height: 18),
												Row(
													children: [
														Expanded(
															child: ElevatedButton(
																onPressed: (!_hasChanges || _saving) ? null : () async => await _save(),
																child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Guardar mudanças'),
															),
														),
													],
												),
											],
										),
									),
								),
								const SizedBox(height: 14),
								OutlinedButton.icon(
									icon: const Icon(Icons.lock_outline),
									label: const Text('Alterar password'),
									onPressed: _changePassword,
								),
								const SizedBox(height: 8),
								OutlinedButton.icon(
									icon: const Icon(Icons.delete_outline),
									label: const Text('Apagar conta'),
									style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
									onPressed: _deleteAccount,
								),
							],
						),
					),
				),
			),
		);
	}
}

