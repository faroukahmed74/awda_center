import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const int _auditFetchLimit = 5000;

  final FirestoreService _firestore = FirestoreService();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _auditSubscription;
  int _hydrateToken = 0;
  List<AuditLogModel> _list = [];
  Map<String, String> _userNameById = {};
  Map<String, String> _doctorNameById = {};
  /// Current status (value) per appointment ID so audit log shows up-to-date session status.
  Map<String, String> _currentStatusByAppointmentId = {};
  /// Appointment date + start time per ID (e.g. "31/05/2026 09:00").
  Map<String, String> _appointmentScheduleById = {};
  /// Package display name by ID so audit log shows package name instead of ID.
  Map<String, String> _packageNameById = {};
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _subscribeToAuditLogs();
  }

  @override
  void dispose() {
    _auditSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Match an entry against the search query by resolved doctor/patient names
  /// (with ID fallback) found either in [details] or as the entry's [entityId].
  /// Empty query matches everything.
  bool _matchesSearch(AuditLogModel e) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool contains(String? value) =>
        value != null && value.isNotEmpty && value.toLowerCase().contains(q);

    final details = e.details;
    if (details != null) {
      final pid = details['patientId'];
      if (pid is String && pid.isNotEmpty) {
        if (contains(_userNameById[pid]) || contains(pid)) return true;
      }
      final did = details['doctorId'];
      if (did is String && did.isNotEmpty) {
        if (contains(_doctorNameById[did]) || contains(did)) return true;
      }
    }

    final entityId = e.entityId;
    if (entityId != null && entityId.isNotEmpty) {
      if (e.entityType == 'user' && contains(_userNameById[entityId])) {
        return true;
      }
      if (e.entityType == 'doctor' && contains(_doctorNameById[entityId])) {
        return true;
      }
    }
    return false;
  }

  DateTime get _auditWindowStart => FirestoreService.auditLogSinceOneMonthAgo();

  /// Keep last 30 days after fetching the most recent rows (avoids Firestore
  /// range-query quirks and still loads enough history beyond the old 200 cap).
  List<AuditLogModel> _filterToAuditWindow(List<AuditLogModel> raw) {
    final since = _auditWindowStart;
    return raw.where((e) {
      final at = e.createdAt;
      return at != null && !at.isBefore(since);
    }).toList();
  }

  void _subscribeToAuditLogs() {
    _auditSubscription?.cancel();
    _auditSubscription = _firestore
        .auditLogsStream(limit: _auditFetchLimit)
        .listen(
      (snapshot) {
        final list = _filterToAuditWindow(
          snapshot.docs.map((d) => AuditLogModel.fromFirestore(d)).toList(),
        );
        unawaited(_hydrateAndSet(list));
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('audit log stream error: $error\n$stack');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _load() async {
    final raw = await _firestore.getAuditLogs(limit: _auditFetchLimit);
    await _hydrateAndSet(_filterToAuditWindow(raw));
  }

  Future<void> _hydrateAndSet(List<AuditLogModel> list) async {
    final token = ++_hydrateToken;
    if (_list.isEmpty && mounted) {
      setState(() => _loading = true);
    }
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
    final appointmentScheduleById = <String, String>{};
    for (var i = 0; i < appointmentIds.length; i++) {
      final a = appointmentResults[i];
      if (a != null) {
        currentStatusByAppointmentId[appointmentIds[i]] = a.status.value;
        final dateStr = AppDateFormat.shortDate.format(a.appointmentDate);
        appointmentScheduleById[appointmentIds[i]] = '$dateStr ${a.startTime}';
      }
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

    if (!mounted || token != _hydrateToken) return;
    if (mounted) {
      setState(() {
        _list = list;
        _userNameById = userNameById;
        _doctorNameById = doctorNameById;
        _currentStatusByAppointmentId = currentStatusByAppointmentId;
        _appointmentScheduleById = appointmentScheduleById;
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

  /// Date + time of the appointment an audit entry refers to (live fetch, or stored in details).
  String? _appointmentScheduleForEntry(AuditLogModel e) {
    if (e.entityType != 'appointment') return null;
    final id = e.entityId;
    if (id != null && id.isNotEmpty) {
      final live = _appointmentScheduleById[id];
      if (live != null && live.isNotEmpty) return live;
    }
    final stored = e.details?['appointmentWhen'];
    if (stored is String && stored.trim().isNotEmpty) return stored.trim();
    final date = e.details?['appointmentDate'];
    final time = e.details?['startTime'];
    if (date is String && date.isNotEmpty && time is String && time.isNotEmpty) {
      return '$date $time';
    }
    return null;
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
      final platform = details['platform'];
      final deviceType = details['deviceType'];
      if (platform != null) resolved.add('platform: $platform');
      if (deviceType != null) resolved.add('deviceType: $deviceType');
      for (final entry in details.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key == 'platform' || key == 'deviceType') {
          continue;
        }
        if (key == 'patientId' && value is String) {
          resolved.add('patient: ${_userNameById[value] ?? value}');
        } else if (key == 'doctorId' && value is String) {
          final doctorPart = 'doctor: ${_doctorNameById[value] ?? value}';
          final schedule = _appointmentScheduleForEntry(e);
          if (schedule != null) {
            resolved.add('$doctorPart · $schedule');
          } else {
            resolved.add(doctorPart);
          }
        } else if (key == 'status') {
          // For appointments, show current session status (from live data) with localized label
          final statusValue = entityType == 'appointment' && entityId != null
              ? (_currentStatusByAppointmentId[entityId] ?? value?.toString())
              : value?.toString();
          resolved.add('${l10n.status}: ${_statusLabelForValue(statusValue, l10n)}');
        } else if (key == 'packageId' && value is String) {
          resolved.add('package: ${_packageNameById[value] ?? value}');
        } else if (key == 'appointmentWhen' ||
            key == 'appointmentDate' ||
            key == 'startTime') {
          continue;
        } else if (key == 'targetEmail' || key == 'fileName' || key == 'roles' || key == 'permissions' || key == 'amount' || key == 'category' || key == 'source') {
          resolved.add('$key: $value');
        } else {
          resolved.add('$key: $value');
        }
      }
      if (resolved.isNotEmpty) parts.add(resolved.take(5).join(' · '));
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
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.searchByDoctorOrPatientHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  if (_list.isNotEmpty && _searchQuery.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          isRtl
                              ? '${_list.length} إدخال من ${AppDateFormat.shortDate.format(_auditWindowStart)}'
                              : '${_list.length} entries since ${AppDateFormat.shortDate.format(_auditWindowStart)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: Builder(
                        builder: (context) {
                          final filtered = _list.where(_matchesSearch).toList();
                          if (filtered.isEmpty) {
                            return ListView(
                              padding: responsiveListPadding(context),
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(_searchQuery.trim().isEmpty
                                      ? l10n.noData
                                      : l10n.noSearchResults),
                                ),
                              ],
                            );
                          }
                          return ListView.builder(
                            padding: responsiveListPadding(context),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final e = filtered[i];
                              final when = e.createdAt != null ? AppDateFormat.shortDateTimeSec.format(e.createdAt!) : '';
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
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
