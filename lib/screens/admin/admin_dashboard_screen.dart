import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'invite_user_dialog.dart';
import 'migrate_staff_patients_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestore = FirestoreService();
  Map<String, int>? _stats;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _firestore.getAdminStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('AdminDashboardScreen _loadStats error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
  }

  Future<void> _openInviteUser() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const InviteUserDialog());
    if (ok == true && mounted) _loadStats();
  }

  Future<void> _openMigrateStaffPatients() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const MigrateStaffPatientsDialog());
    if (ok == true && mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isRtl = l10n.isArabic;
    if (user == null || !user.canAccessAdminDashboard) {
      return const Scaffold(body: Center(child: Text('Admin only')));
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminDashboard),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: const [NotificationsButton()],
        ),
        body: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            padding: ResponsivePadding.all(context),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Breakpoint.isDesktop(context) ? 1200 : responsiveMaxContentWidth(context),
                ),
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                    : _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                                  const SizedBox(height: 16),
                                  Text(_errorMessage!, textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _loadStats),
                                ],
                              ),
                            ),
                          )
                        : _stats == null
                            ? const SizedBox.shrink()
                            : Breakpoint.isDesktop(context)
                                ? _buildDesktopLayout(context, l10n, user)
                                : _buildMobileLayout(context, l10n, user),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsAndManage(BuildContext context, AppLocalizations l10n, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.welcome,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: l10n.totalUsers,
                value: '${_stats!['totalUsers'] ?? 0}',
                icon: Icons.people,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: l10n.activeUsers,
                value: '${_stats!['activeUsers'] ?? 0}',
                icon: Icons.check_circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: l10n.todayAppointments,
                value: '${_stats!['todayAppointments'] ?? 0}',
                icon: Icons.calendar_today,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: l10n.thisWeekAppointments,
                value: '${_stats!['weekAppointments'] ?? 0}',
                icon: Icons.calendar_month,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: l10n.patients,
                value: '${_stats!['totalPatients'] ?? 0}',
                icon: Icons.medical_services,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: l10n.ourDoctors,
                value: '${_stats!['totalDoctors'] ?? 0}',
                icon: Icons.badge,
              ),
            ),
          ],
        ),
        if (user.canAccessAdminTodos) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: l10n.openTodos,
                  value: '${_stats!['openTodos'] ?? 0}',
                  icon: Icons.task_alt,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
        const SizedBox(height: 24),
        if (user.canAccessUsers) ...[
          Text(l10n.manageUsers, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openInviteUser,
            icon: const Icon(Icons.person_add),
            label: Text(l10n.inviteUser),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => context.push('/users'),
            icon: const Icon(Icons.people),
            label: Text(l10n.users),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAccessTiles(BuildContext context, AppLocalizations l10n, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.quickAccess, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (user.canAccessUsers)
          _AdminTile(icon: Icons.people, title: l10n.users, onTap: () => context.push('/users')),
        if (user.canAccessAppointments)
          _AdminTile(icon: Icons.calendar_today, title: l10n.appointments, onTap: () => context.push('/appointments')),
        if (user.canAccessPatients)
          _AdminTile(icon: Icons.medical_services, title: l10n.patients, onTap: () => context.push('/patients')),
        if (user.canAccessIncomeExpenses)
          _AdminTile(icon: Icons.attach_money, title: l10n.incomeAndExpenses, onTap: () => context.push('/income-expenses')),
        if (user.canAccessReports)
          _AdminTile(icon: Icons.assessment, title: l10n.reports, onTap: () => context.push('/reports')),
        if (user.canAccessAdminDashboard) ...[
          _AdminTile(icon: Icons.meeting_room, title: l10n.rooms, onTap: () => context.push('/rooms')),
          _AdminTile(icon: Icons.badge, title: l10n.manageDoctors, onTap: () => context.push('/doctors-admin')),
          _AdminTile(icon: Icons.login, title: l10n.migrateStaffCreatedPatients, onTap: _openMigrateStaffPatients),
          _AdminTile(icon: Icons.history, title: l10n.auditLog, onTap: () => context.push('/audit-log')),
        ],
        if (user.canAccessRequirements)
          _AdminTile(icon: Icons.shopping_cart, title: l10n.requirements, onTap: () => context.push('/requirements')),
        if (user.canAccessAdminTodos)
          _AdminTile(icon: Icons.task_alt, title: l10n.toDoList, onTap: () => context.push('/admin-todos')),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppLocalizations l10n, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatsAndManage(context, l10n, user),
        const SizedBox(height: 24),
        _buildQuickAccessTiles(context, l10n, user),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppLocalizations l10n, UserModel user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildStatsAndManage(context, l10n, user),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _buildQuickAccessTiles(context, l10n, user),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AdminTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
