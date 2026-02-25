import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/doctor_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'appointment_form_dialog.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _list = [];
  Map<String, String> _userNames = {};
  List<UserModel> _patients = [];
  List<DoctorModel> _doctors = [];
  List<RoomModel> _rooms = [];
  bool _loading = true;
  /// null = All (non-cancelled), otherwise filter by this status. Cancelled appointments are never shown.
  AppointmentStatus? _statusFilter;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadRefData();
    _startAppointmentsStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRefData() async {
    final patients = await _firestore.getPatients();
    final doctors = await _firestore.getDoctors();
    final rooms = await _firestore.getRooms();
    if (mounted) setState(() {
      _patients = patients;
      _doctors = doctors;
      _rooms = rooms;
    });
  }

  void _startAppointmentsStream() async {
    final auth = context.read<AuthProvider>().currentUser;
    String? doctorId;
    if (auth != null && auth.hasRole(UserRole.doctor)) {
      final doc = await _firestore.getDoctorByUserId(auth.id);
      if (doc != null) doctorId = doc.id;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    _subscription?.cancel();
    _subscription = _firestore.appointmentsStream(doctorId: doctorId).listen(
      (snapshot) {
        final from = DateTime.now().subtract(const Duration(days: 30));
        var list = snapshot.docs
            .map((d) => AppointmentModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .where((a) => a.appointmentDate.isAfter(from.subtract(const Duration(days: 1))))
            .where((a) => a.status != AppointmentStatus.cancelled)
            .toList();
        if (mounted) {
          setState(() {
            _list = list;
            _loading = false;
          });
          _loadNames(list);
        }
      },
      onError: (e, st) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  Future<void> _loadNames(List<AppointmentModel> list) async {
    final userIds = <String>{};
    for (final a in list) {
      userIds.add(a.patientId);
      userIds.add(a.doctorId);
    }
    final names = <String, String>{};
    for (final id in userIds) {
      final u = await _firestore.getUser(id);
      if (u != null) {
        names[id] = u.displayName;
      } else {
        final doc = await _firestore.getDoctorById(id);
        if (doc != null) {
          final docUser = await _firestore.getUser(doc.userId);
          names[id] = docUser?.displayName ?? doc.displayName ?? id;
        }
      }
    }
    if (mounted) setState(() => _userNames = names);
  }

  String _statusLabel(AppointmentStatus s, AppLocalizations l10n) {
    switch (s) {
      case AppointmentStatus.pending: return l10n.pending;
      case AppointmentStatus.confirmed: return l10n.confirmed;
      case AppointmentStatus.completed: return l10n.completed;
      case AppointmentStatus.cancelled: return l10n.cancelled;
      case AppointmentStatus.noShow: return l10n.noShow;
    }
  }

  /// After status change: reschedule local reminders for patient and doctor. Push to patient/doctor/secretary is sent by Cloud Function when deployed.
  void _notifyAppointmentStatusChange(AppointmentModel a) {
    NotificationService().rescheduleRemindersForUser(a.patientId);
    _firestore.getDoctorById(a.doctorId).then((doc) {
      if (doc != null) NotificationService().rescheduleRemindersForUser(doc.userId);
    });
  }

  /// List to display: already excludes cancelled; further filtered by _statusFilter.
  List<AppointmentModel> _displayList() {
    if (_statusFilter == null) return _list;
    return _list.where((a) => a.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>().currentUser;
    final canUpdate = auth != null && auth.canAccessAppointments;
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appointments),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            if (canUpdate)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.createAppointment,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AppointmentFormDialog(
                      currentUserId: auth.id,
                      patients: _patients,
                      doctors: _doctors,
                      rooms: _rooms,
                    ),
                  );
                  if (ok == true && mounted) { _subscription?.cancel(); _startAppointmentsStream(); }
                },
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(l10n.filterAll),
                      selected: _statusFilter == null,
                      onSelected: (_) => setState(() => _statusFilter = null),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.pending), selected: _statusFilter == AppointmentStatus.pending, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.pending))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.confirmed), selected: _statusFilter == AppointmentStatus.confirmed, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.confirmed))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.completed), selected: _statusFilter == AppointmentStatus.completed, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.completed))),
                  FilterChip(label: Text(l10n.noShow), selected: _statusFilter == AppointmentStatus.noShow, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.noShow)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayList().isEmpty
                      ? Center(child: Text(l10n.noData))
                      : RefreshIndicator(
                    onRefresh: () async {
                          _subscription?.cancel();
                          _startAppointmentsStream();
                          await Future.delayed(const Duration(milliseconds: 400));
                        },
                        child: ListView.builder(
                          padding: responsiveListPadding(context),
                          itemCount: _displayList().length,
                          itemBuilder: (context, i) {
                            final a = _displayList()[i];
                        final dateStr = DateFormat.yMd().format(a.appointmentDate);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${_userNames[a.patientId] ?? a.patientId} • ${_userNames[a.doctorId] ?? a.doctorId}'),
                            subtitle: Text('$dateStr ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status, l10n)}'),
                            trailing: canUpdate
                                ? PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AppointmentFormDialog(
                                            existing: a,
                                            currentUserId: auth.id,
                                            patients: _patients,
                                            doctors: _doctors,
                                            rooms: _rooms,
                                          ),
                                        );
                                        if (ok == true && mounted) { _subscription?.cancel(); _startAppointmentsStream(); }
                                      } else if (v == 'confirmed') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.confirmed);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'completed') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.completed);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'cancelled') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.cancelled);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'noShow') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.noShow);
                                        _notifyAppointmentStatusChange(a);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                      if (a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled) ...[
                                        PopupMenuItem(value: 'confirmed', child: Text(l10n.confirmed)),
                                        PopupMenuItem(value: 'completed', child: Text(l10n.completed)),
                                        PopupMenuItem(value: 'cancelled', child: Text(l10n.cancelled)),
                                        PopupMenuItem(value: 'noShow', child: Text(l10n.noShow)),
                                      ],
                                    ],
                                  )
                                : null,
                          ),
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
