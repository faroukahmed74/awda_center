import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audit_log_model.dart';
import '../../models/appointment_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';
import '../../core/date_format.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AuditLogModel> _list = [];
  Map<String, String> _userNameById = {};
  Map<String, String> _doctorNameById = {};
  /// Current status (value) per appointment ID so audit log shows up-to-date session status.
  Map<String, String> _currentStatusByAppointmentId = {};
  /// Package display name by ID so audit log shows package name instead of ID.
  Map<String, String> _packageNameById = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getAuditLogs();
    list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    final userIds = <String>{};
    final doctorIds = <String>{};
    final packageIds = <String>{};
    for (final e in list) {
      if (e.userId.isNotEmpty) userIds.add(e.userId);
      if (e.entityId != null && e.entityId!.isNotEmpty) {
        if (e.entityType == 'user') userIds.add(e.entityId!);
      }
      if (e.details != null) {
        final pid = e.details!['patientId'];
        if (pid is String && pid.isNotEmpty) userIds.add(pid);
        final did = e.details!['doctorId'];
        if (did is String && did.isNotEmpty) doctorIds.add(did);
        final pkgId = e.details!['packageId'];
        if (pkgId is String && pkgId.isNotEmpty) packageIds.add(pkgId);
      }
    }

    // Fetch all users and doctors in parallel instead of sequentially
    final userIdList = userIds.toList();
    final doctorIdList = doctorIds.toList();
    final userResults = await Future.wait(
      userIdList.map((uid) => _firestore.getUser(uid)),
    );
    final userNameById = <String, String>{
      for (var i = 0; i < userIdList.length; i++)
        userIdList[i]: userResults[i]?.displayName ?? userResults[i]?.email ?? userIdList[i],
    };

    final doctorResults = await Future.wait(
      doctorIdList.map((did) => _firestore.getDoctorById(did)),
    );
    final doctorUserIdList = <String>[];
    final seenDoctorUserId = <String>{};
    for (var i = 0; i < doctorIdList.length; i++) {
      final d = doctorResults[i];
      if (d != null && (d.displayName == null || d.displayName!.isEmpty) && d.userId.isNotEmpty && seenDoctorUserId.add(d.userId)) {
        doctorUserIdList.add(d.userId);
      }
    }
    final doctorUserResults = await Future.wait(
      doctorUserIdList.map((uid) => _firestore.getUser(uid)),
    );
    final doctorUserByName = <String, String>{
      for (var i = 0; i < doctorUserIdList.length; i++)
        doctorUserIdList[i]:
            doctorUserResults[i]?.displayName ?? doctorUserResults[i]?.email ?? '',
    };

    final doctorNameById = <String, String>{};
    for (var i = 0; i < doctorIdList.length; i++) {
      final did = doctorIdList[i];
      final d = doctorResults[i];
      String name = d?.displayName ?? '';
      if (name.isEmpty && d != null && d.userId.isNotEmpty) {
        name = doctorUserByName[d.userId] ?? did;
      }
      doctorNameById[did] = name.isEmpty ? did : name;
    }

    // Fetch current status for all appointments in the log so we show up-to-date session status
    final appointmentIds = list
        .where((e) => e.entityType == 'appointment' && e.entityId != null && e.entityId!.isNotEmpty)
        .map((e) => e.entityId!)
        .toSet()
        .toList();
    final appointmentResults = await Future.wait(
      appointmentIds.map((id) => _firestore.getAppointmentById(id)),
    );
    final currentStatusByAppointmentId = <String, String>{};
    for (var i = 0; i < appointmentIds.length; i++) {
      final a = appointmentResults[i];
      if (a != null) currentStatusByAppointmentId[appointmentIds[i]] = a.status.value;
    }

    // Fetch package names so we show package name instead of package ID in logs
    final packageIdList = packageIds.toList();
    final packageResults = await Future.wait(
      packageIdList.map((id) => _firestore.getPackageById(id)),
    );
    final packageNameById = <String, String>{};
    for (var i = 0; i < packageIdList.length; i++) {
      final pkg = packageResults[i];
      if (pkg != null) packageNameById[packageIdList[i]] = pkg.displayName;
    }

    if (mounted) {
      setState(() {
        _list = list;
        _userNameById = userNameById;
        _doctorNameById = doctorNameById;
        _currentStatusByAppointmentId = currentStatusByAppointmentId;
        _packageNameById = packageNameById;
        _loading = false;
      });
    }
  }

  /// Localized label for appointment status value (e.g. 'completed' -> Attended).
  String _statusLabelForValue(String? value, AppLocalizations l10n) {
    final s = AppointmentStatusExt.fromString(value);
    switch (s) {
      case AppointmentStatus.pending: return l10n.pending;
      case AppointmentStatus.confirmed: return l10n.confirmed;
      case AppointmentStatus.completed: return l10n.attended;
      case AppointmentStatus.cancelled: return l10n.cancelled;
      case AppointmentStatus.noShow: return l10n.absent;
      case AppointmentStatus.absentWithCause: return l10n.apologized;
      case AppointmentStatus.absentWithoutCause: return l10n.absent;
    }
  }

  String _auditActionLabel(AuditLogModel e, AppLocalizations l10n) {
    final action = e.action.replaceAll('_', ' ');
    final entityType = e.entityType;
    final entityId = e.entityId;
    final details = e.details;

    String entityLabel = entityType;
    if (entityId != null && entityId.isNotEmpty) {
      if (entityType == 'user') {
        entityLabel = _userNameById[entityId] ?? entityId;
      } else if (entityType == 'invite') {
        entityLabel = entityId;
      } else {
        final typeLabel = entityType.replaceAll('_', ' ');
        entityLabel = typeLabel.isNotEmpty ? typeLabel : entityId;
      }
    }

    final parts = <String>[action, entityLabel];

    if (details != null && details.isNotEmpty) {
      final resolved = <String>[];
      for (final entry in details.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key == 'patientId' && value is String) {
          resolved.add('patient: ${_userNameById[value] ?? value}');
        } else if (key == 'doctorId' && value is String) {
          resolved.add('doctor: ${_doctorNameById[value] ?? value}');
        } else if (key == 'status') {
          // For appointments, show current session status (from live data) with localized label
          final statusValue = entityType == 'appointment' && entityId != null
              ? (_currentStatusByAppointmentId[entityId] ?? value?.toString())
              : value?.toString();
          resolved.add('${l10n.status}: ${_statusLabelForValue(statusValue, l10n)}');
        } else if (key == 'packageId' && value is String) {
          resolved.add('package: ${_packageNameById[value] ?? value}');
        } else if (key == 'targetEmail' || key == 'fileName' || key == 'roles' || key == 'permissions' || key == 'amount' || key == 'category' || key == 'source') {
          resolved.add('$key: $value');
        } else {
          resolved.add('$key: $value');
        }
      }
      if (resolved.isNotEmpty) parts.add(resolved.take(3).join(' · '));
    }

    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.auditLog),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [...MainAppBarActions.notificationsLanguageTheme(context)],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _list.isEmpty
                    ? Center(child: Text(l10n.noData))
                    : ListView.builder(
                        padding: responsiveListPadding(context),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final e = _list[i];
                          final when = e.createdAt != null ? AppDateFormat.shortDateTime.format(e.createdAt!) : '';
                          final who = _userNameById[e.userId] ?? e.userEmail ?? e.userId;
                          final what = _auditActionLabel(e, l10n);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(what, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l10n.auditWho}: $who'),
                                  Text('${l10n.auditWhen}: $when'),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
