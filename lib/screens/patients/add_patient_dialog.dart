import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
  final _fullNameArController = TextEditingController();
  final _fullNameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender; // 'male' | 'female' | null
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullNameArController.dispose();
    _fullNameEnController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ageStr = _ageController.text.trim();
      final ageVal = ageStr.isEmpty ? null : int.tryParse(ageStr);
      final age = ageVal != null && ageVal >= 0 && ageVal <= 150 ? ageVal : null;
      final uid = await FirestoreService().createPatientUser(
        fullNameAr: nameAr.isEmpty ? null : nameAr,
        fullNameEn: nameEn.isEmpty ? null : nameEn,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        dateOfBirth: _dateOfBirth != null ? toIsoDateString(_dateOfBirth!) : null,
        age: age,
        gender: _gender,
      );
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      if (currentUserId != null) {
        AuditService.log(
          action: 'patient_created',
          entityType: 'user',
          entityId: uid,
          userId: currentUserId,
          details: {},
        );
      }
      if (mounted) Navigator.of(context).pop(uid);
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
      title: Text(l10n.addNewPatient),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _fullNameArController,
                decoration: InputDecoration(
                  labelText: '${l10n.fullNameAr} (${l10n.required})',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameEnController,
                decoration: InputDecoration(
                  labelText: '${l10n.fullNameEn} (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: l10n.phone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: '${l10n.email} (optional)'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@')) return l10n.authErrorMessage('authErrorInvalidEmail');
                  return null;
                },
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
              DropdownButtonFormField<String?>(
                value: _gender,
                decoration: InputDecoration(
                  labelText: '${l10n.gender} (optional)',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text('—')),
                  DropdownMenuItem<String?>(value: 'male', child: Text(l10n.male)),
                  DropdownMenuItem<String?>(value: 'female', child: Text(l10n.female)),
                ],
                onChanged: (v) => setState(() => _gender = v),
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
