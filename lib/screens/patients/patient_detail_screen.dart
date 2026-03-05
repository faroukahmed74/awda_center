import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/package_model.dart';
import '../../models/patient_profile_model.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../core/patient_date_utils.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../appointments/appointment_form_dialog.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'patient_profile_edit_dialog.dart';
import 'patient_document_dialog.dart';
import 'document_viewer.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final FirestoreService _firestore = FirestoreService();
  UserModel? _user;
  PatientProfileModel? _profile;
  List<SessionModel> _sessions = [];
  List<AppointmentModel> _appointmentSessions = [];
  List<PackageModel> _packages = [];
  List<PatientDocumentModel> _documents = [];
  bool _loading = true;
  StreamSubscription<dynamic>? _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _appointmentsSubscription = _firestore
        .appointmentsStream(patientId: widget.patientId)
        .listen((snapshot) {
      if (!mounted) return;
      final list = snapshot.docs
          .map((d) => AppointmentModel.fromFirestore(d))
          .where((a) =>
              a.status == AppointmentStatus.confirmed ||
              a.status == AppointmentStatus.completed)
          .toList();
      list.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      setState(() => _appointmentSessions = list);
    });
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await _firestore.getUser(widget.patientId);
    final profile = await _firestore.getPatientProfile(widget.patientId);
    final sessions = await _firestore.getSessionsForPatient(widget.patientId);
    final appointments = await _firestore.getAppointments(patientId: widget.patientId);
    final packages = await _firestore.getAllPackages();
    final appointmentSessions = appointments
        .where((a) =>
            a.status == AppointmentStatus.confirmed ||
            a.status == AppointmentStatus.completed)
        .toList();
    appointmentSessions.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
    final docs = await _firestore.getPatientDocuments(widget.patientId);
    setState(() {
      _user = user;
      _profile = profile;
      _sessions = sessions;
      _appointmentSessions = appointmentSessions;
      _packages = packages;
      _documents = docs;
      _loading = false;
    });
  }

  /// Package progress for this patient: list of (package, completedCount, totalSessions).
  List<({PackageModel pkg, int completed, int total})> _packageProgress() {
    final out = <({PackageModel pkg, int completed, int total})>[];
    final byPackage = <String, List<AppointmentModel>>{};
    for (final a in _appointmentSessions) {
      if (a.packageId == null || a.packageId!.isEmpty) continue;
      byPackage.putIfAbsent(a.packageId!, () => []).add(a);
    }
    for (final pkg in _packages) {
      final list = byPackage[pkg.id];
      if (list == null) continue;
      final completed = list.where((a) => a.status == AppointmentStatus.completed).length;
      out.add((pkg: pkg, completed: completed, total: pkg.numberOfSessions));
    }
    return out;
  }

  /// Merged session rows: from sessions collection and from confirmed/completed appointments, sorted by date desc.
  List<_SessionRow> _mergedSessionRows(AppLocalizations l10n) {
    final rows = <_SessionRow>[];
    for (final s in _sessions) {
      rows.add(_SessionRow(
        date: s.sessionDate,
        startTime: s.startTime,
        endTime: s.endTime,
        service: s.service,
        statusLabel: null,
      ));
    }
    for (final a in _appointmentSessions) {
      final statusLabel = a.status == AppointmentStatus.confirmed
          ? l10n.confirmed
          : l10n.completed;
      rows.add(_SessionRow(
        date: a.appointmentDate,
        startTime: a.startTime,
        endTime: a.endTime,
        service: a.hasServices ? a.servicesDisplay : null,
        statusLabel: statusLabel,
      ));
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.take(50).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.patientDetail),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/patients'); }),
          actions: [
            if (context.watch<AuthProvider>().currentUser?.canAccessPatients == true)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: l10n.editProfile,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => PatientProfileEditDialog(patientId: widget.patientId, existing: _profile),
                  );
                  if (ok == true && mounted) _load();
                },
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _user == null
                ? Center(child: Text(l10n.noData))
                : SingleChildScrollView(
                    padding: ResponsivePadding.all(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_user!.displayName, style: Theme.of(context).textTheme.titleLarge),
                                if (_user!.email.isNotEmpty) Text(_user!.email, style: Theme.of(context).textTheme.bodyMedium),
                                if (_user!.phone != null && _user!.phone!.isNotEmpty) Text(_user!.phone!, style: Theme.of(context).textTheme.bodyMedium),
                                if (_profile != null) ...[
                                  if (_profile!.dateOfBirth != null) ...[
                                    Text(
                                      () {
                                        final dob = _profile!.dateOfBirth!;
                                        final parsed = parseDateOfBirth(dob);
                                        final dateStr = parsed != null ? DateFormat.yMMMd().format(parsed) : dob;
                                        final age = ageFromDateOfBirth(dob);
                                        return '${l10n.date}: $dateStr${age != null ? ' (${l10n.age}: $age ${l10n.yearsOld})' : ''}';
                                      }(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                  if (_profile!.diagnosis != null) Text('Diagnosis: ${_profile!.diagnosis}', style: Theme.of(context).textTheme.bodySmall),
                                  if (_profile!.medicalHistory != null && _profile!.medicalHistory!.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('${l10n.medicalHistory}: ${_profile!.medicalHistory}', style: Theme.of(context).textTheme.bodySmall)),
                                  if (_profile!.treatmentProgress != null && _profile!.treatmentProgress!.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l10n.treatmentProgress}: ${_profile!.treatmentProgress}', style: Theme.of(context).textTheme.bodySmall)),
                                  if (_profile!.progressNotes != null && _profile!.progressNotes!.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l10n.progressNotes}: ${_profile!.progressNotes}', style: Theme.of(context).textTheme.bodySmall)),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (context.watch<AuthProvider>().currentUser?.canAccessAppointments == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: FilledButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              label: Text(l10n.bookAppointment),
                              onPressed: () async {
                                final cache = context.read<DataCacheProvider>();
                                final currentUserId = context.read<AuthProvider>().currentUser?.id;
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AppointmentFormDialog(
                                    currentUserId: currentUserId,
                                    patients: cache.patients,
                                    doctors: cache.doctors,
                                    rooms: cache.rooms,
                                    services: cache.services,
                                    packages: _packages,
                                    initialPatientId: widget.patientId,
                                  ),
                                );
                                if (ok == true && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.appointmentBooked)),
                                  );
                                  _load();
                                }
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(l10n.packages, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final progress = _packageProgress();
                            if (progress.isEmpty) {
                              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)));
                            }
                            return Column(
                              children: progress.map((e) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.inventory_2_outlined),
                                  title: Text(e.pkg.displayName),
                                  subtitle: Text('${e.completed} / ${e.total} ${l10n.sessions}'),
                                ),
                              )).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(l10n.sessions, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final rows = _mergedSessionRows(l10n);
                            if (rows.isEmpty) {
                              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)));
                            }
                            return Column(
                              children: rows.map((r) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(DateFormat.yMd().format(r.date)),
                                  subtitle: Text([
                                    '${r.startTime} - ${r.endTime}',
                                    if (r.service != null && r.service!.isNotEmpty) r.service,
                                    if (r.statusLabel != null) r.statusLabel,
                                  ].where((e) => e != null && e.isNotEmpty).join(' • ')),
                                ),
                              )).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.documents, style: Theme.of(context).textTheme.titleMedium),
                            if (_canEditDocuments(context))
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 20),
                                label: Text(l10n.notes),
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => PatientDocumentDialog(
                                      patientId: widget.patientId,
                                      currentUserId: context.read<AuthProvider>().currentUser?.id,
                                      canEdit: true,
                                    ),
                                  );
                                  if (ok == true && mounted) _load();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_documents.isEmpty)
                          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                        else
                          ..._documents.take(50).map((d) => _buildDocumentCard(context, d, l10n)),
                      ],
                    ),
                  ),
      ),
    );
  }

  bool _canEditDocuments(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return false;
    return user.canAccessPatients || user.id == widget.patientId;
  }

  Widget _buildDocumentCard(BuildContext context, PatientDocumentModel d, AppLocalizations l10n) {
    final canEdit = _canEditDocuments(context);
    IconData icon = Icons.insert_drive_file;
    if (d.documentType == DocumentType.note) icon = Icons.note;
    if (d.documentType == DocumentType.image) icon = Icons.image;
    if (d.documentType == DocumentType.pdf) icon = Icons.picture_as_pdf;
    final title = d.documentType == DocumentType.note
        ? (d.textContent ?? '').replaceAll('\n', ' ').trim()
        : (d.fileName.isNotEmpty ? d.fileName : d.documentType.value);
    final subtitle = formatDocumentDateTime(d.createdAt, d.updatedAt, l10n);
    final isPdfOrImage = d.documentType == DocumentType.image || d.documentType == DocumentType.pdf;
    final canView = isPdfOrImage && d.filePathOrUrl.trim().isNotEmpty;
    void openOrHint() {
      if (canView) {
        showDocumentViewer(context, d);
      } else if (isPdfOrImage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No link set. Edit the document to add a URL or upload a file.')),
        );
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title.isEmpty ? d.documentType.value : title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall) : null,
        onTap: isPdfOrImage ? openOrHint : null,
        trailing: (canEdit || isPdfOrImage)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPdfOrImage)
                    IconButton(
                      icon: Icon(Icons.open_in_new, size: 22, color: Theme.of(context).colorScheme.primary),
                      tooltip: 'Open',
                      onPressed: openOrHint,
                    ),
                  if (canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => PatientDocumentDialog(
                            patientId: widget.patientId,
                            currentUserId: context.read<AuthProvider>().currentUser?.id,
                            existing: d,
                            canEdit: true,
                          ),
                        );
                        if (ok == true && mounted) _load();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () async {
                        final uid = context.read<AuthProvider>().currentUser?.id;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.deleteConfirm),
                            content: Text('${l10n.documents}: ${d.fileName.isEmpty ? d.id : d.fileName}'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          if (uid != null) {
                            AuditService.log(action: 'patient_document_deleted', entityType: 'patient_document', entityId: d.id, userId: uid, details: {'patientId': widget.patientId, 'fileName': d.fileName});
                          }
                          await _firestore.deletePatientDocument(d.id);
                          _load();
                        }
                      },
                    ),
                  ],
                ],
              )
            : null,
      ),
    );
  }
}

/// One row in the merged Sessions list (from sessions collection or from confirmed/completed appointment).
class _SessionRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;

  _SessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
  });
}
