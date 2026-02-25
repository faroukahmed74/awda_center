import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/patient_profile_model.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../patients/patient_document_dialog.dart';
import '../patients/document_viewer.dart';
import '../patients/patient_profile_edit_dialog.dart';
import 'edit_my_info_dialog.dart';
import 'change_password_dialog.dart';

/// Unified profile screen for all users: personal data + role-specific content (patient: medical/sessions/documents; doctor: link to doctor profile).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestore = FirestoreService();
  PatientProfileModel? _profile;
  List<SessionModel> _sessions = [];
  List<AppointmentModel> _appointmentSessions = [];
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
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Not signed in';
      });
      return;
    }
    try {
      if (user.hasRole(UserRole.patient)) {
        final profile = await _firestore.getPatientProfile(user.id);
        List<SessionModel> sessions = [];
        List<AppointmentModel> appointmentSessions = [];
        List<PatientDocumentModel> docs = [];
        try {
          sessions = await _firestore.getSessionsForPatient(user.id);
        } catch (_) {
          sessions = [];
        }
        try {
          final appointments = await _firestore.getAppointments(patientId: user.id);
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
          docs = await _firestore.getPatientDocuments(user.id);
        } catch (_) {
          docs = [];
        }
        if (!mounted) return;
        setState(() {
          _profile = profile;
          _sessions = sessions;
          _appointmentSessions = appointmentSessions;
          _documents = docs;
        });
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('ProfileScreen _load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().currentUser;
    final canChangePassword = context.watch<AuthProvider>().canChangePassword;
    final isRtl = l10n.isArabic;

    if (user == null) {
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.profile), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); })),
          body: const Center(child: Text('Not signed in')),
        ),
      );
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editMyInfo,
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => EditMyInfoDialog(user: user));
                if (ok == true && mounted) setState(() {});
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: ResponsivePadding.all(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Personal data card (all users)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.personalData, style: Theme.of(context).textTheme.titleMedium),
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(l10n.editMyInfo),
                            onPressed: () async {
                              final ok = await showDialog<bool>(context: context, builder: (_) => EditMyInfoDialog(user: user));
                              if (ok == true && mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(user.displayName, style: Theme.of(context).textTheme.titleLarge),
                      if (user.fullNameAr != null && user.fullNameAr!.isNotEmpty) Text('${l10n.fullNameAr}: ${user.fullNameAr}', style: Theme.of(context).textTheme.bodyMedium),
                      if (user.fullNameEn != null && user.fullNameEn!.isNotEmpty) Text('${l10n.fullNameEn}: ${user.fullNameEn}', style: Theme.of(context).textTheme.bodyMedium),
                      Text('${l10n.email}: ${user.email}', style: Theme.of(context).textTheme.bodyMedium),
                      if (user.phone != null && user.phone!.isNotEmpty) Text('${l10n.phone}: ${user.phone}', style: Theme.of(context).textTheme.bodyMedium),
                      Text('${l10n.role}: ${user.roles.map((r) => l10n.roleDisplay(r)).join(", ")}', style: Theme.of(context).textTheme.bodySmall),
                      Text(user.isActive ? l10n.active : l10n.inactive, style: Theme.of(context).textTheme.bodySmall),
                      if (canChangePassword) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.lock_outline, size: 20),
                          label: Text(l10n.changePassword),
                          onPressed: () async {
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => const ChangePasswordDialog(),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Doctor: link to my doctor profile
              if (user.hasRole(UserRole.doctor)) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.medical_services_outlined),
                    title: Text(l10n.myDoctorProfile),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/my-doctor-profile'),
                  ),
                ),
              ],
              // Patient: medical profile, sessions, documents
              if (user.hasRole(UserRole.patient)) ...[
                const SizedBox(height: 16),
                _loading
                    ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
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
                                  FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
                                ],
                              ),
                            ),
                          )
                        : _patientSection(context, user.id, l10n),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _patientSection(BuildContext context, String uid, AppLocalizations l10n) {
    return Column(
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
                      final ok = await showDialog<bool>(context: context, builder: (_) => PatientProfileEditDialog(patientId: uid, existing: null));
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
                  if (_profile!.dateOfBirth != null) Text('${l10n.date}: ${_profile!.dateOfBirth}', style: Theme.of(context).textTheme.bodySmall),
                  if (_profile!.diagnosis != null) Text('Diagnosis: ${_profile!.diagnosis}', style: Theme.of(context).textTheme.bodySmall),
                  if (_profile!.medicalHistory != null && _profile!.medicalHistory!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('${l10n.medicalHistory}: ${_profile!.medicalHistory}', style: Theme.of(context).textTheme.bodySmall)),
                  if (_profile!.treatmentProgress != null && _profile!.treatmentProgress!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l10n.treatmentProgress}: ${_profile!.treatmentProgress}', style: Theme.of(context).textTheme.bodySmall)),
                  if (_profile!.progressNotes != null && _profile!.progressNotes!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('${l10n.progressNotes}: ${_profile!.progressNotes}', style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
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
                  title: Text(DateFormat.yMd().format(r.date)),
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
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => PatientDocumentDialog(patientId: uid, currentUserId: uid, canEdit: true),
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
          ..._documents.take(50).map((d) => _docCard(context, d, l10n, uid)),
      ],
    );
  }

  /// Merged session rows: from sessions collection + confirmed/completed appointments, sorted by date desc.
  List<_ProfileSessionRow> _mergedSessionRows(AppLocalizations l10n) {
    final rows = <_ProfileSessionRow>[];
    for (final s in _sessions) {
      rows.add(_ProfileSessionRow(
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
      rows.add(_ProfileSessionRow(
        date: a.appointmentDate,
        startTime: a.startTime,
        endTime: a.endTime,
        service: a.service,
        statusLabel: statusLabel,
      ));
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.take(50).toList();
  }

  Widget _docCard(BuildContext context, PatientDocumentModel d, AppLocalizations l10n, String uid) {
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

class _ProfileSessionRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;

  _ProfileSessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
  });
}
