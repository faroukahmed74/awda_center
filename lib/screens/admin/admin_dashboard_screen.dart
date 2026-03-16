import 'dart:ui' as ui show ImageByteFormat;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/general_error_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'admin_dashboard_pdf.dart';
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
  Map<String, dynamic>? _chartData;
  bool _loading = true;
  bool _chartsLoading = true;
  String? _errorMessage;
  String _chartRange = 'week';
  final Map<String, String> _chartTypes = {'appointments': 'bar', 'incomeExpense': 'bar', 'usersByRole': 'pie'};
  final Map<String, GlobalKey> _chartKeys = {
    'appointments': GlobalKey(),
    'incomeExpense': GlobalKey(),
    'usersByRole': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _chartsLoading = true;
      _errorMessage = null;
    });
    try {
      final stats = await _firestore.getAdminStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('AdminDashboardScreen _loadStats error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e));
      });
    }
    try {
      final chartData = await _firestore.getAdminChartData(_chartRange);
      if (!mounted) return;
      setState(() {
        _chartData = chartData;
        _chartsLoading = false;
      });
    } catch (e) {
      debugPrint('AdminDashboardScreen _loadChartData error: $e');
      if (!mounted) return;
      setState(() => _chartsLoading = false);
    }
  }

  Future<void> _openInviteUser() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const InviteUserDialog());
    if (ok == true && mounted) _loadAll();
  }

  Future<void> _openMigrateStaffPatients() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const MigrateStaffPatientsDialog());
    if (ok == true && mounted) _loadAll();
  }

  String _formatMoney(num n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(0);
  }

  Widget _periodChip(AppLocalizations l10n, String value, String label) {
    final selected = _chartRange == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _chartRange = value;
          _chartsLoading = true;
        });
        _loadChartDataOnly();
      },
    );
  }

  Future<void> _loadChartDataOnly() async {
    try {
      final chartData = await _firestore.getAdminChartData(_chartRange);
      if (!mounted) return;
      setState(() {
        _chartData = chartData;
        _chartsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _chartsLoading = false);
    }
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          actions: const [NotificationsButton()],
        ),
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: SingleChildScrollView(
            padding: ResponsivePadding.all(context),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Breakpoint.isDesktop(context) ? 1400 : responsiveMaxContentWidth(context),
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
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
                                  FilledButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    onPressed: _loadAll,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _stats == null
                            ? const SizedBox.shrink()
                            : _buildContent(context, l10n, user),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, UserModel user) {
    final crossCount = _statGridCrossCount(context);
    final tileCrossCount = _tileGridCrossCount(context);
    final isDesktop = Breakpoint.isDesktop(context);
    final isTablet = Breakpoint.isTablet(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.welcome, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 20),
        // Stats grid (responsive: 2 / 3 / 4 columns)
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Taller cards so large numbers are fully visible above the charts
              childAspectRatio: isDesktop ? 1.15 : (isTablet ? 1.2 : 1.25),
              children: [
                _StatCard(
                  title: l10n.totalUsers,
                  value: '${_stats!['totalUsers'] ?? 0}',
                  icon: Icons.people,
                ),
                _StatCard(
                  title: l10n.activeUsers,
                  value: '${_stats!['activeUsers'] ?? 0}',
                  icon: Icons.check_circle,
                ),
                _StatCard(
                  title: l10n.todayAppointments,
                  value: '${_stats!['todayAppointments'] ?? 0}',
                  icon: Icons.calendar_today,
                ),
                _StatCard(
                  title: l10n.thisWeekAppointments,
                  value: '${_stats!['weekAppointments'] ?? 0}',
                  icon: Icons.calendar_month,
                ),
                _StatCard(
                  title: l10n.patients,
                  value: '${_stats!['totalPatients'] ?? 0}',
                  icon: Icons.medical_services,
                ),
                _StatCard(
                  title: l10n.ourDoctors,
                  value: '${_stats!['totalDoctors'] ?? 0}',
                  icon: Icons.badge,
                ),
                if (user.canAccessAdminTodos)
                  _StatCard(
                    title: l10n.openTodos,
                    value: '${_stats!['openTodos'] ?? 0}',
                    icon: Icons.task_alt,
                  ),
                _StatCard(title: l10n.totalRooms, value: '${_stats!['totalRooms'] ?? 0}', icon: Icons.meeting_room),
                _StatCard(title: l10n.totalServices, value: '${_stats!['totalServices'] ?? 0}', icon: Icons.medical_information),
                _StatCard(title: l10n.totalPackages, value: '${_stats!['totalPackages'] ?? 0}', icon: Icons.inventory_2),
                if (_chartData != null && _chartData!['periodTotals'] != null) ...[
                  _StatCard(
                    title: l10n.periodIncome,
                    value: _formatMoney((_chartData!['periodTotals'] as Map)['totalIncome'] as num? ?? 0),
                    icon: Icons.trending_up,
                  ),
                  _StatCard(
                    title: l10n.periodExpense,
                    value: _formatMoney((_chartData!['periodTotals'] as Map)['totalExpense'] as num? ?? 0),
                    icon: Icons.trending_down,
                  ),
                  _StatCard(
                    title: l10n.periodNet,
                    value: _formatMoney((_chartData!['periodTotals'] as Map)['totalNet'] as num? ?? 0),
                    icon: Icons.account_balance,
                  ),
                  _StatCard(
                    title: l10n.appointments,
                    value: '${(_chartData!['periodTotals'] as Map)['totalAppointments'] ?? 0}',
                    icon: Icons.event_note,
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        // Period filter for charts
        Text(l10n.filterByPeriod, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _periodChip(l10n, 'day', l10n.periodDay),
            _periodChip(l10n, 'week', l10n.periodWeek),
            _periodChip(l10n, 'month', l10n.periodMonth),
            _periodChip(l10n, '3months', l10n.period3Months),
            _periodChip(l10n, '6months', l10n.period6Months),
            _periodChip(l10n, '9months', l10n.period9Months),
            _periodChip(l10n, 'year', l10n.periodYear),
          ],
        ),
        const SizedBox(height: 20),
        // Charts section
        Text(l10n.statistics, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _chartsLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            : _chartData != null
                ? _buildChartsSection(context, l10n)
                : const SizedBox.shrink(),
        const SizedBox(height: 28),
        // Manage users (if access)
        if (user.canAccessUsers) ...[
          Text(l10n.manageUsers, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openInviteUser,
                icon: const Icon(Icons.person_add),
                label: Text(l10n.inviteUser),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/users'),
                icon: const Icon(Icons.people),
                label: Text(l10n.users),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        // Quick access (responsive grid)
        Text(l10n.quickAccess, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: tileCrossCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.2,
              children: _quickAccessTiles(context, l10n, user),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  int _statGridCrossCount(BuildContext context) {
    if (Breakpoint.isDesktop(context)) return 4;
    if (Breakpoint.isTablet(context)) return 3;
    return 2;
  }

  int _tileGridCrossCount(BuildContext context) {
    if (Breakpoint.isDesktop(context)) return 4;
    if (Breakpoint.isTablet(context)) return 3;
    return 2;
  }

  Widget _buildChartsSection(BuildContext context, AppLocalizations l10n) {
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoint.tablet;
    // Use larger height so charts stay within the stat section and don't overflow
    final chartHeight = isWide ? 320.0 : 280.0;
    final appointmentsByDay = _chartData!['appointmentsByDay'] as List<dynamic>? ?? [];
    final incomeExpenseByMonth = _chartData!['incomeExpenseByMonth'] as List<dynamic>? ?? [];
    final usersByRole = Map<String, int>.from(_chartData!['usersByRole'] as Map<dynamic, dynamic>? ?? {});
    final rangeLabel = _chartData!['rangeStart'] != null && _chartData!['rangeEnd'] != null
        ? '${DateFormat.yMd().format((_chartData!['rangeStart'] as DateTime))} - ${DateFormat.yMd().format((_chartData!['rangeEnd'] as DateTime))}'
        : _chartRange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appointmentsByDay.isNotEmpty) ...[
          _ChartCard(
            title: l10n.appointmentsLast7Days,
            chartKey: _chartKeys['appointments']!,
            chartType: _chartTypes['appointments']!,
            chartTypes: ['bar', 'line'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['appointments'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'appointments', l10n.appointmentsLast7Days, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['appointments'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['appointments'] == 'line'
                      ? _AppointmentsLineChart(data: appointmentsByDay, l10n: l10n)
                      : _AppointmentsBarChart(data: appointmentsByDay, l10n: l10n),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (incomeExpenseByMonth.isNotEmpty) ...[
          _ChartCard(
            title: l10n.incomeVsExpense6Months,
            chartKey: _chartKeys['incomeExpense']!,
            chartType: _chartTypes['incomeExpense']!,
            chartTypes: ['bar', 'line'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['incomeExpense'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'incomeExpense', l10n.incomeVsExpense6Months, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['incomeExpense'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['incomeExpense'] == 'line'
                      ? _IncomeExpenseLineChart(data: incomeExpenseByMonth, l10n: l10n)
                      : _IncomeExpenseBarChart(data: incomeExpenseByMonth, l10n: l10n),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (usersByRole.isNotEmpty) ...[
          _ChartCard(
            title: l10n.usersByRole,
            chartKey: _chartKeys['usersByRole']!,
            chartType: _chartTypes['usersByRole']!,
            chartTypes: ['pie', 'bar'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['usersByRole'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'usersByRole', l10n.usersByRole, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['usersByRole'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['usersByRole'] == 'bar'
                      ? _UsersByRoleBarChart(data: usersByRole, l10n: l10n)
                      : _UsersByRoleChart(data: usersByRole, l10n: l10n),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _exportChartPdf(AppLocalizations l10n, String chartId, String chartTitle, String rangeLabel) async {
    final key = _chartKeys[chartId];
    if (key?.currentContext == null) return;
    final boundary = key!.currentContext!.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      await AdminDashboardPdf.exportChartPdf(
        context: context,
        l10n: l10n,
        chartTitle: chartTitle,
        rangeLabel: rangeLabel,
        imageBytes: byteData.buffer.asUint8List(),
      );
    } catch (e) {
      debugPrint('AdminDashboard PDF export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.reportError)));
      }
    }
  }

  List<Widget> _quickAccessTiles(BuildContext context, AppLocalizations l10n, UserModel user) {
    final tiles = <Widget>[];
    if (user.canAccessUsers) tiles.add(_AdminTile(icon: Icons.people, title: l10n.users, onTap: () => context.push('/users')));
    if (user.canAccessAppointments) tiles.add(_AdminTile(icon: Icons.calendar_today, title: l10n.appointments, onTap: () => context.push('/appointments')));
    if (user.canAccessPatients) tiles.add(_AdminTile(icon: Icons.medical_services, title: l10n.patients, onTap: () => context.push('/patients')));
    if (user.canAccessIncomeExpenses) tiles.add(_AdminTile(icon: Icons.attach_money, title: l10n.incomeAndExpenses, onTap: () => context.push('/income-expenses')));
    if (user.canAccessFinanceSummary) tiles.add(_AdminTile(icon: Icons.summarize, title: l10n.financeSummary, onTap: () => context.push('/income-expenses-summary')));
    if (user.canAccessReports) tiles.add(_AdminTile(icon: Icons.assessment, title: l10n.reports, onTap: () => context.push('/reports')));
    if (user.canAccessAdminDashboard) {
      tiles.add(_AdminTile(icon: Icons.meeting_room, title: l10n.rooms, onTap: () => context.push('/rooms')));
      tiles.add(_AdminTile(icon: Icons.badge, title: l10n.manageDoctors, onTap: () => context.push('/doctors-admin')));
      tiles.add(_AdminTile(icon: Icons.medical_information, title: l10n.services, onTap: () => context.push('/services')));
      tiles.add(_AdminTile(icon: Icons.inventory_2, title: l10n.packages, onTap: () => context.push('/packages')));
      tiles.add(_AdminTile(icon: Icons.login, title: l10n.migrateStaffCreatedPatients, onTap: _openMigrateStaffPatients));
      tiles.add(_AdminTile(icon: Icons.history, title: l10n.auditLog, onTap: () => context.push('/audit-log')));
    }
    if (user.canAccessRequirements) tiles.add(_AdminTile(icon: Icons.shopping_cart, title: l10n.requirements, onTap: () => context.push('/requirements')));
    if (user.canAccessAdminTodos) tiles.add(_AdminTile(icon: Icons.task_alt, title: l10n.toDoList, onTap: () => context.push('/admin-todos')));
    return tiles;
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final GlobalKey chartKey;
  final String chartType;
  final List<String> chartTypes;
  final ValueChanged<String> onChartTypeChanged;
  final VoidCallback onExportPdf;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.chartKey,
    required this.chartType,
    required this.chartTypes,
    required this.onChartTypeChanged,
    required this.onExportPdf,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String chartTypeLabel(String t) {
      switch (t) {
        case 'bar': return l10n.barChart;
        case 'line': return l10n.lineChart;
        case 'pie': return l10n.pieChart;
        default: return t;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                if (chartTypes.length > 1)
                  Wrap(
                    spacing: 4,
                    children: chartTypes.map((t) {
                      final selected = chartType == t;
                      return ChoiceChip(
                        label: Text(chartTypeLabel(t), style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => onChartTypeChanged(t),
                      );
                    }).toList(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: l10n.exportPdf,
                  onPressed: onExportPdf,
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AppointmentsLineChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _AppointmentsLineChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Center(child: Text(AppLocalizations.of(context).noData));
    final theme = Theme.of(context);
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['count'] as num).toDouble())).toList();
    final maxY = (data.map<double>((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b) + 2).clamp(4.0, 100.0);
    final shortDate = DateFormat('EEE', l10n.isArabic ? 'ar' : 'en');
    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(enabled: true),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i >= 0 && i < data.length && data[i]['date'] is DateTime) {
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(shortDate.format(data[i]['date'] as DateTime), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)));
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withValues(alpha: 0.1)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _AppointmentsBarChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _AppointmentsBarChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final maxY = data.isEmpty
        ? 5.0
        : (data.map<double>((e) => (e['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.25 + 2)
            .clamp(6.0, 120.0);
    final shortDate = DateFormat('EEE', l10n.isArabic ? 'ar' : 'en');
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY.toInt().toString();
              return BarTooltipItem(
                value,
                TextStyle(
                  color: theme.brightness == Brightness.light
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.surface,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < data.length) {
                  final d = data[i]['date'];
                  if (d is DateTime) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(shortDate.format(d), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface)));
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final count = (data[i]['count'] as num).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: count,
                color: color,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _IncomeExpenseBarChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _IncomeExpenseBarChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomeColor = const Color(0xFF4CAF50);
    final expenseColor = const Color(0xFFF44336);
    final maxVal = data.isEmpty ? 1.0 : data.map<double>((e) {
      final a = (e['income'] as num).toDouble();
      final b = (e['expense'] as num).toDouble();
      return a > b ? a : b;
    }).reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.2).clamp(4.0, double.infinity);
    final monthFormat = DateFormat('MMM', l10n.isArabic ? 'ar' : 'en');
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY.toInt().toString();
              return BarTooltipItem(
                value,
                TextStyle(
                  color: theme.brightness == Brightness.light
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.surface,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < data.length) {
                  final y = data[i]['year'] as int;
                  final m = data[i]['month'] as int;
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(monthFormat.format(DateTime(y, m)), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)));
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final income = (data[i]['income'] as num).toDouble();
          final expense = (data[i]['expense'] as num).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: income, color: incomeColor, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
              BarChartRodData(toY: expense, color: expenseColor, width: 10, borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
            ],
            showingTooltipIndicators: [0, 1],
          );
        }),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _IncomeExpenseLineChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _IncomeExpenseLineChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Center(child: Text(AppLocalizations.of(context).noData));
    final theme = Theme.of(context);
    final incomeColor = const Color(0xFF4CAF50);
    final expenseColor = const Color(0xFFF44336);
    final incomeSpots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['income'] as num).toDouble())).toList();
    final expenseSpots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['expense'] as num).toDouble())).toList();
    final maxVal = data.map<double>((e) {
      final a = (e['income'] as num).toDouble();
      final b = (e['expense'] as num).toDouble();
      return a > b ? a : b;
    }).reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.2).clamp(4.0, double.infinity);
    final monthFormat = DateFormat('MMM', l10n.isArabic ? 'ar' : 'en');
    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(enabled: true),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i >= 0 && i < data.length) {
                  final y = data[i]['year'] as int;
                  final m = data[i]['month'] as int;
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(monthFormat.format(DateTime(y, m)), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)));
                }
                return const SizedBox.shrink();
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(spots: incomeSpots, isCurved: true, color: incomeColor, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: incomeColor.withValues(alpha: 0.1))),
          LineChartBarData(spots: expenseSpots, isCurved: true, color: expenseColor, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: expenseColor.withValues(alpha: 0.1))),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _UsersByRoleBarChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _UsersByRoleBarChart({required this.data, required this.l10n});

  static const List<Color> _roleColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    String roleLabel(String role) {
      switch (role) {
        case 'patient': return l10n.patients;
        case 'doctor': return l10n.ourDoctors;
        case 'admin': return l10n.admin;
        default: return role;
      }
    }
    final maxY = entries.isEmpty
        ? 4.0
        : (entries.map<int>((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.25 + 2)
            .clamp(6.0, 120.0);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideVertically: true,
            fitInsideHorizontally: true,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY.toInt().toString();
              return BarTooltipItem(
                value,
                TextStyle(
                  color: theme.brightness == Brightness.light
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.surface,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < entries.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(roleLabel(entries[i].key), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)));
                return const SizedBox.shrink();
              },
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((e) {
          final i = e.key;
          final count = e.value.value.toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: count, color: _roleColors[i % _roleColors.length], width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _UsersByRoleChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _UsersByRoleChart({required this.data, required this.l10n});

  static const List<Color> _roleColors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFF795548),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = data.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final sections = entries.asMap().entries.map((entry) {
      final index = entry.key;
      final count = entry.value.value;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '$count',
        color: _roleColors[index % _roleColors.length],
        radius: 48,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
        ),
      );
    }).toList();
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 24,
            ),
            duration: const Duration(milliseconds: 300),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final role = entry.value.key;
              final label = role == 'patient' ? l10n.patients : (role == 'doctor' ? l10n.ourDoctors : (role == 'admin' ? l10n.admin : role));
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _roleColors[index % _roleColors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              );
            }).toList(),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 28),
            const SizedBox(height: 8),
            // Scale down large numbers so they stay inside the card
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: theme.textTheme.headlineSmall),
              ),
            ),
            const SizedBox(height: 2),
            Text(title, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
