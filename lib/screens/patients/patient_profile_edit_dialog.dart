import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/patient_date_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../services/firestore_service.dart';

class PatientProfileEditDialog extends StatefulWidget {
  final String patientId;
  final PatientProfileModel? existing;

  const PatientProfileEditDialog({super.key, required this.patientId, this.existing});

  @override
  State<PatientProfileEditDialog> createState() => _PatientProfileEditDialogState();
}

class _PatientProfileEditDialogState extends State<PatientProfileEditDialog> {
  final FirestoreService _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  DateTime? _dateOfBirth;
  String? _gender; // 'male' | 'female' | null
  late TextEditingController _address;
  late TextEditingController _occupation;
  late TextEditingController _referredBy;
  late TextEditingController _maritalStatus;
  late TextEditingController _areasToTreat;
  late TextEditingController _feesType;
  late TextEditingController _diagnosis;
  late TextEditingController _medicalHistory;
  late TextEditingController _treatmentProgress;
  late TextEditingController _progressNotes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _dateOfBirth = e?.dateOfBirth != null ? parseDateOfBirth(e!.dateOfBirth) : null;
    final g = (e?.gender ?? '').trim().toLowerCase();
    _gender = (g == 'male' || g == 'female') ? g : null;
    _address = TextEditingController(text: e?.address ?? '');
    _occupation = TextEditingController(text: e?.occupation ?? '');
    _referredBy = TextEditingController(text: e?.referredBy ?? '');
    _maritalStatus = TextEditingController(text: e?.maritalStatus ?? '');
    _areasToTreat = TextEditingController(text: e?.areasToTreat ?? '');
    _feesType = TextEditingController(text: e?.feesType ?? '');
    _diagnosis = TextEditingController(text: e?.diagnosis ?? '');
    _medicalHistory = TextEditingController(text: e?.medicalHistory ?? '');
    _treatmentProgress = TextEditingController(text: e?.treatmentProgress ?? '');
    _progressNotes = TextEditingController(text: e?.progressNotes ?? '');
  }

  @override
  void dispose() {
    _address.dispose();
    _occupation.dispose();
    _referredBy.dispose();
    _maritalStatus.dispose();
    _areasToTreat.dispose();
    _feesType.dispose();
    _diagnosis.dispose();
    _medicalHistory.dispose();
    _treatmentProgress.dispose();
    _progressNotes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final profile = PatientProfileModel(
      id: widget.patientId,
      userId: widget.patientId,
      dateOfBirth: _dateOfBirth != null ? toIsoDateString(_dateOfBirth!) : null,
      gender: _gender,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      occupation: _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      referredBy: _referredBy.text.trim().isEmpty ? null : _referredBy.text.trim(),
      maritalStatus: _maritalStatus.text.trim().isEmpty ? null : _maritalStatus.text.trim(),
      areasToTreat: _areasToTreat.text.trim().isEmpty ? null : _areasToTreat.text.trim(),
      feesType: _feesType.text.trim().isEmpty ? null : _feesType.text.trim(),
      diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
      medicalHistory: _medicalHistory.text.trim().isEmpty ? null : _medicalHistory.text.trim(),
      treatmentProgress: _treatmentProgress.text.trim().isEmpty ? null : _treatmentProgress.text.trim(),
      progressNotes: _progressNotes.text.trim().isEmpty ? null : _progressNotes.text.trim(),
    );
    await _firestore.savePatientProfile(profile);
    if (mounted) Navigator.of(context).pop(true);
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.createProfile : l10n.editProfile),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    labelText: l10n.dateOfBirth,
                    suffixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                  ),
                  isEmpty: _dateOfBirth == null,
                  child: Text(
                    _dateOfBirth != null ? DateFormat.yMMMd().format(_dateOfBirth!) : '',
                    style: _dateOfBirth != null ? null : TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              ),
              if (_dateOfBirth != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.age}: ${ageFromDateOfBirth(toIsoDateString(_dateOfBirth!)) ?? "—"} ${l10n.yearsOld}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _gender,
                decoration: InputDecoration(
                  labelText: l10n.gender,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text('—')),
                  DropdownMenuItem<String?>(value: 'male', child: Text(l10n.male)),
                  DropdownMenuItem<String?>(value: 'female', child: Text(l10n.female)),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 8),
              TextFormField(controller: _address, decoration: InputDecoration(labelText: l10n.address), maxLines: 2),
              const SizedBox(height: 8),
              TextFormField(controller: _occupation, decoration: InputDecoration(labelText: l10n.occupation)),
              const SizedBox(height: 8),
              TextFormField(controller: _referredBy, decoration: InputDecoration(labelText: l10n.referredBy)),
              const SizedBox(height: 8),
              TextFormField(controller: _maritalStatus, decoration: InputDecoration(labelText: l10n.maritalStatus)),
              const SizedBox(height: 8),
              TextFormField(controller: _areasToTreat, decoration: InputDecoration(labelText: l10n.areasToTreat), maxLines: 2),
              const SizedBox(height: 8),
              TextFormField(controller: _feesType, decoration: InputDecoration(labelText: l10n.feesType)),
              const SizedBox(height: 8),
              TextFormField(controller: _diagnosis, decoration: InputDecoration(labelText: l10n.diagnosis), maxLines: 2),
              const SizedBox(height: 8),
              TextFormField(controller: _medicalHistory, decoration: InputDecoration(labelText: l10n.medicalHistory), maxLines: 3),
              const SizedBox(height: 8),
              TextFormField(controller: _treatmentProgress, decoration: InputDecoration(labelText: l10n.treatmentProgress), maxLines: 3),
              const SizedBox(height: 8),
              TextFormField(controller: _progressNotes, decoration: InputDecoration(labelText: l10n.progressNotes), maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}
