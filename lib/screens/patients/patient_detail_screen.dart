import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/income_expense_models.dart';
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
import '../../core/date_format.dart';
import 'patient_profile_edit_dialog.dart';
import 'patient_document_dialog.dart';
import 'document_viewer.dart';
import 'patient_report_pdf.dart';
import '../reports/report_pdf_share.dart';

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
  List<IncomeRecordModel> _incomeRecords = [];
  List<AppointmentModel> _appointmentSessions = [];
  List<PackageModel> _packages = [];
  List<PatientDocumentModel> _documents = [];
  bool _loading = true;
  StreamSubscription<dynamic>? _appointmentsSubscription;

  Rect? _sharePositionOriginFromContext() {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.width > 0 &&
        renderObject.size.height > 0) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    final size = MediaQuery.maybeSizeOf(context);
    if (size != null && size.width > 0 && size.height > 0) {
      return Rect.fromLTWH(0, 0, size.width, size.height);
    }
    return null;
  }

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
    try {
      final auth = context.read<AuthProvider>().currentUser;
      final canReadFinance = auth?.canAccessIncomeExpenses == true;

      final user = await _firestore.getUser(widget.patientId);
      final profile = await _firestore.getPatientProfile(widget.patientId);
      final sessions = await _firestore.getSessionsForPatient(widget.patientId);
      final incomeRecords = canReadFinance
          ? await _firestore.getIncomeRecordsForPatient(widget.patientId)
          : <IncomeRecordModel>[];
      final appointments = await _firestore.getAppointments(patientId: widget.patientId);
      final packages = await _firestore.getAllPackages();
      final appointmentSessions = List<AppointmentModel>.from(appointments)
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));
      final docs = await _firestore.getPatientDocuments(widget.patientId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _profile = profile;
        _sessions = sessions;
        _incomeRecords = incomeRecords;
        _appointmentSessions = appointmentSessions;
        _packages = packages;
        _documents = docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).generalErrorMessage('errorLoadFailed'))),
      );
    }
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

  /// Merged session rows: from sessions collection and from all appointments, sorted by date desc. Status reflects current appointment status.
  List<_SessionRow> _mergedSessionRows(
    AppLocalizations l10n,
    DataCacheProvider cache,
  ) {
    final rows = <_SessionRow>[];
    final paymentByAppointmentId = <String, String?>{
      for (final r in _incomeRecords)
        if (r.appointmentId != null && r.appointmentId!.isNotEmpty)
          r.appointmentId!: r.sessionPaymentStatus,
    };
    final paymentAmountByAppointmentId = <String, double>{
      for (final r in _incomeRecords)
        if (r.appointmentId != null &&
            r.appointmentId!.isNotEmpty &&
            r.amount.isFinite)
          r.appointmentId!: r.amount,
    };
    for (final s in _sessions) {
      rows.add(_SessionRow(
        date: s.sessionDate,
        startTime: s.startTime,
        endTime: s.endTime,
        service: s.service,
        doctorLabel: s.doctorId.isEmpty
            ? null
            : '${l10n.doctor}: ${cache.doctorDisplayName(s.doctorId) ?? cache.userName(s.doctorId) ?? s.doctorId}',
        statusLabel: null,
        paymentStatusLabel: _paymentStatusLabel(
          s.appointmentId == null ? null : paymentByAppointmentId[s.appointmentId!],
          l10n,
        ),
        paymentAmountLabel: s.appointmentId == null
            ? null
            : _paymentAmountLabel(paymentAmountByAppointmentId[s.appointmentId!]),
      ));
    }
    for (final a in _appointmentSessions) {
      final statusLabel = _appointmentStatusLabel(a.status, l10n);
      rows.add(_SessionRow(
        date: a.appointmentDate,
        startTime: a.startTime,
        endTime: a.endTime,
        service: a.hasServices ? a.servicesDisplay : null,
        doctorLabel:
            '${l10n.doctor}: ${cache.doctorDisplayName(a.doctorId) ?? cache.userName(a.doctorId) ?? a.doctorId}',
        statusLabel: statusLabel,
        paymentStatusLabel: _paymentStatusLabel(
          paymentByAppointmentId[a.id] ?? a.sessionPaymentStatus,
          l10n,
        ),
        paymentAmountLabel: _paymentAmountLabel(paymentAmountByAppointmentId[a.id]),
      ));
    }
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.take(50).toList();
  }

  static String _appointmentStatusLabel(AppointmentStatus status, AppLocalizations l10n) {
    switch (status) {
      case AppointmentStatus.pending: return l10n.pending;
      case AppointmentStatus.confirmed: return l10n.confirmed;
      case AppointmentStatus.completed: return l10n.attended;
      case AppointmentStatus.cancelled: return l10n.cancelled;
      case AppointmentStatus.noShow: return l10n.absent;
      case AppointmentStatus.absentWithCause: return l10n.apologized;
      case AppointmentStatus.absentWithoutCause: return l10n.absent;
    }
  }

  Future<void> _generateReport(AppLocalizations l10n) async {
    if (_user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.generatingReport)));
    try {
      final incomeList = await _firestore.getIncomeRecordsForPatient(widget.patientId);
      final merged = _mergedSessionRows(l10n, context.read<DataCacheProvider>());
      final sessionRows = merged
          .map((r) => PatientReportSessionRow(
                date: r.date,
                startTime: r.startTime,
                endTime: r.endTime,
                service: r.service,
                statusLabel: r.statusLabel,
                paymentStatusLabel: r.paymentStatusLabel,
              ))
          .toList();
      final bytes = await buildPatientReportPdf(
        user: _user!,
        profile: _profile,
        sessionRows: sessionRows,
        incomeForPatient: incomeList,
        packageProgress: _packageProgress(),
        l10n: l10n,
        centerName: l10n.appTitle,
      );
      final name = _user!.displayName.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '').trim();
      final safeName = name.isEmpty ? 'patient' : name.split(RegExp(r'\s+')).first;
      final filename = 'patient_report_${safeName}_${AppDateFormat.fileNameDate.format(DateTime.now())}.pdf';
      await savePdfAndShare(
        filename,
        bytes,
        _sharePositionOriginFromContext(),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.reportReady)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('${l10n.reportError}: $e')));
    }
  }

  Widget _buildPersonalDetails(AppLocalizations l10n) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.personalData, style: theme.titleMedium),
        const SizedBox(height: 8),
        Text(_user!.displayName, style: theme.titleSmall),
        if (_user!.email.isNotEmpty) Text(_user!.email, style: theme.bodySmall),
        if (_user!.phone != null && _user!.phone!.isNotEmpty) Text(_user!.phone!, style: theme.bodySmall),
        if (_profile != null) ...[
          if (_profile!.dateOfBirth != null) ...[
            Text(
              () {
                final dob = _profile!.dateOfBirth!;
                final parsed = parseDateOfBirth(dob);
                final dateStr = parsed != null ? AppDateFormat.mediumDate().format(parsed) : dob;
                final age = ageFromDateOfBirth(dob);
                return '${l10n.date}: $dateStr${age != null ? ' (${l10n.age}: $age ${l10n.yearsOld})' : ''}';
              }(),
              style: theme.bodySmall,
            ),
          ] else if (_profile!.age != null)
            Text('${l10n.age}: ${_profile!.age} ${l10n.yearsOld}', style: theme.bodySmall),
          if (_profile!.gender != null && _profile!.gender!.isNotEmpty)
            Text('${l10n.gender}: ${_profile!.gender}', style: theme.bodySmall),
          if (_profile!.address != null && _profile!.address!.isNotEmpty)
            Text('${l10n.address}: ${_profile!.address}', style: theme.bodySmall),
          if (_profile!.occupation != null && _profile!.occupation!.isNotEmpty)
            Text('${l10n.occupation}: ${_profile!.occupation}', style: theme.bodySmall),
          if (_profile!.referredBy != null && _profile!.referredBy!.isNotEmpty)
            Text('${l10n.referredBy}: ${_profile!.referredBy}', style: theme.bodySmall),
          if (_profile!.maritalStatus != null && _profile!.maritalStatus!.isNotEmpty)
            Text('${l10n.maritalStatus}: ${_profile!.maritalStatus}', style: theme.bodySmall),
        ],
      ],
    );
  }

  Widget _buildMedicalDetails(AppLocalizations l10n) {
    final theme = Theme.of(context).textTheme;
    final hasAny = _profile != null && (
      (_profile!.diagnosis != null && _profile!.diagnosis!.isNotEmpty) ||
      (_profile!.medicalHistory != null && _profile!.medicalHistory!.isNotEmpty) ||
      (_profile!.treatmentProgress != null && _profile!.treatmentProgress!.isNotEmpty) ||
      (_profile!.progressNotes != null && _profile!.progressNotes!.isNotEmpty) ||
      (_profile!.areasToTreat != null && _profile!.areasToTreat!.isNotEmpty) ||
      (_profile!.feesType != null && _profile!.feesType!.isNotEmpty) ||
      (_profile!.chiefComplaint != null && _profile!.chiefComplaint!.isNotEmpty) ||
      (_profile!.painLevel != null && _profile!.painLevel!.isNotEmpty) ||
      (_profile!.treatmentGoals != null && _profile!.treatmentGoals!.isNotEmpty) ||
      (_profile!.contraindications != null && _profile!.contraindications!.isNotEmpty) ||
      (_profile!.previousTreatment != null && _profile!.previousTreatment!.isNotEmpty)
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.medicalDetails, style: theme.titleMedium),
        const SizedBox(height: 8),
        if (!hasAny)
          Text(l10n.noData, style: theme.bodySmall)
        else ...[
          if (_profile!.diagnosis != null && _profile!.diagnosis!.isNotEmpty)
            Text('${l10n.diagnosis}: ${_profile!.diagnosis}', style: theme.bodySmall),
          if (_profile!.medicalHistory != null && _profile!.medicalHistory!.isNotEmpty)
            Text('${l10n.medicalHistory}: ${_profile!.medicalHistory}', style: theme.bodySmall),
          if (_profile!.treatmentProgress != null && _profile!.treatmentProgress!.isNotEmpty)
            Text('${l10n.treatmentProgress}: ${_profile!.treatmentProgress}', style: theme.bodySmall),
          if (_profile!.progressNotes != null && _profile!.progressNotes!.isNotEmpty)
            Text('${l10n.progressNotes}: ${_profile!.progressNotes}', style: theme.bodySmall),
          if (_profile!.areasToTreat != null && _profile!.areasToTreat!.isNotEmpty)
            Text('${l10n.areasToTreat}: ${_profile!.areasToTreat}', style: theme.bodySmall),
          if (_profile!.feesType != null && _profile!.feesType!.isNotEmpty)
            Text('${l10n.feesType}: ${_profile!.feesType}', style: theme.bodySmall),
          if (_profile!.chiefComplaint != null && _profile!.chiefComplaint!.isNotEmpty)
            Text('${l10n.chiefComplaint}: ${_profile!.chiefComplaint}', style: theme.bodySmall),
          if (_profile!.painLevel != null && _profile!.painLevel!.isNotEmpty)
            Text('${l10n.painLevel}: ${_profile!.painLevel}', style: theme.bodySmall),
          if (_profile!.treatmentGoals != null && _profile!.treatmentGoals!.isNotEmpty)
            Text('${l10n.treatmentGoals}: ${_profile!.treatmentGoals}', style: theme.bodySmall),
          if (_profile!.contraindications != null && _profile!.contraindications!.isNotEmpty)
            Text('${l10n.contraindications}: ${_profile!.contraindications}', style: theme.bodySmall),
          if (_profile!.previousTreatment != null && _profile!.previousTreatment!.isNotEmpty)
            Text('${l10n.previousTreatment}: ${_profile!.previousTreatment}', style: theme.bodySmall),
        ],
      ],
    );
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
            if (context.watch<AuthProvider>().currentUser?.canAccessPatients == true) ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: l10n.generateReport,
                onPressed: () => _generateReport(l10n),
              ),
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
            if (context.watch<AuthProvider>().currentUser?.canAccessAdminDashboard == true)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: l10n.sessionsAndPackages,
                onSelected: (value) {
                  if (value == 'sessions_admin') {
                    context.push('/patients/${widget.patientId}/sessions-admin');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'sessions_admin',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_view_week, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.sessionsAndPackages),
                      ],
                    ),
                  ),
                ],
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final twoCols = Breakpoint.isTabletOrWider(context);
                                final personal = _buildPersonalDetails(l10n);
                                final medical = _buildMedicalDetails(l10n);
                                if (twoCols) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: personal),
                                      const SizedBox(width: 24),
                                      Expanded(child: medical),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    personal,
                                    const SizedBox(height: 16),
                                    medical,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        if (context.watch<AuthProvider>().currentUser?.canAccessAppointments == true ||
                            context.watch<AuthProvider>().currentUser?.canAccessPatients == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (context.watch<AuthProvider>().currentUser?.canAccessAppointments == true)
                                  FilledButton.icon(
                                    icon: const Icon(Icons.calendar_today, size: 20),
                                    label: Text(l10n.bookAppointment),
                                    onPressed: () async {
                                      final cache = context.read<DataCacheProvider>();
                                      final currentUserId = context.read<AuthProvider>().currentUser?.id;
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (_) {
                                          final user = context.read<AuthProvider>().currentUser;
                                          final canBookPast = user?.hasRole(UserRole.admin) == true || user?.hasRole(UserRole.supervisor) == true;
                                          return AppointmentFormDialog(
                                            currentUserId: currentUserId,
                                            patients: cache.patients,
                                            doctors: cache.doctors,
                                            rooms: cache.rooms,
                                            services: cache.services,
                                            packages: _packages,
                                            initialPatientId: widget.patientId,
                                            allowPastDate: canBookPast,
                                          );
                                        },
                                      );
                                      if (ok == true && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(l10n.appointmentBooked)),
                                        );
                                        _load();
                                      }
                                    },
                                  ),
                                if (context.watch<AuthProvider>().currentUser?.canAccessPatients == true)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                                    label: Text(l10n.generateReport),
                                    onPressed: () => _generateReport(l10n),
                                  ),
                              ],
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
                            final rows = _mergedSessionRows(
                              l10n,
                              context.watch<DataCacheProvider>(),
                            );
                            if (rows.isEmpty) {
                              return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)));
                            }
                            return Column(
                              children: rows.map((r) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(AppDateFormat.shortDate.format(r.date)),
                                  subtitle: Text([
                                    '${r.startTime} - ${r.endTime}',
                                    if (r.service != null && r.service!.isNotEmpty) r.service,
                                    if (r.doctorLabel != null && r.doctorLabel!.isNotEmpty) r.doctorLabel,
                                    if (r.statusLabel != null) r.statusLabel,
                                    if (r.paymentStatusLabel != null) r.paymentStatusLabel,
                                    if (r.paymentAmountLabel != null) r.paymentAmountLabel,
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
  final String? doctorLabel;
  final String? statusLabel;
  final String? paymentStatusLabel;
  final String? paymentAmountLabel;

  _SessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.doctorLabel,
    this.statusLabel,
    this.paymentStatusLabel,
    this.paymentAmountLabel,
  });
}

String? _paymentStatusLabel(String? status, AppLocalizations l10n) {
  if (status == null || status.isEmpty) return null;
  switch (status) {
    case 'paid': return l10n.paid;
    case 'partial_paid': return l10n.partialPaid;
    case 'prepaid': return l10n.prepaid;
    case 'not_paid': return l10n.notPaid;
    default: return status;
  }
}

String? _paymentAmountLabel(double? amount) {
  if (amount == null || !amount.isFinite) return null;
  return NumberFormat.currency(symbol: '', decimalDigits: 0).format(amount).trim();
}
