import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../models/session_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
      try {
        docs = await _firestore.getPatientDocuments(uid);
      } catch (_) {
        docs = [];
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _sessions = sessions;
        _documents = docs;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('PatientProfileScreen _load error: $e\n$st');
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
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
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
                                    builder: (_) => PatientProfileEditDialog(patientId: uid, existing: null),
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
                    if (_sessions.isEmpty)
                      Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                    else
                      ..._sessions.take(20).map((s) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(DateFormat.yMd().format(s.sessionDate)),
                              subtitle: Text('${s.startTime} - ${s.endTime} ${s.service ?? ''}'),
                            ),
                          )),
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
