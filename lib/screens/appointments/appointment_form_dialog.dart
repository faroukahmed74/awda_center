import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/room_model.dart';
import '../../models/package_model.dart';
import '../../models/service_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';

/// Create or edit an appointment. For edit, pass [existing].
/// When creating, [initialPatientId] pre-selects the patient (e.g. when opened from patient detail).
class AppointmentFormDialog extends StatefulWidget {
  final AppointmentModel? existing;
  final String? currentUserId;
  final List<UserModel> patients;
  final List<DoctorModel> doctors;
  final List<RoomModel> rooms;
  final List<ServiceModel> services;
  final List<PackageModel> packages;
  final String? initialPatientId;
  final DateTime? initialDate;
  final String? initialStartTime;
  final String? initialEndTime;
  final bool? initialIsExtraSlot;

  const AppointmentFormDialog({
    super.key,
    this.existing,
    this.currentUserId,
    required this.patients,
    required this.doctors,
    required this.rooms,
    required this.services,
    this.packages = const [],
    this.initialPatientId,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
    this.initialIsExtraSlot,
  });

  @override
  State<AppointmentFormDialog> createState() => _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<AppointmentFormDialog> {
  late String? _patientId;
  late String? _doctorId;
  late String? _roomId;
  late List<String> _selectedServiceIds; // multiple service ids; display names saved to appointment.services
  late DateTime _date;
  late String _startTime;
  late String _endTime;
  late String _notes;
  double? _costAmount;
  bool _saving = false;
  bool _isExtraSlot = false;
  bool _isStarred = false;
  String? _selectedPackageId;
  String? _errorMessage;
  final _patientSearchController = TextEditingController();
  final _amountController = TextEditingController();

  /// Amount to save (discount is set in session payment dialog, not here).
  double? get _savedAmount => _costAmount ?? double.tryParse(_amountController.text.trim());

  /// Auto-fill amount from selected package or sum of selected services.
  void _updateAmountFromSelection() {
    if (_selectedPackageId != null) {
      for (final p in widget.packages) {
        if (p.id == _selectedPackageId) {
          _costAmount = p.amount > 0 ? p.amount : null;
          break;
        }
      }
    } else {
      final sum = ServiceModel.totalAmountForIds(_selectedServiceIds, widget.services);
      _costAmount = sum > 0 ? sum : null;
    }
    _amountController.text = _costAmount != null ? _costAmount!.toStringAsFixed(2) : '';
  }

  List<String> get _selectedServicesDisplayNames {
    final names = <String>[];
    for (final id in _selectedServiceIds) {
      for (final s in widget.services) if (s.id == id) { names.add(s.displayName); break; }
    }
    return names;
  }

  /// Patients filtered by name, email, phone, or patient code (partial, case-insensitive).
  List<UserModel> get _filteredPatients {
    final q = _patientSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.patients;
    return widget.patients.where((p) {
      final name = p.displayName.toLowerCase();
      final email = p.email.toLowerCase();
      final phone = (p.phone ?? '').toLowerCase();
      final code = (p.patientCode ?? '').toLowerCase();
      return name.contains(q) || email.contains(q) || phone.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _patientId = e?.patientId ?? widget.initialPatientId;
    _doctorId = e?.doctorId;
    _roomId = e?.roomId;
    _date = e?.appointmentDate ?? widget.initialDate ?? DateTime.now();
    _startTime = e?.startTime ?? widget.initialStartTime ?? '12:00';
    _endTime = e?.endTime ?? widget.initialEndTime ?? '12:30';
    _isExtraSlot = e?.isExtraSlot ?? widget.initialIsExtraSlot ?? false;
    _isStarred = e?.isStarred ?? false;
    _selectedServiceIds = [];
    if (e != null && e.services.isNotEmpty) {
      for (final name in e.services) {
        for (final s in widget.services) {
          if (s.displayName == name) {
            _selectedServiceIds.add(s.id);
            break;
          }
        }
      }
    }
    _notes = e?.notes ?? '';
    _costAmount = e?.costAmount;
    _selectedPackageId = e?.packageId;
    if (e != null && e.packageId != null && _selectedServiceIds.isEmpty && widget.packages.isNotEmpty) {
      for (final p in widget.packages) {
        if (p.id == e.packageId) {
          _selectedServiceIds = List<String>.from(p.serviceIds);
          break;
        }
      }
    }
    if (e != null) {
      _amountController.text = _costAmount != null ? _costAmount!.toStringAsFixed(2) : '';
    } else {
      _updateAmountFromSelection();
    }
  }

  @override
  void dispose() {
    _patientSearchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Minutes since midnight for "HH:mm" (e.g. "09:30" -> 570).
  static int _minutesOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].trim()) ?? 0;
    return h * 60 + m;
  }

  /// True if [start1, end1] and [start2, end2] overlap (any time in common).
  static bool _timeRangesOverlap(String start1, String end1, String start2, String end2) {
    final s1 = _minutesOfDay(start1), e1 = _minutesOfDay(end1);
    final s2 = _minutesOfDay(start2), e2 = _minutesOfDay(end2);
    return s1 < e2 && s2 < e1;
  }

  Future<void> _save() async {
    if (_patientId == null || _patientId!.isEmpty || _doctorId == null || _doctorId!.isEmpty) return;
    setState(() => _saving = true);
    final fs = FirestoreService();
    final dayStart = DateTime(_date.year, _date.month, _date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final range = await fs.getAppointments(from: dayStart, to: dayEnd);

    // Room conflict: same date, same room, overlapping session time (all time between start and end)
    if (_roomId != null && _roomId!.trim().isNotEmpty) {
      final sameRoom = range
          .where((a) =>
              a.roomId == _roomId &&
              a.status != AppointmentStatus.cancelled &&
              a.id != (widget.existing?.id ?? ''))
          .toList();
      final hasOverlap = sameRoom.any((a) => _timeRangesOverlap(a.startTime, a.endTime, _startTime, _endTime));
      if (hasOverlap && mounted) {
        setState(() {
          _saving = false;
          _errorMessage = AppLocalizations.of(context).roomTimeConflict;
        });
        return;
      }
    }

    // Slot limit: max 3 main + 1 extra per (date, startTime)
    if (widget.existing == null) {
      final sameSlot = range.where((a) => a.startTime == _startTime && a.status != AppointmentStatus.cancelled).toList();
      final mainCount = sameSlot.where((a) => !a.isExtraSlot).length;
      final extraCount = sameSlot.where((a) => a.isExtraSlot).length;
      if (!_isExtraSlot && mainCount >= 3) {
        if (mounted) {
          setState(() {
            _saving = false;
            _errorMessage = AppLocalizations.of(context).slotFull;
          });
          return;
        }
      }
      if (_isExtraSlot && extraCount >= 1) {
        if (mounted) {
          setState(() {
            _saving = false;
            _errorMessage = AppLocalizations.of(context).slotFull;
          });
          return;
        }
      }
    }

    _errorMessage = null;
    if (widget.existing != null) {
      await fs.updateAppointment(widget.existing!.id, {
        'patientId': _patientId,
        'doctorId': _doctorId,
        'roomId': _roomId,
        'appointmentDate': _date,
        'startTime': _startTime,
        'endTime': _endTime,
        'services': _selectedServicesDisplayNames,
        'costAmount': _savedAmount,
        'discountPercent': null,
        'notes': _notes.isEmpty ? null : _notes,
        'isExtraSlot': _isExtraSlot,
        'isStarred': _isStarred,
        'packageId': _selectedPackageId,
      });
    } else {
      final currentUser = context.read<AuthProvider>().currentUser;
      final isPatient = currentUser?.hasRole(UserRole.patient) ?? true;
      final initialStatus = isPatient ? AppointmentStatus.pending : AppointmentStatus.confirmed;
      final appointmentId = await fs.createAppointment(AppointmentModel(
        id: '',
        patientId: _patientId!,
        doctorId: _doctorId!,
        roomId: _roomId,
        appointmentDate: _date,
        startTime: _startTime,
        endTime: _endTime,
        status: initialStatus,
        services: _selectedServicesDisplayNames,
        costAmount: _savedAmount,
        discountPercent: null,
        notes: _notes.isEmpty ? null : _notes,
        isExtraSlot: _isExtraSlot,
        isStarred: _isStarred,
        packageId: _selectedPackageId,
        createdByUserId: widget.currentUserId,
      ));
      if (widget.currentUserId != null && widget.currentUserId!.isNotEmpty) {
        AuditService.log(
          action: 'appointment_created',
          entityType: 'appointment',
          entityId: appointmentId,
          userId: widget.currentUserId!,
          userEmail: null,
          details: {
            'patientId': _patientId,
            'doctorId': _doctorId,
            if (widget.initialPatientId != null) 'fromPatientDetail': true,
          },
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

  /// Center hours 12 PM–12 AM (midnight). Every 30 min: 12:00–23:30.
  static List<String> get _timeSlots => List.generate(24, (i) => '${(12 + (i ~/ 2)).toString().padLeft(2, '0')}:${(i % 2 * 30).toString().padLeft(2, '0')}');

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
            TextField(
              controller: _patientSearchController,
              decoration: InputDecoration(
                labelText: l10n.patient,
                hintText: l10n.searchByPatientCodeHint,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final list = List<UserModel>.from(_filteredPatients);
                if (_patientId != null && !list.any((p) => p.id == _patientId)) {
                  final found = widget.patients.where((p) => p.id == _patientId).toList();
                  if (found.isNotEmpty) list.insert(0, found.first);
                }
                return DropdownButtonFormField<String?>(
                  value: _patientId,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ...list.map((p) {
                      var parts = <String>[];
                      if (p.patientCode != null && p.patientCode!.isNotEmpty) parts.add(p.patientCode!);
                      if (p.phone != null && p.phone!.isNotEmpty) parts.add(p.phone!);
                      final subtitle = parts.isEmpty ? '' : ' • ${parts.join(' • ')}';
                      return DropdownMenuItem(value: p.id, child: Text('${p.displayName}$subtitle'));
                    }),
                  ],
                  onChanged: (v) => setState(() => _patientId = v),
                );
              },
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
              onChanged: (v) => setState(() { _roomId = v; _errorMessage = null; }),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(AppDateFormat.shortDate.format(_date)),
              subtitle: Text(l10n.date),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  selectableDayPredicate: (day) => day.weekday != DateTime.friday,
                );
                if (d != null) setState(() { _date = d; _errorMessage = null; });
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
                        onChanged: (v) => setState(() { _startTime = v ?? _startTime; _errorMessage = null; }),
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
                        onChanged: (v) => setState(() { _endTime = v ?? _endTime; _errorMessage = null; }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.packages.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _selectedPackageId,
                decoration: InputDecoration(labelText: l10n.linkToPackageOptional),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  ...widget.packages.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.displayName} (${p.numberOfSessions} ${l10n.sessions})'))),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedPackageId = v;
                    if (v != null) {
                      for (final p in widget.packages) {
                        if (p.id == v) {
                          _selectedServiceIds = List<String>.from(p.serviceIds);
                          break;
                        }
                      }
                    }
                    _updateAmountFromSelection();
                  });
                },
              ),
            ],
            const SizedBox(height: 8),
            Text(l10n.service, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._selectedServiceIds.map((id) {
                  String? name;
                  for (final s in widget.services) if (s.id == id) { name = s.displayName; break; }
                  return Chip(
                    label: Text(name ?? id),
                    onDeleted: () => setState(() {
                      _selectedServiceIds = List.from(_selectedServiceIds)..remove(id);
                      _updateAmountFromSelection();
                    }),
                  );
                }),
                Builder(
                  builder: (context) {
                    final available = widget.services.where((s) => !_selectedServiceIds.contains(s.id)).toList();
                    if (available.isEmpty) return const SizedBox.shrink();
                    return InputDecorator(
                      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: null,
                          isExpanded: true,
                          hint: Text(l10n.service, style: Theme.of(context).textTheme.bodyMedium),
                          items: available.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.displayName))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() {
                              _selectedServiceIds = List.from(_selectedServiceIds)..add(v);
                              _updateAmountFromSelection();
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (context.watch<AuthProvider>().currentUser?.canAccessAppointments == true)
              CheckboxListTile(
                title: Text(l10n.extraSlot),
                value: _isExtraSlot,
                onChanged: (v) => setState(() => _isExtraSlot = v ?? false),
              ),
            CheckboxListTile(
              title: Row(
                children: [
                  Icon(Icons.star, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(l10n.starredSessionVip),
                ],
              ),
              value: _isStarred,
              onChanged: (v) => setState(() => _isStarred = v ?? false),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: l10n.amount),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _costAmount = double.tryParse(v);
                setState(() {});
              },
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
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l10n.cancel)),
                FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.save)),
              ],
            ),
            if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
