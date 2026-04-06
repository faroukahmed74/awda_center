import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/date_format.dart';
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../core/patient_date_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';

/// Dialog to add a new patient (creates user + patient_profile in Firestore).
/// Returns the new patient user id on success so caller can navigate to patient detail.
class AddPatientDialog extends StatefulWidget {
  const AddPatientDialog({super.key});

  @override
  State<AddPatientDialog> createState() => _AddPatientDialogState();
}

class _AddPatientDialogState extends State<AddPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameArController = TextEditingController();
  final _fullNameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _dateOfBirth;
  /// Empty string = not selected (avoid nullable [DropdownMenuItem] values — can crash on some devices).
  String _genderValue = '';
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameArController.dispose();
    _fullNameEnController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final nameAr = _fullNameArController.text.trim();
    final nameEn = _fullNameEnController.text.trim();
    if (nameAr.isEmpty && nameEn.isEmpty) {
      setState(() => _error = 'Enter at least one name (Arabic or English).');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ageStr = _ageController.text.trim();
      final ageVal = ageStr.isEmpty ? null : int.tryParse(ageStr);
      final age = ageVal != null && ageVal >= 0 && ageVal <= 150 ? ageVal : null;
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final result = await FirestoreService().createPatientUser(
        fullNameAr: nameAr.isEmpty ? null : nameAr,
        fullNameEn: nameEn.isEmpty ? null : nameEn,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
        dateOfBirth: _dateOfBirth != null ? toIsoDateString(_dateOfBirth!) : null,
        age: age,
        gender: _genderValue.isEmpty ? null : _genderValue,
      );
      if (currentUserId != null) {
        await AuditService.log(
          action: 'patient_created',
          entityType: 'user',
          entityId: result.uid,
          userId: currentUserId,
          details: {},
        );
      }
      if (!mounted) return;
      final email = _emailController.text.trim();
      // Yield so iOS finishes focus/route updates before another dialog + pop (avoids navigator/assert issues).
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      try {
        await _showCredentialsDialog(context, email: email, password: result.password);
      } catch (_) {
        // Still close the form; credentials can be reset via Firebase if needed.
      }
      if (!mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      Navigator.of(context).pop(result.uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
        _loading = false;
      });
    }
  }

  /// Shows a dialog with login credentials so staff can share them with the patient.
  static Future<void> _showCredentialsDialog(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    final l10n = AppLocalizations.of(context);
    final credentialsText = '${l10n.email}: $email\n${l10n.password}: $password';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.patientAdded),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share these login details with the patient so they can sign in. They can change their password in Profile after first login.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(ctx).dividerColor),
                ),
                child: SelectableText(
                  credentialsText,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: credentialsText));
              ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 20),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addNewPatient),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Same fields and order as register form
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.email;
                  if (!v.contains('@')) return l10n.authErrorMessage('authErrorInvalidEmail');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.password;
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameArController,
                decoration: InputDecoration(
                  labelText: l10n.fullNameAr,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameEnController,
                decoration: InputDecoration(
                  labelText: l10n.fullNameEn,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Optional patient profile fields
              Text(
                l10n.personalData,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && mounted) setState(() => _dateOfBirth = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '${l10n.dateOfBirth} (optional)',
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  isEmpty: _dateOfBirth == null,
                  child: Text(
                    _dateOfBirth != null ? AppDateFormat.mediumDate().format(_dateOfBirth!) : '',
                    style: _dateOfBirth != null
                        ? null
                        : TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
              if (_dateOfBirth != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '${l10n.age}: ${ageFromDateOfBirth(toIsoDateString(_dateOfBirth!)) ?? "—"} ${l10n.yearsOld}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.age,
                  hintText: '—',
                  helperText: l10n.ageIfNoDateOfBirth,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // FilterChips instead of DropdownButtonFormField — Dropdown has had iOS assertion/layout crashes in nested dialogs.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.gender} (optional)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('—'),
                          selected: _genderValue.isEmpty,
                          onSelected: (_) => setState(() => _genderValue = ''),
                        ),
                        FilterChip(
                          label: Text(l10n.male),
                          selected: _genderValue == 'male',
                          onSelected: (_) => setState(() => _genderValue = 'male'),
                        ),
                        FilterChip(
                          label: Text(l10n.female),
                          selected: _genderValue == 'female',
                          onSelected: (_) => setState(() => _genderValue = 'female'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
