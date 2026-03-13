import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/package_model.dart';
import '../../models/room_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../models/income_expense_models.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/date_format.dart';
import 'appointment_form_dialog.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _list = [];
  bool _loading = true;
  AppointmentStatus? _statusFilter;
  String _searchQuery = '';
  /// Date filters: exactly one of these can be set (day = single date, month = year+month, year = year only).
  DateTime? _filterDay;
  int? _filterYear;
  int? _filterMonth; // 1-12 when _filterYear is set
  /// Filter by doctor (appointments for this doctor only). Combines with status, date, and search.
  String? _filterDoctorId;
  bool _scheduleView = false;
  DateTime _scheduleDate = DateTime.now();
  List<PackageModel> _packages = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// 24-hour schedule: time slots every 30 min from 00:00 to 23:30.
  static final List<String> _scheduleHours = List.generate(48, (i) {
    final h = i ~/ 2;
    final m = (i % 2) * 30;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  });

  /// Next 30-min slot after [startTime] (e.g. 00:00 -> 00:30, 23:30 -> 23:30).
  static String _nextSlot(String startTime) {
    final parts = startTime.split(':');
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0;
    if (m == 30) {
      if (h == 23) return '23:30';
      return '${(h + 1).toString().padLeft(2, '0')}:00';
    }
    return '${h.toString().padLeft(2, '0')}:30';
  }

  /// Builds DateTime from appointment date + "HH:mm" startTime for income record so Date shows correct time.
  static DateTime _dateTimeFromAppointmentDateAndTime(DateTime date, String startTime) {
    final parts = startTime.split(':');
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1].trim() : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, h.clamp(0, 23), m.clamp(0, 59));
  }

  /// For schedule view: appointments at [date] and [startTime] that occupy the slot (pending/confirmed/completed).
  /// Apologized/absent do not appear in the grid so the new booking in the same room shows.
  List<AppointmentModel> _appointmentsForSlot(DateTime date, String startTime, List<AppointmentModel> list) {
    return list.where((a) =>
        a.appointmentDate.year == date.year &&
        a.appointmentDate.month == date.month &&
        a.appointmentDate.day == date.day &&
        a.startTime == startTime &&
        a.status.occupiesSlot).toList();
  }

  /// Appointment to show in schedule cell: column [cellIndex] (0=room0, 1=room1, 2=room2, 3=extra).
  /// Uses each appointment's roomId so bookings appear under their chosen room.
  AppointmentModel? _appointmentForCell(int cellIndex, List<AppointmentModel> slotApps, List<RoomModel> rooms) {
    if (slotApps.isEmpty) return null;
    if (cellIndex == 3) {
      try {
        return slotApps.firstWhere((a) => a.isExtraSlot);
      } catch (_) {
        return null;
      }
    }
    if (rooms.isEmpty || cellIndex < 0 || cellIndex >= rooms.length) {
      final main = slotApps.where((a) => !a.isExtraSlot).toList();
      return cellIndex < main.length ? main[cellIndex] : null;
    }
    final roomId = rooms[cellIndex].id;
    final forRoom = slotApps.where((a) => !a.isExtraSlot && a.roomId == roomId).toList();
    if (forRoom.isNotEmpty) return forRoom.first;
    if (cellIndex == 0) {
      final noRoom = slotApps.where((a) => !a.isExtraSlot && (a.roomId == null || a.roomId!.isEmpty)).toList();
      if (noRoom.isNotEmpty) return noRoom.first;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startAppointmentsStream();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final p = await _firestore.getAllPackages();
    if (mounted) setState(() => _packages = p);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startAppointmentsStream() async {
    final auth = context.read<AuthProvider>().currentUser;
    String? doctorId;
    if (auth != null && auth.hasRole(UserRole.doctor) && !auth.hasRole(UserRole.admin)) {
      // If admin granted "See all" or "View all (read-only)", doctor sees full list/schedule; otherwise only their own.
      final seeOrViewAll = auth.canAccessFeature('appointments_see_all') || auth.canAccessFeature('appointments_view_all');
      if (!seeOrViewAll) {
      final doc = await _firestore.getDoctorByUserId(auth.id);
      if (doc != null) doctorId = doc.id;
      }
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
        if (mounted) setState(() {
            _list = list;
            _loading = false;
          });
      },
      onError: (e, st) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  /// True when the user sees all doctors' appointments and can filter by doctor (admin/staff or doctor with see_all/view_all).
  bool _showDoctorFilter(BuildContext context) {
    final auth = context.read<AuthProvider>().currentUser;
    if (auth == null) return false;
    if (auth.hasRole(UserRole.admin)) return true;
    final seeOrViewAll = auth.canAccessFeature('appointments_see_all') || auth.canAccessFeature('appointments_view_all');
    if (auth.hasRole(UserRole.doctor) && !seeOrViewAll) return false;
    return true;
  }

  String _statusLabel(AppointmentStatus s, AppLocalizations l10n) {
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

  /// After status change: reschedule local reminders for patient and doctor. Push to patient/doctor/secretary is sent by Cloud Function when deployed.
  void _notifyAppointmentStatusChange(AppointmentModel a) {
    NotificationService().rescheduleRemindersForUser(a.patientId);
    _firestore.getDoctorById(a.doctorId).then((doc) {
      if (doc != null) NotificationService().rescheduleRemindersForUser(doc.userId);
    });
  }

  /// Update local list immediately so UI refreshes without waiting for stream.
  void _updateListAfterChange(String appointmentId, {AppointmentStatus? newStatus, AppointmentModel? replacement}) {
    if (replacement != null) {
      final i = _list.indexWhere((x) => x.id == appointmentId);
      if (i >= 0) {
        if (replacement.status == AppointmentStatus.cancelled) {
          _list.removeAt(i);
        } else {
          _list[i] = replacement;
        }
      } else {
        if (replacement.status != AppointmentStatus.cancelled) _list.insert(0, replacement);
      }
    } else if (newStatus != null) {
      if (newStatus == AppointmentStatus.cancelled) {
        _list.removeWhere((x) => x.id == appointmentId);
      } else {
        final i = _list.indexWhere((x) => x.id == appointmentId);
        if (i >= 0) _list[i] = _list[i].copyWith(status: newStatus);
      }
    }
    setState(() {});
  }

  /// When an appointment is marked completed and it's linked to a package, check if all sessions of that package are done and notify.
  Future<void> _checkPackageCompleted(AppointmentModel a, AppLocalizations l10n) async {
    if (a.packageId == null || a.packageId!.isEmpty) return;
    final pkg = await _firestore.getPackageById(a.packageId!);
    if (pkg == null) return;
    final list = await _firestore.getAppointments(patientId: a.patientId);
    final completedForPackage = list.where((x) => x.packageId == a.packageId && x.status == AppointmentStatus.completed).length;
    if (completedForPackage >= pkg.numberOfSessions && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pkg.displayName}: ${l10n.packageCompleted}')),
      );
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        AuditService.log(
          action: 'package_completed',
          entityType: 'package',
          entityId: pkg.id,
          userId: user.id,
          userEmail: user.email,
          details: {'patientId': a.patientId, 'packageId': pkg.id, 'sessionsCompleted': completedForPackage},
        );
      }
    }
  }

  /// Shows session payment dialog. Returns (amount, sessionPaymentStatus) or null if cancelled.
  /// sessionPaymentStatus: 'paid', 'partial_paid', 'prepaid', 'not_paid'. Discount is applied in this dialog.
  Future<({double amount, String status})?> _showSessionPaymentDialog(BuildContext context, AppointmentModel a, AppLocalizations l10n) async {
    final costAmount = a.costAmount ?? 0.0;
    final discountPercent = a.discountPercent;
    final baseAmount = costAmount > 0 && discountPercent != null && discountPercent > 0 && discountPercent < 100
        ? costAmount / (1 - discountPercent / 100)
        : costAmount;
    final discountController = TextEditingController(
      text: discountPercent != null ? discountPercent.toStringAsFixed(0) : '0',
    );
    final partialController = TextEditingController(
      text: costAmount > 0 ? costAmount.toStringAsFixed(2) : '',
    );
    double getAmountAfterDiscount() {
      final pct = double.tryParse(discountController.text.trim());
      if (pct == null || pct <= 0) return baseAmount;
      if (pct >= 100) return 0.0;
      return baseAmount * (1 - pct / 100);
    }

    String paymentType = 'not_paid';
    Future<({double amount, String status})?> dialogFuture = showDialog<({double amount, String status})?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amountAfterDiscount = getAmountAfterDiscount();
            return AlertDialog(
              title: Text(l10n.sessionPayment),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l10n.amount}: ${NumberFormat.currency(symbol: '').format(baseAmount)}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountController,
                      decoration: InputDecoration(
                        labelText: l10n.discountPercent,
                        hintText: '0',
                        suffixText: '%',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (amountAfterDiscount != baseAmount || (discountController.text.trim().isNotEmpty && double.tryParse(discountController.text.trim()) != 0)) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${l10n.amountAfterDiscount}: ${NumberFormat.currency(symbol: '').format(amountAfterDiscount)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    RadioListTile<String>(
                      title: Text(l10n.paid),
                      value: 'paid',
                      groupValue: paymentType,
                      onChanged: (v) => setDialogState(() => paymentType = v!),
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.partialPaid),
                      value: 'partial',
                      groupValue: paymentType,
                      onChanged: (v) => setDialogState(() => paymentType = v!),
                    ),
                    if (paymentType == 'partial')
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 4),
                        child: TextField(
                          controller: partialController,
                          decoration: InputDecoration(
                            labelText: l10n.amountPaid,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                    RadioListTile<String>(
                      title: Text(l10n.prepaid),
                      value: 'prepaid',
                      groupValue: paymentType,
                      onChanged: (v) => setDialogState(() => paymentType = v!),
                    ),
                    RadioListTile<String>(
                      title: Text(l10n.notPaid),
                      value: 'not_paid',
                      groupValue: paymentType,
                      onChanged: (v) => setDialogState(() => paymentType = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final sessionAmount = getAmountAfterDiscount();
                    final pctRaw = double.tryParse(discountController.text.trim());
                    final newDiscountPercent = (pctRaw != null && pctRaw > 0 && pctRaw < 100) ? pctRaw : null;
                    final statusValue = paymentType == 'partial' ? 'partial_paid' : paymentType;
                    await _firestore.updateAppointment(a.id, {
                      'costAmount': sessionAmount,
                      'discountPercent': newDiscountPercent,
                      'sessionPaymentStatus': statusValue,
                    });
                    if (paymentType == 'paid') {
                      Navigator.pop(ctx, (amount: sessionAmount, status: 'paid'));
                    } else if (paymentType == 'partial') {
                      final v = double.tryParse(partialController.text.trim());
                      Navigator.pop(ctx, (amount: v != null && v > 0 ? v : 0.0, status: 'partial_paid'));
                    } else if (paymentType == 'prepaid') {
                      Navigator.pop(ctx, (amount: 0.0, status: 'prepaid'));
                    } else {
                      Navigator.pop(ctx, (amount: 0.0, status: 'not_paid'));
                    }
                  },
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      },
    );
    return dialogFuture.whenComplete(() {
      discountController.dispose();
      partialController.dispose();
    });
  }

  void _logAppointmentAction(BuildContext context, String action, AppointmentModel a, AppointmentStatus newStatus) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    AuditService.log(
      action: action,
      entityType: 'appointment',
      entityId: a.id,
      userId: user.id,
      userEmail: user.email,
      details: {'patientId': a.patientId, 'doctorId': a.doctorId, 'status': newStatus.value},
    );
  }

  /// Appointment ids that are the patient's first ever session (New Patient) — earliest by date+time in the list.
  Set<String> _firstSessionIdsNewPatient(List<AppointmentModel> list) {
    final byPatient = <String, AppointmentModel>{};
    for (final a in list) {
      final existing = byPatient[a.patientId];
      if (existing == null) {
        byPatient[a.patientId] = a;
      } else {
        final cmp = a.appointmentDate.compareTo(existing.appointmentDate);
        if (cmp < 0 || (cmp == 0 && _compareTime(a.startTime, existing.startTime) < 0)) {
          byPatient[a.patientId] = a;
        }
      }
    }
    return byPatient.values.map((a) => a.id).toSet();
  }

  Widget _buildScheduleView(BuildContext context, DataCacheProvider cache, AppLocalizations l10n, UserModel? auth, bool canUpdate) {
    final list = _list.where((a) => a.status != AppointmentStatus.cancelled).toList();
    final firstSessionIds = _firstSessionIdsNewPatient(list);
    final roomHeaders = [
      cache.rooms.length > 0 ? cache.rooms[0].displayName : '1',
      cache.rooms.length > 1 ? cache.rooms[1].displayName : '2',
      cache.rooms.length > 2 ? cache.rooms[2].displayName : '3',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(AppDateFormat.mediumDate().format(_scheduleDate), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 12),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(l10n.date),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _scheduleDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _scheduleDate = d);
                },
              ),
            ],
          ),
        ),
        _scheduleColorLegend(context, l10n),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minTableHeight = constraints.maxHeight;
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minTableHeight, minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                      columns: [
                        DataColumn(label: Text(l10n.time)),
                        DataColumn(label: Text(roomHeaders[0])),
                        DataColumn(label: Text(roomHeaders[1])),
                        DataColumn(label: Text(roomHeaders[2])),
                        DataColumn(label: Text(l10n.extraSlot)),
                      ],
                      rows: _scheduleHours.map((hour) {
                        final slotApps = _appointmentsForSlot(_scheduleDate, hour, list);
                        return DataRow(
                          cells: [
                            DataCell(Text(hour)),
                            DataCell(_slotCell(_appointmentForCell(0, slotApps, cache.rooms), hour, false, cache, l10n, auth, canUpdate, firstSessionIds)),
                            DataCell(_slotCell(_appointmentForCell(1, slotApps, cache.rooms), hour, false, cache, l10n, auth, canUpdate, firstSessionIds)),
                            DataCell(_slotCell(_appointmentForCell(2, slotApps, cache.rooms), hour, false, cache, l10n, auth, canUpdate, firstSessionIds)),
                            DataCell(_slotCell(_appointmentForCell(3, slotApps, cache.rooms), hour, true, cache, l10n, auth, canUpdate, firstSessionIds)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Status colors: Attended=green, Pending=blue, Absent=red, Apologized=orange.
  static Color? _colorForStatus(AppointmentStatus? status) {
    if (status == null) return null;
    switch (status) {
      case AppointmentStatus.completed: return const Color(0xFF4CAF50); // green
      case AppointmentStatus.pending:
      case AppointmentStatus.confirmed: return const Color(0xFF2196F3); // blue (pending)
      case AppointmentStatus.noShow:
      case AppointmentStatus.absentWithoutCause: return const Color(0xFFF44336); // red
      case AppointmentStatus.absentWithCause: return const Color(0xFFFF9800); // orange (apologized)
      case AppointmentStatus.cancelled: return null;
    }
  }

  Widget _scheduleColorLegend(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _legendChip(context, const Color(0xFF4CAF50), l10n.attended),
          _legendChip(context, const Color(0xFF2196F3), l10n.pending),
          _legendChip(context, const Color(0xFFF44336), l10n.absent),
          _legendChip(context, const Color(0xFFFF9800), l10n.apologized),
          _legendChipWithIcon(context, const Color(0xFFE8EAF6), l10n.newPatient, Icons.star),
          _legendChipWithIcon(context, const Color(0xFFE8EAF6), l10n.starredSessionVip, Icons.star),
        ],
      ),
    );
  }

  Widget _legendChip(BuildContext context, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _legendChipWithIcon(BuildContext context, Color color, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _slotCell(AppointmentModel? a, String startTime, bool isExtraSlotColumn, DataCacheProvider cache, AppLocalizations l10n, UserModel? auth, bool canUpdate, Set<String> firstSessionIds) {
    final label = a != null ? (cache.userName(a.patientId) ?? a.patientId) : '—';
    final statusColor = _colorForStatus(a?.status);
    final isFirstSession = a != null && firstSessionIds.contains(a.id);
    final isStarredSession = a?.isStarred == true;
    final showStar = isFirstSession || isStarredSession;
    final bgColor = statusColor != null
        ? statusColor.withValues(alpha: 0.4)
        : (showStar ? const Color(0xFFE8EAF6).withValues(alpha: 0.5) : null);
    return InkWell(
      onTap: canUpdate
          ? () async {
              if (a != null) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AppointmentFormDialog(
                    existing: a,
                    currentUserId: auth?.id,
                    patients: cache.patients,
                    doctors: cache.doctors,
                    rooms: cache.rooms,
                    services: cache.services,
                    packages: _packages,
                    allowPastDate: auth?.hasRole(UserRole.admin) == true || auth?.hasRole(UserRole.supervisor) == true,
                  ),
                );
                if (ok == true && mounted) {
                  final updated = await _firestore.getAppointmentById(a.id);
                  if (updated != null) _updateListAfterChange(a.id, replacement: updated);
                }
              } else {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AppointmentFormDialog(
                    currentUserId: auth?.id,
                    patients: cache.patients,
                    doctors: cache.doctors,
                    rooms: cache.rooms,
                    services: cache.services,
                    packages: _packages,
                    initialDate: _scheduleDate,
                    initialStartTime: startTime,
                    initialEndTime: _nextSlot(startTime),
                    initialIsExtraSlot: isExtraSlotColumn,
                    allowPastDate: auth?.hasRole(UserRole.admin) == true || auth?.hasRole(UserRole.supervisor) == true,
                  ),
                );
                if (ok == true && mounted) { _subscription?.cancel(); _startAppointmentsStream(); }
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          border: statusColor != null ? Border(left: BorderSide(width: 3, color: statusColor)) : null,
        ),
        child: Row(
          children: [
            if (showStar)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
              ),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  /// Monday 00:00 and Sunday 23:59 for the week containing [date].
  static (DateTime start, DateTime end) _weekRange(DateTime date) {
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    final start = DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
    return (start, end);
  }

  /// Same filters as _displayList but date restricted to the week containing [_filterDay] or [_scheduleDate] or today.
  List<AppointmentModel> _displayListForWeek(DataCacheProvider cache) {
    final refDate = _filterDay ?? _scheduleDate;
    final (weekStart, weekEnd) = _weekRange(refDate);
    var out = _list;
    if (_statusFilter != null) {
      if (_statusFilter == AppointmentStatus.noShow) {
        out = out.where((a) => a.status == AppointmentStatus.noShow || a.status == AppointmentStatus.absentWithCause || a.status == AppointmentStatus.absentWithoutCause).toList();
      } else if (_statusFilter == AppointmentStatus.absentWithCause) {
        out = out.where((a) => a.status == AppointmentStatus.absentWithCause).toList();
      } else if (_statusFilter == AppointmentStatus.absentWithoutCause) {
        out = out.where((a) => a.status == AppointmentStatus.absentWithoutCause || a.status == AppointmentStatus.noShow).toList();
      } else {
        out = out.where((a) => a.status == _statusFilter!).toList();
      }
    }
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      out = out.where((a) => a.doctorId == _filterDoctorId).toList();
    }
    out = out.where((a) => !a.appointmentDate.isBefore(weekStart) && !a.appointmentDate.isAfter(weekEnd)).toList();
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((a) {
        final patientName = (cache.userName(a.patientId) ?? a.patientId).toLowerCase();
        final doctorName = (cache.doctorDisplayName(a.doctorId) ?? a.doctorId).toLowerCase();
        final serviceMatch = a.services.any((s) => s.toLowerCase().contains(q));
        return patientName.contains(q) || doctorName.contains(q) || serviceMatch;
      }).toList();
    }
    return out;
  }

  /// List to display: excludes cancelled; filtered by status, date (day/month/year), search; sorted by date then startTime.
  List<AppointmentModel> _displayList(DataCacheProvider cache) {
    var out = _list;
    if (_statusFilter != null) {
      if (_statusFilter == AppointmentStatus.noShow) {
        out = out.where((a) => a.status == AppointmentStatus.noShow || a.status == AppointmentStatus.absentWithCause || a.status == AppointmentStatus.absentWithoutCause).toList();
      } else if (_statusFilter == AppointmentStatus.absentWithCause) {
        out = out.where((a) => a.status == AppointmentStatus.absentWithCause).toList();
      } else if (_statusFilter == AppointmentStatus.absentWithoutCause) {
        out = out.where((a) => a.status == AppointmentStatus.absentWithoutCause || a.status == AppointmentStatus.noShow).toList();
      } else {
        out = out.where((a) => a.status == _statusFilter!).toList();
      }
    }
    if (_filterDay != null) {
      final d = _filterDay!;
      out = out.where((a) => a.appointmentDate.year == d.year && a.appointmentDate.month == d.month && a.appointmentDate.day == d.day).toList();
    } else if (_filterYear != null && _filterMonth != null) {
      out = out.where((a) => a.appointmentDate.year == _filterYear && a.appointmentDate.month == _filterMonth).toList();
    } else if (_filterYear != null) {
      out = out.where((a) => a.appointmentDate.year == _filterYear).toList();
    }
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      out = out.where((a) => a.doctorId == _filterDoctorId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((a) {
        final patientName = (cache.userName(a.patientId) ?? a.patientId).toLowerCase();
        final doctorName = (cache.doctorDisplayName(a.doctorId) ?? a.doctorId).toLowerCase();
        final serviceMatch = a.services.any((s) => s.toLowerCase().contains(q));
        return patientName.contains(q) || doctorName.contains(q) || serviceMatch;
      }).toList();
    }
    out.sort((a, b) {
      final dateCompare = a.appointmentDate.compareTo(b.appointmentDate);
      if (dateCompare != 0) return dateCompare;
      return _compareTime(a.startTime, b.startTime);
    });
    return out;
  }

  /// Compare time strings "HH:mm" (earlier = smaller). 24-hour order: 00:00 first, 23:30 last.
  static int _compareTime(String a, String b) {
    final aParts = a.split(':');
    final bParts = b.split(':');
    if (aParts.length >= 2 && bParts.length >= 2) {
      final aMins = (int.tryParse(aParts[0].trim()) ?? 0) * 60 + (int.tryParse(aParts[1].trim()) ?? 0);
      final bMins = (int.tryParse(bParts[0].trim()) ?? 0) * 60 + (int.tryParse(bParts[1].trim()) ?? 0);
      return aMins.compareTo(bMins);
    }
    return a.compareTo(b);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>().currentUser;
    final cache = context.watch<DataCacheProvider>();
    // View-only permission (appointments_view_all) can see list/schedule but cannot create or edit.
    final canUpdate = auth != null && auth.canAccessFeature('appointments');
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appointments),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            if (canUpdate)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.createAppointment,
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AppointmentFormDialog(
                      currentUserId: auth.id,
                      patients: cache.patients,
                      doctors: cache.doctors,
                      rooms: cache.rooms,
                      services: cache.services,
                      packages: _packages,
                      allowPastDate: auth.hasRole(UserRole.admin) || auth.hasRole(UserRole.supervisor),
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
                      selected: _statusFilter == null && _filterDoctorId == null,
                      onSelected: (_) => setState(() { _statusFilter = null; _filterDoctorId = null; }),
                    ),
                  ),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.pending), selected: _statusFilter == AppointmentStatus.pending, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.pending))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.confirmed), selected: _statusFilter == AppointmentStatus.confirmed, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.confirmed))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.attended), selected: _statusFilter == AppointmentStatus.completed, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.completed))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.apologized), selected: _statusFilter == AppointmentStatus.absentWithCause, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.absentWithCause))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.absent), selected: _statusFilter == AppointmentStatus.absentWithoutCause, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.absentWithoutCause))),
                  Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(l10n.absentAll), selected: _statusFilter == AppointmentStatus.noShow, onSelected: (_) => setState(() => _statusFilter = AppointmentStatus.noShow))),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(l10n.filterDay),
                      selected: _filterDay != null,
                      onSelected: (_) async {
                        if (_filterDay != null) { setState(() => _filterDay = null); return; }
                        final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                        if (d != null) setState(() { _filterDay = d; _filterMonth = null; _filterYear = null; });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(l10n.filterMonth),
                      selected: _filterMonth != null && _filterYear != null,
                      onSelected: (_) async {
                        if (_filterMonth != null && _filterYear != null) { setState(() { _filterMonth = null; _filterYear = null; _filterDay = null; }); return; }
                        final now = DateTime.now();
                        final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(2020), lastDate: DateTime(now.year + 1));
                        if (d != null) setState(() { _filterMonth = d.month; _filterYear = d.year; _filterDay = null; });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(l10n.filterYear),
                      selected: _filterYear != null && _filterMonth == null,
                      onSelected: (_) async {
                        if (_filterYear != null && _filterMonth == null) { setState(() { _filterYear = null; _filterDay = null; }); return; }
                        final y = await showDialog<int>(context: context, builder: (ctx) {
                          final years = List.generate(6, (i) => DateTime.now().year - 2 + i);
                          return AlertDialog(
                            title: Text(l10n.filterYear),
                            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: years.map((y) => ListTile(title: Text('$y'), onTap: () => Navigator.pop(ctx, y))).toList())),
                          );
                        });
                        if (y != null) setState(() { _filterYear = y; _filterMonth = null; _filterDay = null; });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_showDoctorFilter(context))
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String?>(
                        value: _filterDoctorId,
                        decoration: InputDecoration(
                          labelText: l10n.filterByDoctor,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text(l10n.filterAll)),
                          ...cache.doctors.map((d) => DropdownMenuItem<String?>(
                            value: d.id,
                            child: Text(cache.userName(d.userId) ?? d.displayName ?? d.id, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (v) => setState(() => _filterDoctorId = v),
                      ),
                    ),
                  if (_showDoctorFilter(context)) const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: SegmentedButton<bool>(
                      segments: [ButtonSegment(value: false, label: Text(l10n.listView), icon: const Icon(Icons.list)), ButtonSegment(value: true, label: Text(l10n.scheduleView), icon: const Icon(Icons.calendar_view_week))],
                      selected: {_scheduleView},
                      onSelectionChanged: (s) => setState(() => _scheduleView = s.first),
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final filtered = _displayList(cache);
                final weekList = _displayListForWeek(cache);
                final absentWithCauseCount = filtered.where((a) => a.status == AppointmentStatus.absentWithCause).length;
                final absentWithoutCauseCount = filtered.where((a) => a.status == AppointmentStatus.absentWithoutCause || a.status == AppointmentStatus.noShow).length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _CountChip(label: l10n.sessionsFiltered, count: filtered.length),
                      _CountChip(label: l10n.apologized, count: absentWithCauseCount),
                      _CountChip(label: l10n.absent, count: absentWithoutCauseCount),
                      _CountChip(label: l10n.sessionsThisWeek, count: weekList.length),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: l10n.searchAppointmentsHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _loading
            ? const Center(child: CircularProgressIndicator())
                  : _scheduleView
                      ? _buildScheduleView(context, cache, l10n, auth, canUpdate)
                          : _displayList(cache).isEmpty
                ? Center(child: Text(l10n.noData))
                : RefreshIndicator(
                    onRefresh: () async {
                      _subscription?.cancel();
                      _startAppointmentsStream();
                      await Future.delayed(const Duration(milliseconds: 400));
                    },
                            child: Builder(
                              builder: (context) {
                                final displayList = _displayList(cache);
                                final firstSessionIds = _firstSessionIdsNewPatient(_list.where((x) => x.status != AppointmentStatus.cancelled).toList());
                                return ListView(
                      padding: responsiveListPadding(context),
                                  children: [
                                    _scheduleColorLegend(context, l10n),
                                    ...List.generate(displayList.length, (i) {
                                      final a = displayList[i];
                                      final dateStr = AppDateFormat.shortDate.format(a.appointmentDate);
                                      final statusColor = _colorForStatus(a.status);
                                      final bgColor = statusColor?.withValues(alpha: 0.35) ?? Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
                                      final isFirstSession = firstSessionIds.contains(a.id);
                                      final isStarredSession = a.isStarred;
                                      final showStar = isFirstSession || isStarredSession;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                                    color: bgColor,
                          child: ListTile(
                                      title: Row(
                                        children: [
                                          if (showStar)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: Icon(Icons.star, size: 16, color: Theme.of(context).colorScheme.primary),
                                            ),
                                          Expanded(
                                            child: Text('${cache.userName(a.patientId) ?? a.patientId} • ${cache.doctorDisplayName(a.doctorId) ?? a.doctorId}'),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text('$dateStr ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status, l10n)}${a.hasServices ? ' • ${a.servicesDisplay}' : ''}'),
                            trailing: canUpdate
                                ? PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AppointmentFormDialog(
                                            existing: a,
                                            currentUserId: auth.id,
                                            patients: cache.patients,
                                            doctors: cache.doctors,
                                            rooms: cache.rooms,
                                            services: cache.services,
                                            packages: _packages,
                                            allowPastDate: auth.hasRole(UserRole.admin) || auth.hasRole(UserRole.supervisor),
                                          ),
                                        );
                                        if (ok == true && mounted) {
                                          final updated = await _firestore.getAppointmentById(a.id);
                                          if (updated != null) _updateListAfterChange(a.id, replacement: updated);
                                        }
                                      } else if (v == 'confirmed') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.confirmed);
                                        _updateListAfterChange(a.id, newStatus: AppointmentStatus.confirmed);
                                        _logAppointmentAction(context, 'appointment_confirmed', a, AppointmentStatus.confirmed);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'completed') {
                                        final result = await _showSessionPaymentDialog(context, a, l10n);
                                        if (result == null && mounted) return;
                                        if (result != null && mounted) {
                                          final sessionDateTime = _dateTimeFromAppointmentDateAndTime(a.appointmentDate, a.startTime);
                                          final income = IncomeRecordModel(
                                            id: '',
                                            amount: result.amount,
                                            currency: 'EGP',
                                            source: 'Session',
                                            doctorId: a.doctorId,
                                            patientId: a.patientId,
                                            notes: '${a.servicesDisplay.isNotEmpty ? a.servicesDisplay : 'Session'} • ${AppDateFormat.shortDate.format(a.appointmentDate)} ${a.startTime}',
                                            recordedByUserId: auth.id,
                                            incomeDate: sessionDateTime,
                                            appointmentId: a.id,
                                            sessionPaymentStatus: result.status,
                                          );
                                          await _firestore.addIncomeRecord(income);
                                        }
                                        if (!mounted) return;
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.completed);
                                        _updateListAfterChange(a.id, newStatus: AppointmentStatus.completed);
                                        _logAppointmentAction(context, 'appointment_completed', a, AppointmentStatus.completed);
                                        _notifyAppointmentStatusChange(a);
                                        _checkPackageCompleted(a, l10n);
                                      } else if (v == 'cancelled') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.cancelled);
                                        _updateListAfterChange(a.id, newStatus: AppointmentStatus.cancelled);
                                        _logAppointmentAction(context, 'appointment_cancelled', a, AppointmentStatus.cancelled);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'absentWithCause') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.absentWithCause);
                                        _updateListAfterChange(a.id, newStatus: AppointmentStatus.absentWithCause);
                                        _logAppointmentAction(context, 'appointment_absent_with_cause', a, AppointmentStatus.absentWithCause);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'absentWithoutCause') {
                                        await _firestore.updateAppointmentStatus(a.id, AppointmentStatus.absentWithoutCause);
                                        _updateListAfterChange(a.id, newStatus: AppointmentStatus.absentWithoutCause);
                                        _logAppointmentAction(context, 'appointment_absent_without_cause', a, AppointmentStatus.absentWithoutCause);
                                        _notifyAppointmentStatusChange(a);
                                      } else if (v == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(l10n.deleteConfirm),
                                            content: Text(l10n.deleteAppointmentAndIncomeConfirm),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
                                            ],
                                          ),
                                        );
                                        if (confirm != true || !mounted) return;
                                        await _firestore.deleteAppointment(a.id);
                                        _logAppointmentAction(context, 'appointment_deleted', a, a.status);
                                        if (mounted) setState(() => _list.removeWhere((x) => x.id == a.id));
                                        _notifyAppointmentStatusChange(a);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                      if (auth.canAccessAdminDashboard)
                                        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                      if (a.status != AppointmentStatus.completed && a.status != AppointmentStatus.cancelled) ...[
                                        PopupMenuItem(value: 'confirmed', child: Text(l10n.confirmed)),
                                        PopupMenuItem(value: 'completed', child: Text(l10n.attended)),
                                        PopupMenuItem(value: 'cancelled', child: Text(l10n.cancelled)),
                                        PopupMenuItem(value: 'absentWithCause', child: Text(l10n.apologized)),
                                        PopupMenuItem(value: 'absentWithoutCause', child: Text(l10n.absent)),
                                      ],
                                    ],
                                  )
                                : null,
                          ),
                                  );
                                }),
                                  ],
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 6),
          Text('$count', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
