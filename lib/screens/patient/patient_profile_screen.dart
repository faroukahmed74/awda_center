import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/package_model.dart';
import '../../models/patient_profile_model.dart';
import '../../models/session_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';
import '../../core/date_format.dart';
import '../patients/patient_document_dialog.dart';
import '../patients/document_viewer.dart';
import '../patients/patient_profile_edit_dialog.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  PatientProfileModel? _profile;
  List<SessionModel> _sessions = [];
  List<AppointmentModel> _appointmentSessions = [];
  List<PackageModel> _packages = [];
  List<PatientDocumentModel> _documents = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final uid = context.read<AuthProvider>().currentUser?.id;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'Not signed in';
        });
        return;
      }
      final profile = await _firestore.getPatientProfile(uid);
      List<SessionModel> sessions = [];
      List<PatientDocumentModel> docs = [];
      try {
        sessions = await _firestore.getSessionsForPatient(uid);
      } catch (_) {
        sessions = [];
      }
      List<AppointmentModel> appointmentSessions = [];
      try {
        final appointments = await _firestore.getAppointments(patientId: uid);
        appointmentSessions = appointments
            .where((a) =>
                a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.completed)
            .toList();
        appointmentSessions.sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      } catch (_) {
        appointmentSessions = [];
      }
      try {
        docs = await _firestore.getPatientDocuments(uid);
      } catch (_) {
        docs = [];
      }
      List<PackageModel> packages = [];
      try {
        packages = await _firestore.getAllPackages();
      } catch (_) {
        packages = [];
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _sessions = sessions;
        _appointmentSessions = appointmentSessions;
        _packages = packages;
        _documents = docs;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('PatientProfileScreen _load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
  }

  /// Merged session rows: from sessions collection + confirmed/completed appointments, sorted by date desc.
  List<_SessionDisplayRow> _mergedSessionRows(AppLocalizations l10n) {
    final rows = <_SessionDisplayRow>[];
    for (final s in _sessions) {
      rows.add(_SessionDisplayRow(
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
      rows.add(_SessionDisplayRow(
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
      final ordered = List<AppointmentModel>.from(list)
        ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
      final totalSessions = pkg.numberOfSessions <= 0 ? 1 : pkg.numberOfSessions;
      for (var i = 0; i < ordered.length; i += totalSessions) {
        final end = (i + totalSessions) > ordered.length
            ? ordered.length
            : (i + totalSessions);
        final cycle = ordered.sublist(i, end);
        final completed = cycle
            .where((a) => a.status == AppointmentStatus.completed)
            .length;
        out.add((pkg: pkg, completed: completed, total: totalSessions));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/patients'); }),
          actions: [...MainAppBarActions.notificationsLanguageTheme(context)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: _load,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                padding: ResponsivePadding.all(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_profile == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.createProfile, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(l10n.createProfile),
                                onPressed: () async {
                                  final uid = context.read<AuthProvider>().currentUser?.id;
                                  if (uid == null) return;
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => PatientProfileEditDialog(patientId: uid, existing: null, canEditMedical: false),
                                  );
                                  if (ok == true && mounted) _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.displayName ?? '', style: Theme.of(context).textTheme.titleLarge),
                              if (user?.email != null) Text(user!.email, style: Theme.of(context).textTheme.bodyMedium),
                              if (user?.phone != null && user!.phone!.isNotEmpty) Text(user.phone!, style: Theme.of(context).textTheme.bodyMedium),
                              if (_profile!.dateOfBirth != null) Text('${l10n.date}: ${_profile!.dateOfBirth}', style: Theme.of(context).textTheme.bodySmall),
                              if (_profile!.dateOfBirth == null && _profile!.age != null) Text('${l10n.age}: ${_profile!.age} ${l10n.yearsOld}', style: Theme.of(context).textTheme.bodySmall),
                              if (_profile!.gender != null && _profile!.gender!.isNotEmpty) Text('${l10n.gender}: ${_profile!.gender}', style: Theme.of(context).textTheme.bodySmall),
                              if (_profile!.address != null && _profile!.address!.isNotEmpty) Text('${l10n.address}: ${_profile!.address}', style: Theme.of(context).textTheme.bodySmall),
                              if (_profile!.occupation != null && _profile!.occupation!.isNotEmpty) Text('${l10n.occupation}: ${_profile!.occupation}', style: Theme.of(context).textTheme.bodySmall),
                              if (_profile!.maritalStatus != null && _profile!.maritalStatus!.isNotEmpty) Text('${l10n.maritalStatus}: ${_profile!.maritalStatus}', style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text(l10n.editProfile),
                                onPressed: () async {
                                  final uid = context.read<AuthProvider>().currentUser?.id;
                                  if (uid == null) return;
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => PatientProfileEditDialog(patientId: uid, existing: _profile, canEditMedical: false),
                                  );
                                  if (ok == true && mounted) _load();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(l10n.packages, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final progress = _packageProgress();
                        if (progress.isEmpty)
                          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)));
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
                        if (rows.isEmpty)
                          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)));
                        return Column(
                          children: rows.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(AppDateFormat.shortDate.format(r.date)),
                              subtitle: Text('${r.startTime} - ${r.endTime} ${r.service ?? ''}${r.statusLabel != null ? ' • ${r.statusLabel}' : ''}'),
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
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(l10n.notes),
                          onPressed: () async {
                            final uid = context.read<AuthProvider>().currentUser?.id;
                            if (uid == null) return;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => PatientDocumentDialog(
                                patientId: uid,
                                currentUserId: uid,
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
                      ..._documents.take(50).map((d) => _docCard(context, d, l10n)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _docCard(BuildContext context, PatientDocumentModel d, AppLocalizations l10n) {
    IconData icon = Icons.insert_drive_file;
    if (d.documentType == DocumentType.note) icon = Icons.note;
    if (d.documentType == DocumentType.image) icon = Icons.image;
    if (d.documentType == DocumentType.pdf) icon = Icons.picture_as_pdf;
    final title = d.documentType == DocumentType.note
        ? (d.textContent ?? '').replaceAll('\n', ' ').trim()
        : (d.fileName.isNotEmpty ? d.fileName : d.documentType.value);
    final subtitle = formatDocumentDateTime(d.createdAt, d.updatedAt, l10n);
    final uid = context.read<AuthProvider>().currentUser?.id ?? '';
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPdfOrImage)
              IconButton(
                icon: Icon(Icons.open_in_new, size: 22, color: Theme.of(context).colorScheme.primary),
                tooltip: 'Open',
                onPressed: openOrHint,
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => PatientDocumentDialog(patientId: uid, currentUserId: uid, existing: d, canEdit: true),
                );
                if (ok == true && mounted) _load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteConfirm),
                    content: Text('${l10n.documents}: ${d.fileName.isNotEmpty ? d.fileName : d.id}'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  if (uid.isNotEmpty) {
                    AuditService.log(action: 'patient_document_deleted', entityType: 'patient_document', entityId: d.id, userId: uid, details: {'patientId': uid, 'fileName': d.fileName});
                  }
                  await _firestore.deletePatientDocument(d.id);
                  _load();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDisplayRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;

  _SessionDisplayRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
  });
}
