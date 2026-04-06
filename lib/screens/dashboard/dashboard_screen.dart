import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/app_logo.dart';
import '../../core/date_format.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../providers/locale_provider.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../../widgets/live_date_time_banner.dart';
import '../../widgets/main_app_bar_actions.dart';
import '../../widgets/notifications_button.dart';
import '../patients/add_patient_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _todayAppointmentsCount;
  String? _lastSyncedLocaleCode;
  String? _lastSyncedUserId;

  void _closeDrawerIfOpen() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().currentUser;
    final localeCode = context.read<LocaleProvider>().locale.languageCode;
    if (user != null &&
        user.id.isNotEmpty &&
        (_lastSyncedUserId != user.id || _lastSyncedLocaleCode != localeCode)) {
      _lastSyncedUserId = user.id;
      _lastSyncedLocaleCode = localeCode;
      unawaited(FirestoreService().updateUserLocale(user.id, localeCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: responsiveLogoSizeSmall(context)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l10n.appTitle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          actions: [
            const NotificationsButton(),
            if (!user.hasRole(UserRole.patient))
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: l10n.addNewPatient,
                onPressed: () async {
                  final patientId = await showDialog<String>(
                    context: context,
                    builder: (_) => const AddPatientDialog(),
                  );
                  if (patientId != null && mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.patientAdded)));
                    context.push('/patients/$patientId');
                  }
                },
              ),
            ...MainAppBarActions.languageAndTheme(context),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: l10n.logout,
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppLogo(
                            size: responsiveDrawerHeaderLogoSize(context),
                          ),
                          const SizedBox(height: 6),
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            l10n.roleDisplay(user.role.value),
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.dashboard),
                      title: Text(l10n.dashboard),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    if (canAccessRoute(user, '/admin-dashboard')) ...[
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: Text(l10n.adminDashboard),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/admin-dashboard');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.meeting_room),
                        title: Text(l10n.rooms),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/rooms');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.miscellaneous_services),
                        title: Text(l10n.services),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/services');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(l10n.packages),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/packages');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: Text(l10n.manageDoctors),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/doctors-admin');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(l10n.auditLog),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/audit-log');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/users')) ...[
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: Text(l10n.users),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/users');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/appointments')) ...[
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(l10n.appointments),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/appointments');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/doctors')) ...[
                      ListTile(
                        leading: const Icon(Icons.medical_services_outlined),
                        title: Text(l10n.ourDoctors),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/doctors');
                        },
                      ),
                    ],
                    ListTile(
                      leading: const Icon(Icons.request_quote_outlined),
                      title: Text(l10n.priceQuote),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/price-quote');
                      },
                    ),
                    if (canAccessRoute(user, '/my-doctor-profile')) ...[
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(l10n.myDoctorProfile),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my-doctor-profile');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/my-appointments')) ...[
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(l10n.myAppointments),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/my-appointments');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/profile')) ...[
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(l10n.profile),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/profile');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/patients')) ...[
                      ListTile(
                        leading: const Icon(Icons.medical_services),
                        title: Text(l10n.patients),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/patients');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/income-expenses')) ...[
                      ListTile(
                        leading: const Icon(Icons.attach_money),
                        title: Text(l10n.incomeAndExpenses),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/income-expenses');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/income-expenses-summary')) ...[
                      ListTile(
                        leading: const Icon(Icons.summarize),
                        title: Text(l10n.financeSummary),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/income-expenses-summary');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/reports')) ...[
                      ListTile(
                        leading: const Icon(Icons.assessment),
                        title: Text(l10n.reports),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/reports');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/requirements')) ...[
                      ListTile(
                        leading: const Icon(Icons.shopping_cart_outlined),
                        title: Text(l10n.requirements),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/requirements');
                        },
                      ),
                    ],
                    if (canAccessRoute(user, '/admin-todos')) ...[
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(l10n.toDoList),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/admin-todos');
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const _DrawerVersionFooter(),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = MediaQuery.sizeOf(context).width;
            final maxW = w >= Breakpoint.mobile ? 800.0 : double.infinity;
            return SafeArea(
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.translucent,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: ResponsivePadding.all(context),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${l10n.welcome}, ${user.displayName}',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.role}: ${user.roles.map((r) => l10n.roleDisplay(r)).join(", ")}',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          const LiveDateTimeBanner(),
                          if (!user.hasRole(UserRole.patient) ||
                              canAccessRoute(user, '/patients') ||
                              canAccessRoute(user, '/appointments')) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (!user.hasRole(UserRole.patient))
                                  FilledButton.tonalIcon(
                                    icon: const Icon(
                                      Icons.person_add,
                                      size: 20,
                                    ),
                                    label: Text(l10n.addNewPatient),
                                    onPressed: () async {
                                      final patientId =
                                          await showDialog<String>(
                                            context: context,
                                            builder: (_) =>
                                                const AddPatientDialog(),
                                          );
                                      if (patientId != null && mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.patientAdded),
                                          ),
                                        );
                                        context.push('/patients/$patientId');
                                      }
                                    },
                                  ),
                                if (canAccessRoute(user, '/patients')) ...[
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.search, size: 20),
                                    label: Text(l10n.findPatient),
                                    onPressed: () {
                                      _closeDrawerIfOpen();
                                      context.push('/patients?focus=search');
                                    },
                                  ),
                                ],
                                if (canAccessRoute(user, '/appointments')) ...[
                                  FilledButton.tonalIcon(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                    ),
                                    label: Text(l10n.bookAppointment),
                                    onPressed: () {
                                      _closeDrawerIfOpen();
                                      context.push('/appointments');
                                    },
                                  ),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.today, size: 20),
                                    label: Text(
                                      _todayAppointmentsCount != null
                                          ? '${l10n.todayAppointments} ($_todayAppointmentsCount)'
                                          : l10n.todayAppointments,
                                    ),
                                    onPressed: () {
                                      _closeDrawerIfOpen();
                                      context.push('/appointments');
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          _DashboardAppointmentsSection(
                            user: user,
                            l10n: l10n,
                            onTodayCountChanged: (count) {
                              if (mounted)
                                setState(() => _todayAppointmentsCount = count);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shows app version at the bottom of the drawer. All roles see it.
class _DrawerVersionFooter extends StatefulWidget {
  const _DrawerVersionFooter();

  @override
  State<_DrawerVersionFooter> createState() => _DrawerVersionFooterState();
}

class _DrawerVersionFooterState extends State<_DrawerVersionFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted)
        setState(() => _version = '${info.version}+${info.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          _version.isEmpty ? '—' : 'v$_version',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Period filter for dashboard appointments.
enum _DashboardPeriod { today, week, month, year }

/// Loads and shows appointments for the current user with period filter, search, and count.
class _DashboardAppointmentsSection extends StatefulWidget {
  final UserModel user;
  final AppLocalizations l10n;
  final void Function(int)? onTodayCountChanged;

  const _DashboardAppointmentsSection({
    required this.user,
    required this.l10n,
    this.onTodayCountChanged,
  });

  @override
  State<_DashboardAppointmentsSection> createState() =>
      _DashboardAppointmentsSectionState();
}

class _DashboardAppointmentsSectionState
    extends State<_DashboardAppointmentsSection> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _appointments = [];
  bool _loading = true;
  _DashboardPeriod _period = _DashboardPeriod.today;
  String? _filterDoctorId;
  final _searchController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  int? _lastReportedTodayCount;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listen() {
    final user = widget.user;
    setState(() => _loading = true);
    if (user.hasRole(UserRole.patient)) {
      _subscription?.cancel();
      _subscription = _firestore
          .appointmentsStream(patientId: user.id)
          .listen(_onSnapshot);
    } else if (user.hasRole(UserRole.doctor) && !user.hasRole(UserRole.admin)) {
      if (user.canAccessFeature('appointments_see_all') ||
          user.canAccessFeature('appointments_view_all')) {
        _subscription?.cancel();
        _subscription = _firestore.appointmentsStream().listen(_onSnapshot);
      } else {
        _firestore.getDoctorByUserId(user.id).then((doc) {
          if (!mounted) return;
          if (doc != null) {
            _subscription?.cancel();
            _subscription = _firestore
                .appointmentsStream(doctorId: doc.id)
                .listen(_onSnapshot);
          } else {
            setState(() => _loading = false);
          }
        });
      }
    } else if (user.canAccessFeature('appointments') ||
        user.canAccessFeature('appointments_view_all')) {
      _subscription?.cancel();
      _subscription = _firestore.appointmentsStream().listen(_onSnapshot);
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    var list = snapshot.docs
        .map(
          (d) => AppointmentModel.fromFirestore(
            d as DocumentSnapshot<Map<String, dynamic>>,
          ),
        )
        .where((a) => a.status != AppointmentStatus.cancelled)
        .toList();
    if (!mounted) return;
    setState(() {
      _appointments = list;
      _loading = false;
    });
  }

  /// Minutes since midnight for "HH:mm" (for same-day time sort).
  static int _minutesOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].trim()) ?? 0;
    return h * 60 + m;
  }

  /// Date range for current period (start inclusive, end exclusive).
  (DateTime start, DateTime end) _periodRange() {
    final now = DateTime.now();
    switch (_period) {
      case _DashboardPeriod.today:
        final today = DateTime(now.year, now.month, now.day);
        return (today, today.add(const Duration(days: 1)));
      case _DashboardPeriod.week:
        // Monday 00:00 to next Monday 00:00
        final weekday = now.weekday; // 1=Mon ... 7=Sun
        final weekStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 7));
        return (weekStart, weekEnd);
      case _DashboardPeriod.month:
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonthStart = DateTime(now.year, now.month + 1, 1);
        return (monthStart, nextMonthStart);
      case _DashboardPeriod.year:
        final yearStart = DateTime(now.year, 1, 1);
        final nextYearStart = DateTime(now.year + 1, 1, 1);
        return (yearStart, nextYearStart);
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    final (start, end) = _periodRange();
    final cache = context.read<DataCacheProvider>();
    final q = _searchController.text.trim().toLowerCase();
    var list = _appointments
        .where(
          (a) =>
              !a.appointmentDate.isBefore(start) &&
              a.appointmentDate.isBefore(end),
        )
        .toList();
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      list = list.where((a) => a.doctorId == _filterDoctorId).toList();
    }
    if (q.isNotEmpty) {
      list = list.where((a) {
        final patient = cache.users.cast<UserModel?>().firstWhere(
          (u) => u?.id == a.patientId,
          orElse: () => null,
        );
        if (patient == null) return true;
        return patient.displayName.toLowerCase().contains(q) ||
            patient.email.toLowerCase().contains(q) ||
            (patient.phone ?? '').toLowerCase().contains(q);
      }).toList();
    }
    // Sort by calendar date (newest first), then within same day by start time 00:00 -> 23:59.
    list.sort((a, b) {
      final aDay = DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day);
      final bDay = DateTime(b.appointmentDate.year, b.appointmentDate.month, b.appointmentDate.day);
      final c = bDay.compareTo(aDay);
      if (c != 0) return c;
      final aMins = _minutesOfDay(a.startTime);
      final bMins = _minutesOfDay(b.startTime);
      return aMins.compareTo(bMins);
    });
    return list;
  }

  String _periodTitle() {
    final l10n = widget.l10n;
    switch (_period) {
      case _DashboardPeriod.today:
        return l10n.todayAppointments;
      case _DashboardPeriod.week:
        return l10n.thisWeekAppointments;
      case _DashboardPeriod.month:
        return l10n.thisMonthAppointments;
      case _DashboardPeriod.year:
        return l10n.thisYearAppointments;
    }
  }

  /// Same status labels as Appointments screen so dashboard and appointments stay in sync.
  String _statusLabel(AppointmentStatus s) {
    final l10n = widget.l10n;
    switch (s) {
      case AppointmentStatus.pending:
        return l10n.pending;
      case AppointmentStatus.confirmed:
        return l10n.confirmed;
      case AppointmentStatus.completed:
        return l10n.attended;
      case AppointmentStatus.cancelled:
        return l10n.cancelled;
      case AppointmentStatus.noShow:
        return l10n.absent;
      case AppointmentStatus.absentWithCause:
        return l10n.apologized;
      case AppointmentStatus.absentWithoutCause:
        return l10n.absent;
    }
  }

  String _patientName(AppointmentModel appointment, DataCacheProvider cache) {
    return cache.userName(appointment.patientId) ?? appointment.patientId;
  }

  String _doctorName(AppointmentModel appointment, DataCacheProvider cache) {
    return cache.doctorDisplayName(appointment.doctorId) ??
        cache.userName(appointment.doctorId) ??
        appointment.doctorId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final user = widget.user;
    final isPatient = user.hasRole(UserRole.patient);
    final isDoctor = user.hasRole(UserRole.doctor);
    final canSeeAppointments = user.canAccessFeature('appointments');
    if (!isPatient && !isDoctor && !canSeeAppointments)
      return const SizedBox.shrink();

    final padding = ResponsivePadding.all(context);
    final cache = context.watch<DataCacheProvider>();
    final filtered = _filteredAppointments;
    final count = filtered.length;

    if (!_loading &&
        _period == _DashboardPeriod.today &&
        _lastReportedTodayCount != count) {
      _lastReportedTodayCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTodayCountChanged?.call(count);
      });
    }

    if (_loading) {
      return Card(
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.todayAppointments,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${_periodTitle()} ($count)',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(
                      isPatient ? '/my-appointments' : '/appointments',
                    );
                  },
                  child: Text(
                    isPatient ? l10n.myAppointments : l10n.appointments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text(l10n.filterToday),
                  selected: _period == _DashboardPeriod.today,
                  onSelected: (_) =>
                      setState(() => _period = _DashboardPeriod.today),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisWeek),
                  selected: _period == _DashboardPeriod.week,
                  onSelected: (_) =>
                      setState(() => _period = _DashboardPeriod.week),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisMonth),
                  selected: _period == _DashboardPeriod.month,
                  onSelected: (_) =>
                      setState(() => _period = _DashboardPeriod.month),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisYear),
                  selected: _period == _DashboardPeriod.year,
                  onSelected: (_) =>
                      setState(() => _period = _DashboardPeriod.year),
                ),
              ],
            ),
            if (!isPatient && !isDoctor) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<String?>(
                  value: _filterDoctorId,
                  decoration: InputDecoration(
                    labelText: l10n.filterByDoctor,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.filterAll),
                    ),
                    ...cache.doctors.map(
                      (d) => DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(
                          cache.userName(d.userId) ?? d.displayName ?? d.id,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterDoctorId = v),
                ),
              ),
            ],
            if (!isPatient) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.noData,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...filtered.take(15).map((a) {
                final otherName = isPatient
                    ? _doctorName(a, cache)
                    : isDoctor
                    ? _patientName(a, cache)
                    : '${_patientName(a, cache)} • ${_doctorName(a, cache)}';
                final subtitle = [
                  '${AppDateFormat.shortDate.format(a.appointmentDate)} ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status)}${a.hasServices ? ' • ${a.servicesDisplay}' : ''}',
                  if (a.notes != null && a.notes!.trim().isNotEmpty)
                    '${l10n.notes}: ${a.notes!.trim()}',
                ].join('\n');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      otherName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
