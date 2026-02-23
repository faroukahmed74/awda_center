import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
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
  List<PatientDocumentModel> _documents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final user = await _firestore.getUser(widget.patientId);
    final profile = await _firestore.getPatientProfile(widget.patientId);
    final sessions = await _firestore.getSessionsForPatient(widget.patientId);
    final docs = await _firestore.getPatientDocuments(widget.patientId);
    setState(() {
      _user = user;
      _profile = profile;
      _sessions = sessions;
      _documents = docs;
      _loading = false;
    });
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
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
                                  if (_profile!.dateOfBirth != null) Text('${l10n.date}: ${_profile!.dateOfBirth}', style: Theme.of(context).textTheme.bodySmall),
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
                        const SizedBox(height: 16),
                        Text(l10n.sessions, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_sessions.isEmpty)
                          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                        else
                          ..._sessions.take(30).map((s) => Card(
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
    final canView = (d.documentType == DocumentType.image || d.documentType == DocumentType.pdf) && d.filePathOrUrl.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title.isEmpty ? d.documentType.value : title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: Theme.of(context).textTheme.bodySmall) : null,
        onTap: canView ? () => showDocumentViewer(context, d) : null,
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              )
            : null,
      ),
    );
  }
}
