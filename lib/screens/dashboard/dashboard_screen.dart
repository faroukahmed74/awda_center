import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/app_logo.dart';
import '../../core/date_format.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import '../patients/add_patient_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _todayAppointmentsCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final isRtl = l10n.isArabic;
    // Sync current locale to Firestore so push notifications use the right language
    final localeCode = context.watch<LocaleProvider>().locale.languageCode;
    if (user.id.isNotEmpty) {
      FirestoreService().updateUserLocale(user.id, localeCode);
    }

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
            if (!kIsWeb && !user.hasRole(UserRole.patient))
              IconButton(
                icon: const Icon(Icons.person_add),
                tooltip: l10n.addNewPatient,
                onPressed: () async {
                  final patientId = await showDialog<String>(
                    context: context,
                    builder: (_) => const AddPatientDialog(),
                  );
                  if (patientId != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.patientAdded)),
                    );
                    context.push('/patients/$patientId');
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: l10n.isArabic ? 'English' : 'العربية',
              onPressed: () => context.read<LocaleProvider>().toggleLocale(),
            ),
            IconButton(
              icon: Icon(context.watch<ThemeProvider>().isDark ? Icons.light_mode : Icons.dark_mode),
              tooltip: 'Theme',
              onPressed: () => context.read<ThemeProvider>().toggleDarkLight(),
            ),
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
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AppLogo(size: responsiveDrawerHeaderLogoSize(context)),
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
                      onTap: () { Navigator.pop(context); },
                    ),
                    if (canAccessRoute(user, '/admin-dashboard')) ...[
                      ListTile(
                        leading: const Icon(Icons.admin_panel_settings),
                        title: Text(l10n.adminDashboard),
                        onTap: () { Navigator.pop(context); context.push('/admin-dashboard'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.meeting_room),
                        title: Text(l10n.rooms),
                        onTap: () { Navigator.pop(context); context.push('/rooms'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.miscellaneous_services),
                        title: Text(l10n.services),
                        onTap: () { Navigator.pop(context); context.push('/services'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(l10n.packages),
                        onTap: () { Navigator.pop(context); context.push('/packages'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: Text(l10n.manageDoctors),
                        onTap: () { Navigator.pop(context); context.push('/doctors-admin'); },
                      ),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(l10n.auditLog),
                        onTap: () { Navigator.pop(context); context.push('/audit-log'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/users')) ...[
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: Text(l10n.users),
                        onTap: () { Navigator.pop(context); context.push('/users'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/appointments')) ...[
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(l10n.appointments),
                        onTap: () { Navigator.pop(context); context.push('/appointments'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/doctors')) ...[
                      ListTile(
                        leading: const Icon(Icons.medical_services_outlined),
                        title: Text(l10n.ourDoctors),
                        onTap: () { Navigator.pop(context); context.push('/doctors'); },
                      ),
                    ],
                    ListTile(
                      leading: const Icon(Icons.request_quote_outlined),
                      title: Text(l10n.priceQuote),
                      onTap: () { Navigator.pop(context); context.push('/price-quote'); },
                    ),
                    if (canAccessRoute(user, '/my-doctor-profile')) ...[
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(l10n.myDoctorProfile),
                        onTap: () { Navigator.pop(context); context.push('/my-doctor-profile'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/my-appointments')) ...[
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(l10n.myAppointments),
                        onTap: () { Navigator.pop(context); context.push('/my-appointments'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/profile')) ...[
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(l10n.profile),
                        onTap: () { Navigator.pop(context); context.push('/profile'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/patients')) ...[
                      ListTile(
                        leading: const Icon(Icons.medical_services),
                        title: Text(l10n.patients),
                        onTap: () { Navigator.pop(context); context.push('/patients'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/income-expenses')) ...[
                      ListTile(
                        leading: const Icon(Icons.attach_money),
                        title: Text(l10n.incomeAndExpenses),
                        onTap: () { Navigator.pop(context); context.push('/income-expenses'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/income-expenses-summary')) ...[
                      ListTile(
                        leading: const Icon(Icons.summarize),
                        title: Text(l10n.financeSummary),
                        onTap: () { Navigator.pop(context); context.push('/income-expenses-summary'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/reports')) ...[
                      ListTile(
                        leading: const Icon(Icons.assessment),
                        title: Text(l10n.reports),
                        onTap: () { Navigator.pop(context); context.push('/reports'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/requirements')) ...[
                      ListTile(
                        leading: const Icon(Icons.shopping_cart_outlined),
                        title: Text(l10n.requirements),
                        onTap: () { Navigator.pop(context); context.push('/requirements'); },
                      ),
                    ],
                    if (canAccessRoute(user, '/admin-todos')) ...[
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(l10n.toDoList),
                        onTap: () { Navigator.pop(context); context.push('/admin-todos'); },
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
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                          if (!user.hasRole(UserRole.patient) || canAccessRoute(user, '/patients') || canAccessRoute(user, '/appointments')) ...[
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (!kIsWeb && !user.hasRole(UserRole.patient))
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.person_add, size: 20),
                                    label: Text(l10n.addNewPatient),
                                    onPressed: () async {
                                      final patientId = await showDialog<String>(
                                        context: context,
                                        builder: (_) => const AddPatientDialog(),
                                      );
                                      if (patientId != null && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(l10n.patientAdded)),
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
                                      Navigator.pop(context);
                                      context.push('/patients?focus=search');
                                    },
                                  ),
                                ],
                                if (canAccessRoute(user, '/appointments')) ...[
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.calendar_today, size: 20),
                                    label: Text(l10n.bookAppointment),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      context.push('/appointments');
                                    },
                                  ),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.today, size: 20),
                                    label: Text(_todayAppointmentsCount != null
                                        ? '${l10n.todayAppointments} ($_todayAppointmentsCount)'
                                        : l10n.todayAppointments),
                                    onPressed: () {
                                      Navigator.pop(context);
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
                              if (mounted) setState(() => _todayAppointmentsCount = count);
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
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
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
  State<_DashboardAppointmentsSection> createState() => _DashboardAppointmentsSectionState();
}

class _DashboardAppointmentsSectionState extends State<_DashboardAppointmentsSection> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _appointments = [];
  Map<String, String> _names = {};
  /// Patient id -> (name, email, phone, code) for search by name/email/phone/code.
  final Map<String, ({String name, String email, String phone})> _patientData = {};
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
      _subscription = _firestore.appointmentsStream(patientId: user.id).listen(_onSnapshot);
    } else if (user.hasRole(UserRole.doctor) && !user.hasRole(UserRole.admin)) {
      if (user.canAccessFeature('appointments_see_all') || user.canAccessFeature('appointments_view_all')) {
        _subscription?.cancel();
        _subscription = _firestore.appointmentsStream().listen(_onSnapshot);
      } else {
        _firestore.getDoctorByUserId(user.id).then((doc) {
          if (!mounted) return;
          if (doc != null) {
            _subscription?.cancel();
            _subscription = _firestore.appointmentsStream(doctorId: doc.id).listen(_onSnapshot);
          } else {
            setState(() => _loading = false);
          }
        });
      }
    } else if (user.canAccessFeature('appointments') || user.canAccessFeature('appointments_view_all')) {
      _subscription?.cancel();
      _subscription = _firestore.appointmentsStream().listen(_onSnapshot);
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final to = todayStart.add(const Duration(days: 400));
    var list = snapshot.docs
        .map((d) => AppointmentModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
        .where((a) => a.status != AppointmentStatus.cancelled)
        .where((a) => !a.appointmentDate.isBefore(todayStart) && a.appointmentDate.isBefore(to))
        .toList();
    list.sort((a, b) {
      int c = a.appointmentDate.compareTo(b.appointmentDate);
      if (c != 0) return c;
      return a.startTime.compareTo(b.startTime);
    });
    if (!mounted) return;
    setState(() => _appointments = list);
    if (list.isEmpty) setState(() => _loading = false);
    else _loadNamesAndPatientData(list);
  }

  Future<void> _loadNamesAndPatientData(List<AppointmentModel> list) async {
    final ids = <String>{};
    for (final a in list) {
      ids.add(a.patientId);
      ids.add(a.doctorId);
    }
    final names = <String, String>{};
    for (final id in ids) {
      final u = await _firestore.getUser(id);
      if (u != null) {
        names[id] = u.displayName;
        _patientData[id] = (name: u.displayName, email: u.email, phone: u.phone ?? '');
      } else {
        final d = await _firestore.getDoctorById(id);
        if (d != null) {
          final du = await _firestore.getUser(d.userId);
          names[id] = du?.displayName ?? d.displayName ?? id;
        }
      }
    }
    if (mounted) setState(() {
      _names = names;
      _loading = false;
    });
  }

  /// Date range for current period (start inclusive, end exclusive).
  (DateTime start, DateTime end) _periodRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _DashboardPeriod.today:
        return (today, today.add(const Duration(days: 1)));
      case _DashboardPeriod.week:
        return (today, today.add(const Duration(days: 7)));
      case _DashboardPeriod.month:
        return (today, today.add(const Duration(days: 31)));
      case _DashboardPeriod.year:
        return (today, today.add(const Duration(days: 366)));
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    final (start, end) = _periodRange();
    final q = _searchController.text.trim().toLowerCase();
    var list = _appointments
        .where((a) => !a.appointmentDate.isBefore(start) && a.appointmentDate.isBefore(end))
        .toList();
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      list = list.where((a) => a.doctorId == _filterDoctorId).toList();
    }
    if (q.isNotEmpty && _patientData.isNotEmpty) {
      list = list.where((a) {
        final p = _patientData[a.patientId];
        if (p == null) return true;
        return p.name.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q) ||
            p.phone.toLowerCase().contains(q);
      }).toList();
    }
    list.sort((a, b) {
      int c = a.appointmentDate.compareTo(b.appointmentDate);
      if (c != 0) return c;
      return a.startTime.compareTo(b.startTime);
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
      case AppointmentStatus.pending: return l10n.pending;
      case AppointmentStatus.confirmed: return l10n.confirmed;
      case AppointmentStatus.completed: return l10n.attended;
      case AppointmentStatus.cancelled: return l10n.cancelled;
      case AppointmentStatus.noShow: return l10n.absent;
      case AppointmentStatus.absentWithCause: return l10n.apologized;
      case AppointmentStatus.absentWithoutCause: return l10n.absent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final user = widget.user;
    final isPatient = user.hasRole(UserRole.patient);
    final isDoctor = user.hasRole(UserRole.doctor);
    final canSeeAppointments = user.canAccessFeature('appointments');
    if (!isPatient && !isDoctor && !canSeeAppointments) return const SizedBox.shrink();

    final padding = ResponsivePadding.all(context);
    final cache = context.watch<DataCacheProvider>();
    final filtered = _filteredAppointments;
    final count = filtered.length;

    if (!_loading && _period == _DashboardPeriod.today && _lastReportedTodayCount != count) {
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
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Flexible(child: Text(l10n.todayAppointments, overflow: TextOverflow.ellipsis)),
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
                    context.push(isPatient ? '/my-appointments' : '/appointments');
                  },
                  child: Text(isPatient ? l10n.myAppointments : l10n.appointments),
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
                  onSelected: (_) => setState(() => _period = _DashboardPeriod.today),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisWeek),
                  selected: _period == _DashboardPeriod.week,
                  onSelected: (_) => setState(() => _period = _DashboardPeriod.week),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisMonth),
                  selected: _period == _DashboardPeriod.month,
                  onSelected: (_) => setState(() => _period = _DashboardPeriod.month),
                ),
                ChoiceChip(
                  label: Text(l10n.filterThisYear),
                  selected: _period == _DashboardPeriod.year,
                  onSelected: (_) => setState(() => _period = _DashboardPeriod.year),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            ],
            if (!isPatient) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.noData, style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              ...filtered.take(15).map((a) {
                final otherName = isPatient
                    ? (_names[a.doctorId] ?? a.doctorId)
                    : isDoctor
                        ? (_names[a.patientId] ?? a.patientId)
                        : '${_names[a.patientId] ?? a.patientId} • ${_names[a.doctorId] ?? a.doctorId}';
                final subtitle = '${AppDateFormat.shortDate.format(a.appointmentDate)} ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status)}${a.hasServices ? ' • ${a.servicesDisplay}' : ''}';
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
                      maxLines: 2,
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
