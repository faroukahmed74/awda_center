import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/income_expense_models.dart';
import '../../models/package_model.dart';
import '../../models/session_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';
import '../appointments/appointment_form_dialog.dart';
import 'session_edit_dialog.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Admin-only screen: view/edit all sessions and packages for a patient, delete session (and relations).
class PatientSessionsPackagesAdminScreen extends StatefulWidget {
  final String patientId;

  const PatientSessionsPackagesAdminScreen({super.key, required this.patientId});

  @override
  State<PatientSessionsPackagesAdminScreen> createState() => _PatientSessionsPackagesAdminScreenState();
}

class _PatientSessionsPackagesAdminScreenState extends State<PatientSessionsPackagesAdminScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<SessionModel> _sessions = [];
  List<AppointmentModel> _appointments = [];
  List<PackageModel> _packages = [];
  List<IncomeRecordModel> _incomeRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sessions = await _firestore.getSessionsForPatient(widget.patientId);
      final appointments = await _firestore.getAppointments(patientId: widget.patientId);
      final packages = await _firestore.getAllPackages();
      final auth = context.read<AuthProvider>().currentUser;
      final incomeRecords = auth?.canAccessIncomeExpenses == true
          ? await _firestore.getIncomeRecordsForPatient(widget.patientId)
          : <IncomeRecordModel>[];
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _appointments = appointments;
        _packages = packages;
        _incomeRecords = incomeRecords;
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

  /// Appointment IDs that are linked from sessions collection.
  Set<String> get _appointmentIdsFromSessions =>
      _sessions.map((s) => s.appointmentId).where((id) => id != null && id.isNotEmpty).cast<String>().toSet();

  /// Appointments that do not have a session doc (show as appointment-only rows).
  List<AppointmentModel> get _appointmentOnlyList =>
      _appointments.where((a) => !_appointmentIdsFromSessions.contains(a.id)).toList();

  List<({PackageModel pkg, int completed, int total})> _packageProgress() {
    final out = <({PackageModel pkg, int completed, int total})>[];
    final byPackage = <String, List<AppointmentModel>>{};
    for (final a in _appointments) {
      if (a.packageId == null || a.packageId!.isEmpty) continue;
      byPackage.putIfAbsent(a.packageId!, () => []).add(a);
    }
    for (final pkg in _packages) {
      final list = byPackage[pkg.id];
      if (list == null) continue;
      final ordered = List<AppointmentModel>.from(list)..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
      final totalSessions = pkg.numberOfSessions <= 0 ? 1 : pkg.numberOfSessions;
      for (var i = 0; i < ordered.length; i += totalSessions) {
        final end = (i + totalSessions) > ordered.length ? ordered.length : (i + totalSessions);
        final cycle = ordered.sublist(i, end);
        final completed = cycle.where((a) => a.status == AppointmentStatus.completed).length;
        out.add((pkg: pkg, completed: completed, total: totalSessions));
      }
    }
    return out;
  }

  static String _statusLabel(AppointmentStatus status, AppLocalizations l10n) {
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

  Future<void> _deleteSessionRow({String? sessionId, String? appointmentId}) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text(l10n.deleteSession),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      if (sessionId != null) {
        await _firestore.deleteSessionAndRelations(sessionId);
      } else if (appointmentId != null) {
        await _firestore.deleteAppointment(appointmentId);
      }
      final uid = context.read<AuthProvider>().currentUser?.id;
      if (uid != null) {
        AuditService.log(
          action: sessionId != null ? 'session_deleted' : 'appointment_deleted',
          entityType: sessionId != null ? 'session' : 'appointment',
          entityId: sessionId ?? appointmentId ?? '',
          userId: uid,
          details: {'patientId': widget.patientId},
        );
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.reportError}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cache = context.watch<DataCacheProvider>();
    final auth = context.read<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sessionsAndPackages),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () { if (context.canPop()) context.pop(); else context.go('/patients/${widget.patientId}'); },
        ),
        actions: [...MainAppBarActions.notificationsLanguageTheme(context)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 24),
                  Text(l10n.sessions, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // Rows from sessions collection
                  ..._sessions.map((s) => _buildSessionRow(context, l10n, cache, auth, session: s)),
                  // Rows from appointments only (no session doc)
                  ..._appointmentOnlyList.map((a) => _buildSessionRow(context, l10n, cache, auth, appointment: a)),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionRow(
    BuildContext context,
    AppLocalizations l10n,
    DataCacheProvider cache,
    UserModel? auth, {
    SessionModel? session,
    AppointmentModel? appointment,
  }) {
    final isSession = session != null;
    final date = isSession ? session.sessionDate : appointment!.appointmentDate;
    final startTime = isSession ? session.startTime : appointment!.startTime;
    final endTime = isSession ? session.endTime : appointment!.endTime;
    final service = isSession ? (session.service ?? '') : appointment!.servicesDisplay;
    final doctorLabel = isSession
        ? (session.doctorId.isEmpty ? null : cache.doctorDisplayName(session.doctorId) ?? cache.userName(session.doctorId))
        : (cache.doctorDisplayName(appointment!.doctorId) ?? cache.userName(appointment.doctorId));
    final statusLabel = isSession ? null : _statusLabel(appointment!.status, l10n);

    final paymentByAppointmentId = <String, String?>{};
    final paymentAmountByAppointmentId = <String, double>{};
    for (final r in _incomeRecords) {
      if (r.appointmentId != null && r.appointmentId!.isNotEmpty) {
        paymentByAppointmentId[r.appointmentId!] = r.sessionPaymentStatus;
        if (r.amount.isFinite) paymentAmountByAppointmentId[r.appointmentId!] = r.amount;
      }
    }
    final appointmentId = isSession ? session.appointmentId : appointment!.id;
    final paymentStatus = appointmentId != null ? paymentByAppointmentId[appointmentId] : null;
    final paymentAmount = appointmentId != null ? paymentAmountByAppointmentId[appointmentId] : null;
    String? paymentStatusLabel;
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      switch (paymentStatus) {
        case 'paid': paymentStatusLabel = l10n.paid; break;
        case 'partial_paid': paymentStatusLabel = l10n.partialPaid; break;
        case 'prepaid': paymentStatusLabel = l10n.prepaid; break;
        case 'not_paid': paymentStatusLabel = l10n.notPaid; break;
        default: paymentStatusLabel = paymentStatus;
      }
    }
    final paymentAmountLabel = paymentAmount != null && paymentAmount.isFinite
        ? NumberFormat.currency(symbol: '', decimalDigits: 0).format(paymentAmount).trim()
        : null;

    final subtitle = [
      '$startTime - $endTime',
      if (service.isNotEmpty) service,
      if (doctorLabel != null) '${l10n.doctor}: $doctorLabel',
      if (statusLabel != null) statusLabel,
      if (paymentStatusLabel != null) paymentStatusLabel,
      if (paymentAmountLabel != null) paymentAmountLabel,
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(AppDateFormat.shortDate.format(date)),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: l10n.viewDetails,
              onPressed: () => _showDetails(context, l10n, cache, session: session, appointment: appointment),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.edit,
              onPressed: () => _editRow(context, l10n, cache, auth, session: session, appointment: appointment),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteSession,
              onPressed: () => _deleteSessionRow(
                sessionId: session?.id,
                appointmentId: appointment?.id,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    AppLocalizations l10n,
    DataCacheProvider cache, {
    SessionModel? session,
    AppointmentModel? appointment,
  }) {
    final lines = <String>[];
    if (session != null) {
      lines.addAll([
        '${l10n.date}: ${AppDateFormat.mediumDate().format(session.sessionDate)}',
        '${l10n.time} (start): ${session.startTime}',
        '${l10n.time} (end): ${session.endTime}',
        if (session.service != null) '${l10n.service}: ${session.service}',
        '${l10n.doctor}: ${cache.doctorDisplayName(session.doctorId) ?? session.doctorId}',
        if (session.notes != null) '${l10n.notes}: ${session.notes}',
        if (session.progressNotes != null) 'Progress notes: ${session.progressNotes}',
        if (session.vas != null) 'VAS: ${session.vas}',
        if (session.rom != null) 'ROM: ${session.rom}',
        if (session.feesAmount != null) '${l10n.amount}: ${session.feesAmount}',
        if (session.appointmentId != null) 'Appointment ID: ${session.appointmentId}',
      ]);
    } else if (appointment != null) {
      lines.addAll([
        '${l10n.date}: ${AppDateFormat.mediumDate().format(appointment.appointmentDate)}',
        '${l10n.time}: ${appointment.startTime} - ${appointment.endTime}',
        '${l10n.service}: ${appointment.servicesDisplay}',
        '${l10n.doctor}: ${cache.doctorDisplayName(appointment.doctorId) ?? appointment.doctorId}',
        '${l10n.status}: ${_statusLabel(appointment.status, l10n)}',
        if (appointment.notes != null && appointment.notes!.isNotEmpty) '${l10n.notes}: ${appointment.notes}',
        if (appointment.packageId != null) 'Package ID: ${appointment.packageId}',
      ]);
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.viewDetails),
        content: SingleChildScrollView(child: SelectableText(lines.join('\n'))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.confirm))],
      ),
    );
  }

  Future<void> _editRow(
    BuildContext context,
    AppLocalizations l10n,
    DataCacheProvider cache,
    UserModel? auth, {
    SessionModel? session,
    AppointmentModel? appointment,
  }) async {
    if (session != null) {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => SessionEditDialog(session: session),
      );
      if (data == null || !mounted) return;
      final update = Map<String, dynamic>.from(data);
      if (update['sessionDate'] is DateTime) {
        update['sessionDate'] = Timestamp.fromDate(update['sessionDate'] as DateTime);
      }
      await _firestore.updateSession(session.id, update);
      if (mounted) _load();
    } else if (appointment != null && auth != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AppointmentFormDialog(
          existing: appointment,
          currentUserId: auth.id,
          patients: cache.patients,
          doctors: cache.activeDoctors,
          rooms: cache.rooms,
          services: cache.services,
          packages: _packages,
          allowPastDate: auth.hasRole(UserRole.admin) || auth.hasRole(UserRole.supervisor),
        ),
      );
      if (ok == true && mounted) _load();
    }
  }
}
