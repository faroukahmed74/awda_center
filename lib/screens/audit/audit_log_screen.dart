import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/audit_log_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
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
      }
    }

    final userNameById = <String, String>{};
    for (final uid in userIds) {
      final user = await _firestore.getUser(uid);
      userNameById[uid] = user?.displayName ?? user?.email ?? uid;
    }

    final doctorNameById = <String, String>{};
    for (final did in doctorIds) {
      final doctor = await _firestore.getDoctorById(did);
      String name = doctor?.displayName ?? '';
      if (name.isEmpty && doctor?.userId != null) {
        final user = await _firestore.getUser(doctor!.userId);
        name = user?.displayName ?? user?.email ?? did;
      }
      doctorNameById[did] = name.isEmpty ? did : name;
    }

    if (mounted) {
      setState(() {
        _list = list;
        _userNameById = userNameById;
        _doctorNameById = doctorNameById;
        _loading = false;
      });
    }
  }

  String _auditActionLabel(AuditLogModel e) {
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
        } else if (key == 'targetEmail' || key == 'fileName' || key == 'status' || key == 'roles' || key == 'permissions' || key == 'amount' || key == 'category' || key == 'source') {
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
          actions: const [NotificationsButton()],
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
                          final what = _auditActionLabel(e);
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
