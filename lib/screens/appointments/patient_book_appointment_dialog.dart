import 'package:flutter/material.dart';
import '../../core/date_format.dart';
import 'package:provider/provider.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/package_model.dart';
import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';

/// Lets a patient book an appointment (reserve a session/examination) for themselves.
/// Shows services and packages; prevents booking when the doctor already has an appointment at the chosen date/time.
class PatientBookAppointmentDialog extends StatefulWidget {
  final String patientId;

  const PatientBookAppointmentDialog({super.key, required this.patientId});

  @override
  State<PatientBookAppointmentDialog> createState() => _PatientBookAppointmentDialogState();
}

class _PatientBookAppointmentDialogState extends State<PatientBookAppointmentDialog> {
  final FirestoreService _firestore = FirestoreService();
  List<DoctorModel> _doctors = [];
  List<ServiceModel> _services = [];
  List<PackageModel> _packages = [];
  bool _loadingDoctors = true;
  String? _doctorId;
  DateTime _date = DateTime.now();
  String _startTime = '09:00';
  String _endTime = '09:30';
  List<String> _selectedServiceIds = [];
  String? _packageId;
  String _notes = '';
  bool _saving = false;
  String? _errorMessage;

  /// 24-hour time slots (00:00–23:30, every 30 min)
  static List<String> get _timeSlots => List.generate(48, (i) => '${(i ~/ 2).toString().padLeft(2, '0')}:${(i % 2 * 30).toString().padLeft(2, '0')}');

  static int _minutesOfDay(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return h * 60 + m;
  }

  static bool _timeRangesOverlap(String start1, String end1, String start2, String end2) {
    final s1 = _minutesOfDay(start1), e1 = _minutesOfDay(end1);
    final s2 = _minutesOfDay(start2), e2 = _minutesOfDay(end2);
    return s1 < e2 && s2 < e1;
  }

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadServicesAndPackages();
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

  Future<void> _loadServicesAndPackages() async {
    try {
      final services = await _firestore.getServices();
      final packages = await _firestore.getAllPackages();
      if (!mounted) return;
      setState(() {
        _services = services.where((s) => s.isActive).toList();
        _packages = packages.where((p) => p.isActive).toList();
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_doctorId == null || _doctorId!.isEmpty) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final dayStart = DateTime(_date.year, _date.month, _date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    try {
      final existing = await _firestore.getAppointments(doctorId: _doctorId, from: dayStart, to: dayEnd);
      final conflicting = existing
          .where((a) => a.status != AppointmentStatus.cancelled)
          .where((a) => _timeRangesOverlap(a.startTime, a.endTime, _startTime, _endTime))
          .toList();
      if (conflicting.isNotEmpty && mounted) {
        setState(() {
          _saving = false;
          _errorMessage = AppLocalizations.of(context).doctorTimeConflict;
        });
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return;
    }

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
        services: _selectedServiceIds,
        costAmount: null,
        notes: _notes.isEmpty ? null : _notes,
        packageId: _packageId?.isEmpty == true ? null : _packageId,
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
                        title: Text(AppDateFormat.shortDate.format(_date)),
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
                      const SizedBox(height: 12),
                      Text(l10n.services, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      if (_services.isEmpty)
                        Text(l10n.noData, style: Theme.of(context).textTheme.bodySmall)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _services.map((s) {
                            final selected = _selectedServiceIds.contains(s.id);
                            return FilterChip(
                              label: Text(s.displayName),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedServiceIds = List.from(_selectedServiceIds)..add(s.id);
                                  } else {
                                    _selectedServiceIds = _selectedServiceIds.where((id) => id != s.id).toList();
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 12),
                      Text(l10n.packages, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String?>(
                        value: _packageId,
                        decoration: InputDecoration(
                          labelText: l10n.packages,
                          hintText: '—',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('—')),
                          ..._packages.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.displayName))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _packageId = v;
                            if (v != null) {
                              final pkg = _packages.firstWhere((p) => p.id == v, orElse: () => _packages.first);
                              _selectedServiceIds = List.from(pkg.serviceIds);
                            }
                          });
                        },
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
