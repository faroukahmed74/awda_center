import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';

/// Create or edit an appointment. For edit, pass [existing].
class AppointmentFormDialog extends StatefulWidget {
  final AppointmentModel? existing;
  final String? currentUserId;
  final List<UserModel> patients;
  final List<DoctorModel> doctors;
  final List<RoomModel> rooms;

  const AppointmentFormDialog({
    super.key,
    this.existing,
    this.currentUserId,
    required this.patients,
    required this.doctors,
    required this.rooms,
  });

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  late String? _patientId;
  late String? _doctorId;
  late String? _roomId;
  late DateTime _date;
  late String _startTime;
  late String _endTime;
  late String _service;
  late String _notes;
  double? _costAmount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _patientId = e?.patientId;
    _doctorId = e?.doctorId;
    _roomId = e?.roomId;
    _date = e?.appointmentDate ?? DateTime.now();
    _startTime = e?.startTime ?? '09:00';
    _endTime = e?.endTime ?? '09:30';
    _service = e?.service ?? '';
    _notes = e?.notes ?? '';
    _costAmount = e?.costAmount;
  }

  Future<void> _save() async {
    if (_patientId == null || _patientId!.isEmpty || _doctorId == null || _doctorId!.isEmpty) return;
    setState(() => _saving = true);
    final fs = FirestoreService();
    if (widget.existing != null) {
      await fs.updateAppointment(widget.existing!.id, {
        'patientId': _patientId,
        'doctorId': _doctorId,
        'roomId': _roomId,
        'appointmentDate': _date,
        'startTime': _startTime,
        'endTime': _endTime,
        'service': _service.isEmpty ? null : _service,
        'costAmount': _costAmount,
        'notes': _notes.isEmpty ? null : _notes,
      });
    } else {
      final appointmentId = await fs.createAppointment(AppointmentModel(
        id: '',
        patientId: _patientId!,
        doctorId: _doctorId!,
        roomId: _roomId,
        appointmentDate: _date,
        startTime: _startTime,
        endTime: _endTime,
        service: _service.isEmpty ? null : _service,
        costAmount: _costAmount,
        notes: _notes.isEmpty ? null : _notes,
        createdByUserId: widget.currentUserId,
      ));
      if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
        AuditService.log(
          action: 'appointment_created',
          entityType: 'appointment',
          entityId: appointmentId,
          userId: widget.currentUserId!,
          userEmail: null,
          details: {'patientId': _patientId, 'doctorId': _doctorId},
        );
      }
      // Reschedule reminders so patient and doctor get notification for the new appointment
      NotificationService().rescheduleRemindersForUser(_patientId);
      final doctorDoc = await fs.getDoctorById(_doctorId!);
      if (doctorDoc != null) {
        NotificationService().rescheduleRemindersForUser(doctorDoc.userId);
      }
    }
    if (mounted) Navigator.of(context).pop(true);
    setState(() => _saving = false);
  }

  /// 24-hour time slots (00:00–23:30, every 30 min)
  static List<String> get _timeSlots => List.generate(48, (i) => '${(i ~/ 2).toString().padLeft(2, '0')}:${(i % 2 * 30).toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.editAppointment : l10n.createAppointment),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String?>(
              value: _patientId,
              decoration: InputDecoration(labelText: l10n.patient),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...widget.patients.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName))),
              ],
              onChanged: (v) => setState(() => _patientId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _doctorId,
              decoration: InputDecoration(labelText: l10n.doctor),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...widget.doctors.map((d) => DropdownMenuItem(value: d.id, child: Text(d.displayName ?? d.userId))),
              ],
              onChanged: (v) => setState(() => _doctorId = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _roomId,
              decoration: InputDecoration(labelText: l10n.room),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ...widget.rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.displayName))),
              ],
              onChanged: (v) => setState(() => _roomId = v),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(DateFormat.yMd().format(_date)),
              subtitle: Text(l10n.date),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
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
              onChanged: (v) => _service = v,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _costAmount?.toString(),
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: TextInputType.number,
              onChanged: (v) => _costAmount = double.tryParse(v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _notes,
              decoration: InputDecoration(labelText: l10n.notes),
              maxLines: 2,
              onChanged: (v) => _notes = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save)),
      ],
    );
  }
}
