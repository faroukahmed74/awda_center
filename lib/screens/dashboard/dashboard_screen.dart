import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/app_logo.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
import '../../router/app_router.dart';
import '../../services/firestore_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
              Flexible(child: Text(l10n.appTitle)),
            ],
          ),
          actions: [
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
                          AppLogo(size: Breakpoint.isDesktop(context) ? 56 : 48),
                          const SizedBox(height: 8),
                          Text(
                            user.displayName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(l10n.roleDisplay(user.role.value), style: Theme.of(context).textTheme.bodySmall),
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
                          const SizedBox(height: 24),
                          _DashboardAppointmentsSection(user: user, l10n: l10n),
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

/// Loads and shows today/upcoming appointments for the current user (patient or doctor) on the home screen.
class _DashboardAppointmentsSection extends StatefulWidget {
  final UserModel user;
  final AppLocalizations l10n;

  const _DashboardAppointmentsSection({required this.user, required this.l10n});

  @override
  State<_DashboardAppointmentsSection> createState() => _DashboardAppointmentsSectionState();
}

class _DashboardAppointmentsSectionState extends State<_DashboardAppointmentsSection> {
  final FirestoreService _firestore = FirestoreService();
  List<AppointmentModel> _appointments = [];
  Map<String, String> _names = {};
  bool _loading = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    final user = widget.user;

    setState(() => _loading = true);
    if (user.hasRole(UserRole.patient)) {
      _subscription?.cancel();
      _subscription = _firestore.appointmentsStream(patientId: user.id).listen(_onSnapshot);
    } else if (user.hasRole(UserRole.doctor)) {
      _firestore.getDoctorByUserId(user.id).then((doc) {
        if (!mounted) return;
        if (doc != null) {
          _subscription?.cancel();
          _subscription = _firestore.appointmentsStream(doctorId: doc.id).listen(_onSnapshot);
        } else {
          setState(() => _loading = false);
        }
      });
    } else if (user.canAccessFeature('appointments')) {
      _subscription?.cancel();
      _subscription = _firestore.appointmentsStream().listen(_onSnapshot);
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final to = todayStart.add(const Duration(days: 14));
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
    else _loadNames(list);
  }

  Future<void> _loadNames(List<AppointmentModel> list) async {
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

  String _statusLabel(AppointmentStatus s) {
    final l10n = widget.l10n;
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
    final l10n = widget.l10n;
    final user = widget.user;
    final isPatient = user.hasRole(UserRole.patient);
    final isDoctor = user.hasRole(UserRole.doctor);
    final canSeeAppointments = user.canAccessFeature('appointments');
    // Show section for patients (their appointments), doctors (their appointments), or users with appointments feature
    if (!isPatient && !isDoctor && !canSeeAppointments) return const SizedBox.shrink();

    final padding = ResponsivePadding.all(context);

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
                    l10n.todayAppointments,
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
            if (_appointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l10n.noData, style: Theme.of(context).textTheme.bodyMedium),
              )
            else
              ..._appointments.take(10).map((a) {
                final otherName = isPatient
                    ? (_names[a.doctorId] ?? a.doctorId)
                    : isDoctor
                        ? (_names[a.patientId] ?? a.patientId)
                        : '${_names[a.patientId] ?? a.patientId} • ${_names[a.doctorId] ?? a.doctorId}';
                final subtitle = '${DateFormat.yMd().format(a.appointmentDate)} ${a.startTime} - ${a.endTime} • ${_statusLabel(a.status)}${a.service != null && a.service!.isNotEmpty ? ' • ${a.service}' : ''}';
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
