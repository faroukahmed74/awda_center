import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';

/// Dialog to add a new doctor by sending an invite (email + role doctor + doctor profile).
/// When the doctor registers with that email, they get the doctor role and profile.
class AddDoctorDialog extends StatefulWidget {
  const AddDoctorDialog({super.key});

  @override
  State<AddDoctorDialog> createState() => _AddDoctorDialogState();
}

class _AddDoctorDialogState extends State<AddDoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameArController = TextEditingController();
  final _fullNameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specializationArController = TextEditingController();
  final _specializationEnController = TextEditingController();
  final _qualificationsArController = TextEditingController();
  final _qualificationsEnController = TextEditingController();
  final _certificationsArController = TextEditingController();
  final _certificationsEnController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullNameArController.dispose();
    _fullNameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationArController.dispose();
    _specializationEnController.dispose();
    _qualificationsArController.dispose();
    _qualificationsEnController.dispose();
    _certificationsArController.dispose();
    _certificationsEnController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppLocalizations.of(context).email);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.currentUser?.id ?? '';
      await FirestoreService().createInvite(
        email: email,
        role: 'doctor',
        fullNameAr: _fullNameArController.text.trim().isEmpty ? null : _fullNameArController.text.trim(),
        fullNameEn: _fullNameEnController.text.trim().isEmpty ? null : _fullNameEnController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        invitedBy: uid,
        specializationAr: _specializationArController.text.trim().isEmpty ? null : _specializationArController.text.trim(),
        specializationEn: _specializationEnController.text.trim().isEmpty ? null : _specializationEnController.text.trim(),
        qualificationsAr: _qualificationsArController.text.trim().isEmpty ? null : _qualificationsArController.text.trim(),
        qualificationsEn: _qualificationsEnController.text.trim().isEmpty ? null : _qualificationsEnController.text.trim(),
        certificationsAr: _certificationsArController.text.trim().isEmpty ? null : _certificationsArController.text.trim(),
        certificationsEn: _certificationsEnController.text.trim().isEmpty ? null : _certificationsEnController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      );
      if (uid.isNotEmpty) {
        AuditService.log(
          action: 'doctor_invite_sent',
          entityType: 'invite',
          entityId: email,
          userId: uid,
          details: {},
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _error = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addDoctor),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.addDoctorInviteHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(l10n.personalData, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameArController,
                decoration: InputDecoration(labelText: '${l10n.fullNameAr} (${l10n.optional})', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameEnController,
                decoration: InputDecoration(labelText: '${l10n.fullNameEn} (${l10n.optional})', border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: '${l10n.email} (${l10n.required})', border: const OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.email;
                  if (!v.contains('@')) return l10n.authErrorMessage('authErrorInvalidEmail');
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: '${l10n.phone} (${l10n.optional})', border: const OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Text(l10n.doctorProfile, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specializationArController,
                decoration: InputDecoration(labelText: '${l10n.specialization} (AR)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specializationEnController,
                decoration: InputDecoration(labelText: '${l10n.specialization} (EN)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _qualificationsArController,
                decoration: InputDecoration(labelText: '${l10n.qualifications} (AR)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _qualificationsEnController,
                decoration: InputDecoration(labelText: '${l10n.qualifications} (EN)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _certificationsArController,
                decoration: InputDecoration(labelText: '${l10n.certifications} (AR)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _certificationsEnController,
                decoration: InputDecoration(labelText: '${l10n.certifications} (EN)', border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                maxLines: 3,
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
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.sendInvite),
        ),
      ],
    );
  }
}
