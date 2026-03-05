import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class InviteUserDialog extends StatefulWidget {
  const InviteUserDialog({super.key});

  @override
  State<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends State<InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameArController = TextEditingController();
  final _fullNameEnController = TextEditingController();
  UserRole _role = UserRole.patient;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameArController.dispose();
    _fullNameEnController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.id ?? '';
      await FirestoreService().createInvite(
        email: _emailController.text.trim(),
        role: _role.value,
        fullNameAr: _fullNameArController.text.trim().isEmpty ? null : _fullNameArController.text.trim(),
        fullNameEn: _fullNameEnController.text.trim().isEmpty ? null : _fullNameEnController.text.trim(),
        invitedBy: uid,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.inviteUser),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.inviteUserHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.email),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.email;
                  if (!v.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                value: _role,
                decoration: InputDecoration(labelText: l10n.role),
                items: UserRole.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.value)))
                    .toList(),
                onChanged: (r) => setState(() => _role = r ?? UserRole.patient),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameArController,
                decoration: const InputDecoration(labelText: 'Full name (Arabic) (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameEnController,
                decoration: const InputDecoration(labelText: 'Full name (English) (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}
