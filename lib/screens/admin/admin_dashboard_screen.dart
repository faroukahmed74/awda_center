import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'invite_user_dialog.dart';

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
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openInviteUser() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const InviteUserDialog());
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            padding: ResponsivePadding.all(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: responsiveMaxContentWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (_errorMessage != null)
                    Padding(
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
                  else if (_stats != null) ...[
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
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    Text('Administration', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _AdminTile(
                      icon: Icons.calendar_today,
                      title: l10n.appointments,
                      onTap: () => context.push('/appointments'),
                    ),
                    _AdminTile(
                      icon: Icons.medical_services,
                      title: l10n.patients,
                      onTap: () => context.push('/patients'),
                    ),
                    _AdminTile(
                      icon: Icons.attach_money,
                      title: l10n.incomeAndExpenses,
                      onTap: () => context.push('/income-expenses'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
