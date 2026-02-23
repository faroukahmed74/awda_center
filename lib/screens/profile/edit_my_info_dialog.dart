import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

/// Dialog for the current user to edit their own name and phone (no roles/permissions).
class EditMyInfoDialog extends StatefulWidget {
  final UserModel user;

  const EditMyInfoDialog({super.key, required this.user});

  @override
  State<EditMyInfoDialog> createState() => _EditMyInfoDialogState();
}

class _EditMyInfoDialogState extends State<EditMyInfoDialog> {
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _phoneController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameArController = TextEditingController(text: widget.user.fullNameAr ?? '');
    _nameEnController = TextEditingController(text: widget.user.fullNameEn ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().updateUserProfile(
      widget.user.id,
      fullNameAr: _nameArController.text.trim().isEmpty ? null : _nameArController.text.trim(),
      fullNameEn: _nameEnController.text.trim().isEmpty ? null : _nameEnController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editMyInfo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.user.email, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _nameArController,
              decoration: InputDecoration(labelText: l10n.fullNameAr),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameEnController,
              decoration: InputDecoration(labelText: l10n.fullNameEn),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: l10n.phone),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}
