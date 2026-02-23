import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'patient_book_appointment_dialog.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _list = [];
  Map<String, String> _doctorNames = {};
  bool _loading = true;
  String? _errorMessage;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToAppointments();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToAppointments() {
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Not signed in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    _subscription?.cancel();
    _subscription = _firestore.appointmentsStream(patientId: uid).listen(
      (snapshot) {
        final list = snapshot.docs
            .map((d) => AppointmentModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        if (mounted) {
          setState(() {
            _list = list;
            _loading = false;
            _errorMessage = null;
          });
          _loadDoctorNames(list);
        }
      },
      onError: (e, st) {
        debugPrint('MyAppointmentsScreen stream error: $e\n$st');
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMessage = e.toString();
          });
        }
      },
    );
  }

  Future<void> _loadDoctorNames(List<AppointmentModel> list) async {
    final doctorIds = list.map((a) => a.doctorId).toSet().toList();
    final names = <String, String>{};
    for (final did in doctorIds) {
      try {
        final doc = await _firestore.getDoctorById(did);
        if (doc != null) {
          final u = await _firestore.getUser(doc.userId);
          names[did] = u?.displayName ?? doc.displayName ?? did;
        }
      } catch (_) {
        names[did] = did;
      }
    }
    if (mounted) setState(() => _doctorNames = names);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.myAppointments),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.bookAppointment,
              onPressed: () async {
                final uid = context.read<AuthProvider>().currentUser?.id;
                if (uid == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => PatientBookAppointmentDialog(patientId: uid),
                );
                if (ok == true && mounted) _listenToAppointments();
              },
            ),
          ],
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
                            onPressed: () { _subscription?.cancel(); _listenToAppointments(); },
                          ),
                        ],
                      ),
                    ),
                  )
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.noData),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(l10n.bookAppointment),
                              onPressed: () async {
                                final uid = context.read<AuthProvider>().currentUser?.id;
                                if (uid == null) return;
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => PatientBookAppointmentDialog(patientId: uid),
                                );
                                if (ok == true && mounted) _listenToAppointments();
                              },
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                    onRefresh: () async {
                      _subscription?.cancel();
                      _listenToAppointments();
                      await Future.delayed(const Duration(milliseconds: 400));
                    },
                    child: ListView.builder(
                      padding: responsiveListPadding(context),
                      itemCount: _list.length,
                      itemBuilder: (context, i) {
                        final a = _list[i];
                        final dateStr = DateFormat.yMd().format(a.appointmentDate);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(_doctorNames[a.doctorId] ?? a.doctorId),
                            subtitle: Text('$dateStr ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status, l10n)}'),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
