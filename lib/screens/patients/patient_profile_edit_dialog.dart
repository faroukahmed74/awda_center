import 'package:flutter/material.dart';
import '../../core/date_format.dart';
import '../../core/patient_date_utils.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/medical/medical_rich_text_field.dart';

class PatientProfileEditDialog extends StatefulWidget {
  final String patientId;
  final PatientProfileModel? existing;
  /// When false (e.g. patient editing own profile), only personal fields are shown and editable; medical fields stay unchanged.
  final bool canEditMedical;

  const PatientProfileEditDialog({super.key, required this.patientId, this.existing, this.canEditMedical = true});

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
  late TextEditingController _feesType;
  late TextEditingController _painLevel;

  final _chiefComplaintKey = GlobalKey<MedicalRichTextFieldState>();
  final _areasToTreatKey = GlobalKey<MedicalRichTextFieldState>();
  final _diagnosisKey = GlobalKey<MedicalRichTextFieldState>();
  final _medicalHistoryKey = GlobalKey<MedicalRichTextFieldState>();
  final _treatmentGoalsKey = GlobalKey<MedicalRichTextFieldState>();
  final _contraindicationsKey = GlobalKey<MedicalRichTextFieldState>();
  final _previousTreatmentKey = GlobalKey<MedicalRichTextFieldState>();
  final _treatmentProgressKey = GlobalKey<MedicalRichTextFieldState>();
  final _progressNotesKey = GlobalKey<MedicalRichTextFieldState>();

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
    _feesType = TextEditingController(text: e?.feesType ?? '');
    _painLevel = TextEditingController(text: e?.painLevel ?? '');
  }

  @override
  void dispose() {
    _ageController.dispose();
    _address.dispose();
    _occupation.dispose();
    _referredBy.dispose();
    _maritalStatus.dispose();
    _feesType.dispose();
    _painLevel.dispose();
    super.dispose();
  }

  String? _rich(GlobalKey<MedicalRichTextFieldState> key) =>
      key.currentState?.htmlValue;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ageStr = _ageController.text.trim();
    final ageVal = ageStr.isEmpty ? null : int.tryParse(ageStr);
    final age = ageVal != null && ageVal >= 0 && ageVal <= 150 ? ageVal : null;
    final e = widget.existing;
    final profile = PatientProfileModel(
      id: widget.patientId,
      userId: widget.patientId,
      dateOfBirth: _dateOfBirth != null ? toIsoDateString(_dateOfBirth!) : null,
      age: age,
      gender: _gender,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      occupation: _occupation.text.trim().isEmpty ? null : _occupation.text.trim(),
      referredBy: widget.canEditMedical
          ? (_referredBy.text.trim().isEmpty ? null : _referredBy.text.trim())
          : e?.referredBy,
      maritalStatus:
          _maritalStatus.text.trim().isEmpty ? null : _maritalStatus.text.trim(),
      areasToTreat:
          widget.canEditMedical ? _rich(_areasToTreatKey) : e?.areasToTreat,
      feesType: widget.canEditMedical
          ? (_feesType.text.trim().isEmpty ? null : _feesType.text.trim())
          : e?.feesType,
      diagnosis: widget.canEditMedical ? _rich(_diagnosisKey) : e?.diagnosis,
      followedByDoctorId:
          widget.canEditMedical ? e?.followedByDoctorId : e?.followedByDoctorId,
      medicalHistory:
          widget.canEditMedical ? _rich(_medicalHistoryKey) : e?.medicalHistory,
      treatmentProgress: widget.canEditMedical
          ? _rich(_treatmentProgressKey)
          : e?.treatmentProgress,
      progressNotes:
          widget.canEditMedical ? _rich(_progressNotesKey) : e?.progressNotes,
      chiefComplaint:
          widget.canEditMedical ? _rich(_chiefComplaintKey) : e?.chiefComplaint,
      painLevel: widget.canEditMedical
          ? (_painLevel.text.trim().isEmpty ? null : _painLevel.text.trim())
          : e?.painLevel,
      treatmentGoals:
          widget.canEditMedical ? _rich(_treatmentGoalsKey) : e?.treatmentGoals,
      contraindications: widget.canEditMedical
          ? _rich(_contraindicationsKey)
          : e?.contraindications,
      previousTreatment: widget.canEditMedical
          ? _rich(_previousTreatmentKey)
          : e?.previousTreatment,
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
              initialDate: _dateOfBirth ??
                  DateTime.now().subtract(const Duration(days: 365 * 25)),
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
              _dateOfBirth != null
                  ? AppDateFormat.mediumDate().format(_dateOfBirth!)
                  : '',
              style: _dateOfBirth != null
                  ? null
                  : TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        ),
        if (_dateOfBirth != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${l10n.age}: ${ageFromDateOfBirth(toIsoDateString(_dateOfBirth!)) ?? "—"} ${l10n.yearsOld}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
            DropdownMenuItem<String?>(
                value: 'female', child: Text(l10n.female)),
          ],
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _address,
          decoration: InputDecoration(
            labelText: l10n.address,
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _occupation,
          decoration: InputDecoration(
            labelText: l10n.occupation,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _referredBy,
          decoration: InputDecoration(
            labelText: l10n.referredBy,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _maritalStatus,
          decoration: InputDecoration(
            labelText: l10n.maritalStatus,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalColumn(AppLocalizations l10n) {
    final e = widget.existing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.medicalDetails, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _chiefComplaintKey,
          label: l10n.chiefComplaint,
          initialHtml: e?.chiefComplaint,
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _painLevel,
          decoration: InputDecoration(
            labelText: l10n.painLevel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _areasToTreatKey,
          label: l10n.areasToTreat,
          initialHtml: e?.areasToTreat,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _diagnosisKey,
          label: l10n.diagnosis,
          initialHtml: e?.diagnosis,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _medicalHistoryKey,
          label: l10n.medicalHistory,
          initialHtml: e?.medicalHistory,
          minHeight: 140,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _treatmentGoalsKey,
          label: l10n.treatmentGoals,
          initialHtml: e?.treatmentGoals,
          minHeight: 160,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _contraindicationsKey,
          label: l10n.contraindications,
          initialHtml: e?.contraindications,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _previousTreatmentKey,
          label: l10n.previousTreatment,
          initialHtml: e?.previousTreatment,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _treatmentProgressKey,
          label: l10n.treatmentProgress,
          initialHtml: e?.treatmentProgress,
        ),
        const SizedBox(height: _fieldSpacing),
        MedicalRichTextField(
          key: _progressNotesKey,
          label: l10n.progressNotes,
          initialHtml: e?.progressNotes,
        ),
        const SizedBox(height: _fieldSpacing),
        TextFormField(
          controller: _feesType,
          decoration: InputDecoration(
            labelText: l10n.feesType,
            border: const OutlineInputBorder(),
          ),
        ),
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
            child: widget.canEditMedical
                ? (twoCols
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
                      ))
                : _buildPersonalColumn(l10n),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
