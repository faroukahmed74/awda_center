import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/patient_date_utils.dart';
import '../../core/responsive.dart';
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
  final TextEditingController _ageController = TextEditingController();
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
  late TextEditingController _chiefComplaint;
  late TextEditingController _painLevel;
  late TextEditingController _treatmentGoals;
  late TextEditingController _contraindications;
  late TextEditingController _previousTreatment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _dateOfBirth = e?.dateOfBirth != null ? parseDateOfBirth(e!.dateOfBirth) : null;
    if (e?.age != null) _ageController.text = e!.age.toString();
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
    _chiefComplaint = TextEditingController(text: e?.chiefComplaint ?? '');
    _painLevel = TextEditingController(text: e?.painLevel ?? '');
    _treatmentGoals = TextEditingController(text: e?.treatmentGoals ?? '');
    _contraindications = TextEditingController(text: e?.contraindications ?? '');
    _previousTreatment = TextEditingController(text: e?.previousTreatment ?? '');
  }

  @override
  void dispose() {
    _ageController.dispose();
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
    _chiefComplaint.dispose();
    _painLevel.dispose();
    _treatmentGoals.dispose();
    _contraindications.dispose();
    _previousTreatment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ageStr = _ageController.text.trim();
    final ageVal = ageStr.isEmpty ? null : int.tryParse(ageStr);
    final age = ageVal != null && ageVal >= 0 && ageVal <= 150 ? ageVal : null;
    final profile = PatientProfileModel(
      id: widget.patientId,
      userId: widget.patientId,
      dateOfBirth: _dateOfBirth != null ? toIsoDateString(_dateOfBirth!) : null,
      age: age,
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
      chiefComplaint: _chiefComplaint.text.trim().isEmpty ? null : _chiefComplaint.text.trim(),
      painLevel: _painLevel.text.trim().isEmpty ? null : _painLevel.text.trim(),
      treatmentGoals: _treatmentGoals.text.trim().isEmpty ? null : _treatmentGoals.text.trim(),
      contraindications: _contraindications.text.trim().isEmpty ? null : _contraindications.text.trim(),
      previousTreatment: _previousTreatment.text.trim().isEmpty ? null : _previousTreatment.text.trim(),
    );
    await _firestore.savePatientProfile(profile);
    if (mounted) Navigator.of(context).pop(true);
    setState(() => _saving = false);
  }

  static const _fieldSpacing = 8.0;

  Widget _buildPersonalColumn(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.personalData, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: _fieldSpacing),
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
        const SizedBox(height: _fieldSpacing),
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
        const SizedBox(height: _fieldSpacing),
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
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _address, decoration: InputDecoration(labelText: l10n.address, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _occupation, decoration: InputDecoration(labelText: l10n.occupation, border: OutlineInputBorder())),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _referredBy, decoration: InputDecoration(labelText: l10n.referredBy, border: OutlineInputBorder())),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _maritalStatus, decoration: InputDecoration(labelText: l10n.maritalStatus, border: OutlineInputBorder())),
      ],
    );
  }

  Widget _buildMedicalColumn(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.medicalDetails, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _chiefComplaint, decoration: InputDecoration(labelText: l10n.chiefComplaint, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _painLevel, decoration: InputDecoration(labelText: l10n.painLevel, border: OutlineInputBorder())),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _areasToTreat, decoration: InputDecoration(labelText: l10n.areasToTreat, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _diagnosis, decoration: InputDecoration(labelText: l10n.diagnosis, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _medicalHistory, decoration: InputDecoration(labelText: l10n.medicalHistory, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _treatmentGoals, decoration: InputDecoration(labelText: l10n.treatmentGoals, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _contraindications, decoration: InputDecoration(labelText: l10n.contraindications, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _previousTreatment, decoration: InputDecoration(labelText: l10n.previousTreatment, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _treatmentProgress, decoration: InputDecoration(labelText: l10n.treatmentProgress, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _progressNotes, decoration: InputDecoration(labelText: l10n.progressNotes, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: _fieldSpacing),
        TextFormField(controller: _feesType, decoration: InputDecoration(labelText: l10n.feesType, border: OutlineInputBorder())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final twoCols = Breakpoint.isTabletOrWider(context);
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.createProfile : l10n.editProfile),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 700),
          child: Form(
            key: _formKey,
            child: twoCols
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPersonalColumn(l10n)),
                      const SizedBox(width: 20),
                      Expanded(child: _buildMedicalColumn(l10n)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPersonalColumn(l10n),
                      const SizedBox(height: 16),
                      _buildMedicalColumn(l10n),
                    ],
                  ),
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
