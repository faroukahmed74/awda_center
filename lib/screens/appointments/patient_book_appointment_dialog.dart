import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';

/// Lets a patient book an appointment (reserve a session/examination) for themselves.
class PatientBookAppointmentDialog extends StatefulWidget {
  final String patientId;

  const PatientBookAppointmentDialog({super.key, required this.patientId});

  @override
  State<PatientBookAppointmentDialog> createState() => _PatientBookAppointmentDialogState();
}

class _PatientBookAppointmentDialogState extends State<PatientBookAppointmentDialog> {
  final FirestoreService _firestore = FirestoreService();
  List<DoctorModel> _doctors = [];
  bool _loadingDoctors = true;
  String? _doctorId;
  DateTime _date = DateTime.now();
  String _startTime = '09:00';
  String _endTime = '09:30';
  String _service = '';
  String _notes = '';
  bool _saving = false;
  String? _errorMessage;

  /// 24-hour time slots (00:00–23:30, every 30 min)
  static List<String> get _timeSlots => List.generate(48, (i) => '${(i ~/ 2).toString().padLeft(2, '0')}:${(i % 2 * 30).toString().padLeft(2, '0')}');

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      final list = await _firestore.getDoctors();
      if (!mounted) return;
      setState(() {
        _doctors = list;
        _loadingDoctors = false;
        if (list.isNotEmpty && _doctorId == null) _doctorId = list.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDoctors = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
  }

  Future<void> _save() async {
    if (_doctorId == null || _doctorId!.isEmpty) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final appointmentId = await _firestore.createAppointment(AppointmentModel(
        id: '',
        patientId: widget.patientId,
        doctorId: _doctorId!,
        roomId: null,
        appointmentDate: _date,
        startTime: _startTime,
        endTime: _endTime,
        status: AppointmentStatus.pending,
        services: _service.isEmpty ? const [] : [_service],
        costAmount: null,
        notes: _notes.isEmpty ? null : _notes,
        createdByUserId: widget.patientId,
      ));
      if (!mounted) return;
      final currentUser = context.read<AuthProvider>().currentUser;
      AuditService.log(
        action: 'appointment_created',
        entityType: 'appointment',
        entityId: appointmentId,
        userId: currentUser?.id ?? widget.patientId,
        userEmail: currentUser?.email,
        details: {'patientId': widget.patientId, 'doctorId': _doctorId},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.bookAppointment),
      content: SingleChildScrollView(
        child: _loadingDoctors
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            : _doctors.isEmpty
                ? Text(l10n.noData)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _doctors.any((d) => d.id == _doctorId) ? _doctorId : _doctors.first.id,
                        decoration: InputDecoration(labelText: l10n.doctor),
                        items: _doctors
                            .map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.displayName ?? d.userId),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _doctorId = v),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        title: Text(DateFormat.yMd().format(_date)),
                        subtitle: Text(l10n.date),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${l10n.time} (start)', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _timeSlots.contains(_startTime) ? _startTime : _timeSlots.first,
                                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (v) => setState(() => _startTime = v ?? _startTime),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('${l10n.time} (end)', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _timeSlots.contains(_endTime) ? _endTime : _timeSlots[1],
                                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                  items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (v) => setState(() => _endTime = v ?? _endTime),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _service,
                        decoration: InputDecoration(labelText: l10n.service),
                        maxLines: 1,
                        onChanged: (v) => _service = v,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _notes,
                        decoration: InputDecoration(labelText: l10n.notes),
                        maxLines: 2,
                        onChanged: (v) => _notes = v,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                      ],
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: (_saving || _loadingDoctors || _doctors.isEmpty) ? null : _save,
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}
