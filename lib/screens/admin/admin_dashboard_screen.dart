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
import '../../models/appointment_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'admin_dashboard_pdf.dart';
import 'invite_user_dialog.dart';
import 'migrate_staff_patients_dialog.dart';

/// Order and colors shared by appointment-status charts (period-filtered).
const _kAppointmentStatusOrder = <String>[
  'pending',
  'confirmed',
  'completed',
  'cancelled',
  'no_show',
  'absent_with_cause',
  'absent_without_cause',
];

const _kAppointmentStatusColors = <Color>[
  Color(0xFF9E9E9E),
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFF44336),
  Color(0xFFFF9800),
  Color(0xFF00BCD4),
  Color(0xFF795548),
];

const _kAmountChartColors = <Color>[
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF00BCD4),
  Color(0xFF795548),
  Color(0xFFE91E63),
  Color(0xFF607D8B),
  Color(0xFF8BC34A),
  Color(0xFFFF5722),
  Color(0xFF3F51B5),
  Color(0xFF009688),
];

/// Order of sections in the combined dynamic PDF (must match keys in [_chartKeys]).
const _kDynamicReportOrder = <String>[
  'appointments',
  'incomeExpense',
  'usersByRole',
  'doctorIncome',
  'expenseCategory',
  'expenseByDoctor',
  'appointmentStatus',
  'appointmentServices',
  'appointmentPackages',
];

class _DynamicReportOption {
  final String id;
  final String title;
  final bool available;

  const _DynamicReportOption({required this.id, required this.title, required this.available});
}

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
  final Map<String, String> _chartTypes = {
    'appointments': 'bar',
    'incomeExpense': 'bar',
    'usersByRole': 'pie',
    'doctorIncome': 'bar',
    'expenseCategory': 'bar',
    'expenseByDoctor': 'bar',
    'appointmentStatus': 'bar',
    'appointmentServices': 'bar',
    'appointmentPackages': 'bar',
  };
  final Map<String, GlobalKey> _chartKeys = {
    'appointments': GlobalKey(),
    'incomeExpense': GlobalKey(),
    'usersByRole': GlobalKey(),
    'doctorIncome': GlobalKey(),
    'expenseCategory': GlobalKey(),
    'expenseByDoctor': GlobalKey(),
    'appointmentStatus': GlobalKey(),
    'appointmentServices': GlobalKey(),
    'appointmentPackages': GlobalKey(),
  };

  final Set<String> _selectedDynamicReportIds = {};
  bool _exportingDynamicReport = false;
  /// Bar / line / pie applied to every selected chart only while generating the combined PDF.
  String _dynamicExportChartType = 'pie';

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
        if (!_chartsLoading && _chartData != null) _buildDynamicReportPanel(context, l10n),
        if (!_chartsLoading && _chartData != null) const SizedBox(height: 16),
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
    final chartHeight = isWide ? 320.0 : 280.0;
    final appointmentsByDay = _chartData!['appointmentsByDay'] as List<dynamic>? ?? [];
    final incomeExpenseByMonth = _chartData!['incomeExpenseByMonth'] as List<dynamic>? ?? [];
    final usersByRole = Map<String, int>.from(_chartData!['usersByRole'] as Map<dynamic, dynamic>? ?? {});
    final appointmentsByStatus = Map<String, int>.from(_chartData!['appointmentsByStatus'] as Map<dynamic, dynamic>? ?? {});
    final incomeByDoctorRaw = _chartData!['incomeByDoctor'] as List<dynamic>? ?? [];
    final expensesByCategoryRaw = _chartData!['expensesByCategory'] as List<dynamic>? ?? [];
    final expensesByDoctorRaw = _chartData!['expensesByDoctor'] as List<dynamic>? ?? [];
    final appointmentsByServiceRaw = _chartData!['appointmentsByService'] as List<dynamic>? ?? [];
    final appointmentsByPackageRaw = _chartData!['appointmentsByPackage'] as List<dynamic>? ?? [];
    final rangeLabel = _chartData!['rangeStart'] != null && _chartData!['rangeEnd'] != null
        ? '${DateFormat.yMd().format((_chartData!['rangeStart'] as DateTime))} - ${DateFormat.yMd().format((_chartData!['rangeEnd'] as DateTime))}'
        : _chartRange;

    final incomeByDoctor = _prepareDoctorIncomeSeries(incomeByDoctorRaw, l10n);
    final expensesByCategory = _prepareExpenseCategorySeries(expensesByCategoryRaw, l10n);
    final expensesByDoctor = _prepareExpenseByDoctorSeries(expensesByDoctorRaw, l10n);
    final appointmentsByService = _prepareCountSeries(appointmentsByServiceRaw, l10n, emptyNameLabel: l10n.appointmentNoServices);
    final appointmentsByPackage = _prepareCountSeries(appointmentsByPackageRaw, l10n, emptyNameLabel: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appointmentsByDay.isNotEmpty) ...[
          _ChartCard(
            title: l10n.appointmentsLast7Days,
            chartKey: _chartKeys['appointments']!,
            chartType: _chartTypes['appointments']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['appointments'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'appointments', l10n.appointmentsLast7Days, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['appointments'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['appointments'] == 'line'
                      ? _AppointmentsLineChart(data: appointmentsByDay, l10n: l10n)
                      : _chartTypes['appointments'] == 'pie'
                          ? _AppointmentsPieChart(data: appointmentsByDay, l10n: l10n)
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
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['incomeExpense'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'incomeExpense', l10n.incomeVsExpense6Months, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['incomeExpense'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['incomeExpense'] == 'line'
                      ? _IncomeExpenseLineChart(data: incomeExpenseByMonth, l10n: l10n)
                      : _chartTypes['incomeExpense'] == 'pie'
                          ? _IncomeExpensePieChart(data: incomeExpenseByMonth, l10n: l10n)
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
            chartTypes: const ['pie', 'bar', 'line'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['usersByRole'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'usersByRole', l10n.usersByRole, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['usersByRole'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['usersByRole'] == 'bar'
                      ? _UsersByRoleBarChart(data: usersByRole, l10n: l10n)
                      : _chartTypes['usersByRole'] == 'line'
                          ? _UsersByRoleLineChart(data: usersByRole, l10n: l10n)
                          : _UsersByRoleChart(data: usersByRole, l10n: l10n),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (incomeByDoctor.isNotEmpty) ...[
          _ChartCard(
            title: l10n.incomeByDoctor,
            chartKey: _chartKeys['doctorIncome']!,
            chartType: _chartTypes['doctorIncome']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['doctorIncome'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'doctorIncome', l10n.incomeByDoctor, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['doctorIncome'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['doctorIncome'] == 'line'
                      ? _LabeledAmountLineChart(data: incomeByDoctor, l10n: l10n, amountKey: 'income')
                      : _chartTypes['doctorIncome'] == 'pie'
                          ? _LabeledAmountPieChart(data: incomeByDoctor, l10n: l10n, amountKey: 'income')
                          : _LabeledAmountBarChart(data: incomeByDoctor, l10n: l10n, amountKey: 'income'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (expensesByCategory.isNotEmpty) ...[
          _ChartCard(
            title: l10n.expensesByCategory,
            chartKey: _chartKeys['expenseCategory']!,
            chartType: _chartTypes['expenseCategory']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['expenseCategory'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'expenseCategory', l10n.expensesByCategory, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['expenseCategory'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['expenseCategory'] == 'line'
                      ? _LabeledAmountLineChart(data: expensesByCategory, l10n: l10n, amountKey: 'amount')
                      : _chartTypes['expenseCategory'] == 'pie'
                          ? _LabeledAmountPieChart(data: expensesByCategory, l10n: l10n, amountKey: 'amount')
                          : _LabeledAmountBarChart(data: expensesByCategory, l10n: l10n, amountKey: 'amount'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (expensesByDoctor.isNotEmpty) ...[
          _ChartCard(
            title: l10n.expenseByDoctor,
            chartKey: _chartKeys['expenseByDoctor']!,
            chartType: _chartTypes['expenseByDoctor']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['expenseByDoctor'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'expenseByDoctor', l10n.expenseByDoctor, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['expenseByDoctor'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['expenseByDoctor'] == 'line'
                      ? _LabeledAmountLineChart(data: expensesByDoctor, l10n: l10n, amountKey: 'expense')
                      : _chartTypes['expenseByDoctor'] == 'pie'
                          ? _LabeledAmountPieChart(data: expensesByDoctor, l10n: l10n, amountKey: 'expense')
                          : _LabeledAmountBarChart(data: expensesByDoctor, l10n: l10n, amountKey: 'expense'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (appointmentsByStatus.values.any((c) => c > 0)) ...[
          _ChartCard(
            title: l10n.appointmentsByStatus,
            chartKey: _chartKeys['appointmentStatus']!,
            chartType: _chartTypes['appointmentStatus']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['appointmentStatus'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'appointmentStatus', l10n.appointmentsByStatus, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['appointmentStatus'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['appointmentStatus'] == 'line'
                      ? _AppointmentStatusLineChart(data: appointmentsByStatus, l10n: l10n)
                      : _chartTypes['appointmentStatus'] == 'pie'
                          ? _AppointmentStatusPieChart(data: appointmentsByStatus, l10n: l10n)
                          : _AppointmentStatusBarChart(data: appointmentsByStatus, l10n: l10n),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (appointmentsByService.isNotEmpty) ...[
          _ChartCard(
            title: l10n.appointmentsByService,
            chartKey: _chartKeys['appointmentServices']!,
            chartType: _chartTypes['appointmentServices']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['appointmentServices'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'appointmentServices', l10n.appointmentsByService, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['appointmentServices'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['appointmentServices'] == 'line'
                      ? _LabeledAmountLineChart(data: appointmentsByService, l10n: l10n, amountKey: 'count')
                      : _chartTypes['appointmentServices'] == 'pie'
                          ? _LabeledAmountPieChart(data: appointmentsByService, l10n: l10n, amountKey: 'count')
                          : _LabeledAmountBarChart(data: appointmentsByService, l10n: l10n, amountKey: 'count'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (appointmentsByPackage.isNotEmpty) ...[
          _ChartCard(
            title: l10n.appointmentsByPackage,
            chartKey: _chartKeys['appointmentPackages']!,
            chartType: _chartTypes['appointmentPackages']!,
            chartTypes: const ['bar', 'line', 'pie'],
            onChartTypeChanged: (t) => setState(() => _chartTypes['appointmentPackages'] = t),
            onExportPdf: () => _exportChartPdf(l10n, 'appointmentPackages', l10n.appointmentsByPackage, rangeLabel),
            child: RepaintBoundary(
              key: _chartKeys['appointmentPackages'],
              child: ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _chartTypes['appointmentPackages'] == 'line'
                      ? _LabeledAmountLineChart(data: appointmentsByPackage, l10n: l10n, amountKey: 'count')
                      : _chartTypes['appointmentPackages'] == 'pie'
                          ? _LabeledAmountPieChart(data: appointmentsByPackage, l10n: l10n, amountKey: 'count')
                          : _LabeledAmountBarChart(data: appointmentsByPackage, l10n: l10n, amountKey: 'count'),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Caps long doctor lists for readable bar/line/pie; merges remainder into [chartOtherCategory].
  List<Map<String, dynamic>> _prepareDoctorIncomeSeries(List<dynamic> raw, AppLocalizations l10n) {
    final rows = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (rows.isEmpty) return [];
    const maxSlices = 14;
    if (rows.length <= maxSlices) {
      return rows.map((r) {
        final id = r['doctorId'] as String? ?? '';
        final name = (r['name'] as String?) ?? '';
        final display = id.isEmpty ? l10n.incomeNoDoctor : (name.isEmpty ? id : name);
        return {...r, 'name': display};
      }).toList();
    }
    final head = rows.take(maxSlices - 1).map((r) {
      final id = r['doctorId'] as String? ?? '';
      final name = (r['name'] as String?) ?? '';
      final display = id.isEmpty ? l10n.incomeNoDoctor : (name.isEmpty ? id : name);
      return {...r, 'name': display};
    }).toList();
    double other = 0;
    for (var i = maxSlices - 1; i < rows.length; i++) {
      other += (rows[i]['income'] as num).toDouble();
    }
    head.add({'doctorId': '_other', 'name': l10n.chartOtherCategory, 'income': other});
    return head;
  }

  /// Expense rows by category; caps long lists and merges remainder into [chartOtherCategory].
  List<Map<String, dynamic>> _prepareExpenseCategorySeries(List<dynamic> raw, AppLocalizations l10n) {
    final rows = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final cat = (m['category'] as String?) ?? '';
      final name = cat.isEmpty ? l10n.uncategorizedExpense : cat;
      return {...m, 'name': name};
    }).toList();
    if (rows.isEmpty) return [];
    const maxSlices = 14;
    if (rows.length <= maxSlices) return rows;
    final head = rows.take(maxSlices - 1).toList();
    double other = 0;
    for (var i = maxSlices - 1; i < rows.length; i++) {
      other += (rows[i]['amount'] as num).toDouble();
    }
    head.add({'category': '_other', 'name': l10n.chartOtherCategory, 'amount': other});
    return head;
  }

  List<Map<String, dynamic>> _prepareExpenseByDoctorSeries(List<dynamic> raw, AppLocalizations l10n) {
    final rows = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['doctorId'] as String? ?? '';
      final name = (m['name'] as String?) ?? '';
      final display = id.isEmpty ? l10n.incomeNoDoctor : (name.isEmpty ? id : name);
      return {...m, 'name': display};
    }).toList();
    if (rows.isEmpty) return [];
    const maxSlices = 14;
    if (rows.length <= maxSlices) return rows;
    final head = rows.take(maxSlices - 1).map((r) => Map<String, dynamic>.from(r)).toList();
    double other = 0;
    for (var i = maxSlices - 1; i < rows.length; i++) {
      other += (rows[i]['expense'] as num).toDouble();
    }
    head.add({'doctorId': '_other', 'name': l10n.chartOtherCategory, 'expense': other});
    return head;
  }

  /// Count-based series (e.g. appointments per service/package); merges long tails into [chartOtherCategory].
  List<Map<String, dynamic>> _prepareCountSeries(List<dynamic> raw, AppLocalizations l10n, {required String emptyNameLabel}) {
    final rows = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final name = (m['name'] as String?) ?? '';
      final display = name.isNotEmpty ? name : emptyNameLabel;
      return {...m, 'name': display};
    }).toList();
    if (rows.isEmpty) return [];
    const maxSlices = 14;
    if (rows.length <= maxSlices) return rows;
    final head = rows.take(maxSlices - 1).map((r) => Map<String, dynamic>.from(r)).toList();
    var other = 0;
    for (var i = maxSlices - 1; i < rows.length; i++) {
      other += (rows[i]['count'] as num).toInt();
    }
    head.add({'name': l10n.chartOtherCategory, 'count': other});
    return head;
  }

  String _chartRangeLabel() {
    if (_chartData == null) return _chartRange;
    final rs = _chartData!['rangeStart'];
    final re = _chartData!['rangeEnd'];
    if (rs is DateTime && re is DateTime) {
      return '${DateFormat.yMd().format(rs)} - ${DateFormat.yMd().format(re)}';
    }
    return _chartRange;
  }

  /// Same availability rules as [_buildChartsSection] so PDF capture matches visible charts.
  List<_DynamicReportOption> _buildDynamicReportOptions(AppLocalizations l10n) {
    final c = _chartData;
    if (c == null) return [];
    final appointmentsByDay = c['appointmentsByDay'] as List<dynamic>? ?? [];
    final incomeExpenseByMonth = c['incomeExpenseByMonth'] as List<dynamic>? ?? [];
    final usersByRole = Map<String, int>.from(c['usersByRole'] as Map<dynamic, dynamic>? ?? {});
    final appointmentsByStatus = Map<String, int>.from(c['appointmentsByStatus'] as Map<dynamic, dynamic>? ?? {});
    final incomeByDoctorRaw = c['incomeByDoctor'] as List<dynamic>? ?? [];
    final expensesByCategoryRaw = c['expensesByCategory'] as List<dynamic>? ?? [];
    final expensesByDoctorRaw = c['expensesByDoctor'] as List<dynamic>? ?? [];
    final appointmentsByServiceRaw = c['appointmentsByService'] as List<dynamic>? ?? [];
    final appointmentsByPackageRaw = c['appointmentsByPackage'] as List<dynamic>? ?? [];

    final incomeByDoctor = _prepareDoctorIncomeSeries(incomeByDoctorRaw, l10n);
    final expensesByCategory = _prepareExpenseCategorySeries(expensesByCategoryRaw, l10n);
    final expensesByDoctor = _prepareExpenseByDoctorSeries(expensesByDoctorRaw, l10n);
    final appointmentsByService = _prepareCountSeries(appointmentsByServiceRaw, l10n, emptyNameLabel: l10n.appointmentNoServices);
    final appointmentsByPackage = _prepareCountSeries(appointmentsByPackageRaw, l10n, emptyNameLabel: '');

    return [
      _DynamicReportOption(id: 'appointments', title: l10n.appointmentsLast7Days, available: appointmentsByDay.isNotEmpty),
      _DynamicReportOption(id: 'incomeExpense', title: l10n.incomeVsExpense6Months, available: incomeExpenseByMonth.isNotEmpty),
      _DynamicReportOption(id: 'usersByRole', title: l10n.usersByRole, available: usersByRole.isNotEmpty),
      _DynamicReportOption(id: 'doctorIncome', title: l10n.incomeByDoctor, available: incomeByDoctor.isNotEmpty),
      _DynamicReportOption(id: 'expenseCategory', title: l10n.expensesByCategory, available: expensesByCategory.isNotEmpty),
      _DynamicReportOption(id: 'expenseByDoctor', title: l10n.expenseByDoctor, available: expensesByDoctor.isNotEmpty),
      _DynamicReportOption(id: 'appointmentStatus', title: l10n.appointmentsByStatus, available: appointmentsByStatus.values.any((x) => x > 0)),
      _DynamicReportOption(id: 'appointmentServices', title: l10n.appointmentsByService, available: appointmentsByService.isNotEmpty),
      _DynamicReportOption(id: 'appointmentPackages', title: l10n.appointmentsByPackage, available: appointmentsByPackage.isNotEmpty),
    ];
  }

  Widget _buildDynamicReportPanel(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final options = _buildDynamicReportOptions(l10n).where((o) => o.available).toList();
    if (options.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.dynamicReportNoCharts, style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_mosaic, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.dynamicReport, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(l10n.dynamicReportHint, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.dynamicReportExportChartType, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.barChart),
                  selected: _dynamicExportChartType == 'bar',
                  onSelected: _exportingDynamicReport
                      ? null
                      : (v) {
                          if (v) setState(() => _dynamicExportChartType = 'bar');
                        },
                ),
                ChoiceChip(
                  label: Text(l10n.lineChart),
                  selected: _dynamicExportChartType == 'line',
                  onSelected: _exportingDynamicReport
                      ? null
                      : (v) {
                          if (v) setState(() => _dynamicExportChartType = 'line');
                        },
                ),
                ChoiceChip(
                  label: Text(l10n.pieChart),
                  selected: _dynamicExportChartType == 'pie',
                  onSelected: _exportingDynamicReport
                      ? null
                      : (v) {
                          if (v) setState(() => _dynamicExportChartType = 'pie');
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _exportingDynamicReport
                      ? null
                      : () => setState(() {
                            _selectedDynamicReportIds
                              ..clear()
                              ..addAll(options.map((e) => e.id));
                          }),
                  child: Text(l10n.dynamicReportSelectAll),
                ),
                TextButton(
                  onPressed: _exportingDynamicReport ? null : () => setState(_selectedDynamicReportIds.clear),
                  child: Text(l10n.dynamicReportClear),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...options.map(
              (o) => CheckboxListTile(
                value: _selectedDynamicReportIds.contains(o.id),
                onChanged: _exportingDynamicReport
                    ? null
                    : (v) {
                        setState(() {
                          if (v == true) {
                            _selectedDynamicReportIds.add(o.id);
                          } else {
                            _selectedDynamicReportIds.remove(o.id);
                          }
                        });
                      },
                title: Text(o.title, style: theme.textTheme.bodyMedium),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _exportingDynamicReport || _selectedDynamicReportIds.isEmpty ? null : () => _exportCombinedDynamicReport(l10n),
              icon: _exportingDynamicReport
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_exportingDynamicReport ? l10n.generatingPdf : l10n.dynamicReportGenerate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _waitForChartRepaint() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _exportCombinedDynamicReport(AppLocalizations l10n) async {
    if (_selectedDynamicReportIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.dynamicReportSelectAtLeastOne)));
      return;
    }
    final optionsById = {for (final o in _buildDynamicReportOptions(l10n)) o.id: o};
    final rangeLabel = _chartRangeLabel();
    final ordered = _kDynamicReportOrder.where(_selectedDynamicReportIds.contains).toList();

    final backupChartTypes = Map<String, String>.from(_chartTypes);
    setState(() {
      _exportingDynamicReport = true;
      for (final id in ordered) {
        if (_chartKeys.containsKey(id)) {
          _chartTypes[id] = _dynamicExportChartType;
        }
      }
    });
    try {
      await _waitForChartRepaint();
      if (!mounted) return;

      final sections = <AdminDashboardReportSection>[];
      for (final id in ordered) {
        final opt = optionsById[id];
        if (opt == null || !opt.available) continue;
        final key = _chartKeys[id];
        if (key?.currentContext == null) continue;
        final boundary = key!.currentContext!.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) continue;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;
        sections.add(AdminDashboardReportSection(title: opt.title, imageBytes: byteData.buffer.asUint8List()));
      }
      if (!mounted) return;
      if (sections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.dynamicReportNothingCaptured)));
        return;
      }
      await AdminDashboardPdf.exportCombinedReport(
        context: context,
        l10n: l10n,
        reportTitle: l10n.dynamicStatisticsReport,
        rangeLabel: rangeLabel,
        sections: sections,
      );
    } catch (e, st) {
      debugPrint('AdminDashboard _exportCombinedDynamicReport: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.reportError)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _chartTypes
            ..clear()
            ..addAll(backupChartTypes);
          _exportingDynamicReport = false;
        });
      }
    }
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

    final chips = chartTypes.length > 1
        ? Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: chartTypes.map((t) {
              final selected = chartType == t;
              return ChoiceChip(
                label: Text(chartTypeLabel(t), style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => onChartTypeChanged(t),
              );
            }).toList(),
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (narrow) ...[
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chips != null) Expanded(child: chips),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: l10n.exportPdf,
                        onPressed: onExportPdf,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                      if (chips != null) ...[chips, const SizedBox(width: 8)],
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
            );
          },
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

class _LegendItem {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
}

/// Pie chart with legend: column layout on narrow widths, row on wide screens.
class _ResponsivePieWithLegend extends StatelessWidget {
  final List<PieChartSectionData> sections;
  final List<_LegendItem> legendItems;

  const _ResponsivePieWithLegend({required this.sections, required this.legendItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          final pie = PieChart(
            PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 22),
            duration: const Duration(milliseconds: 300),
          );
          final legend = Wrap(
            spacing: 8,
            runSpacing: 6,
            children: legendItems
                .map(
                  (item) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: narrow ? constraints.maxWidth - 16 : constraints.maxWidth * 0.35),
                        child: Text(item.label, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )
                .toList(),
          );
          if (narrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 200, child: pie),
                const SizedBox(height: 12),
                legend,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 2, child: SizedBox(height: 220, child: pie)),
              const SizedBox(width: 12),
              Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentsPieChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _AppointmentsPieChart({required this.data, required this.l10n});

  static const List<Color> _colors = [
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFF795548),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
    Color(0xFF3F51B5),
    Color(0xFF009688),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final total = data.fold<double>(0, (s, e) => s + (e['count'] as num).toDouble());
    if (total <= 0) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final shortDate = DateFormat('MMM d', l10n.isArabic ? 'ar' : 'en');
    final entries = data.asMap().entries.toList();
    final sections = entries.map((me) {
      final i = me.key;
      final row = me.value;
      final count = (row['count'] as num).toDouble();
      final d = row['date'];
      final label = d is DateTime ? shortDate.format(d) : '${row['label'] ?? ''}';
      return MapEntry(
        label,
        PieChartSectionData(
          value: count,
          title: count >= 1 ? count.toStringAsFixed(count >= 10 ? 0 : 1) : '',
          color: _colors[i % _colors.length],
          radius: 52,
          titleStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      );
    }).toList();
    return _ResponsivePieWithLegend(
      sections: sections.map((e) => e.value).toList(),
      legendItems: sections.asMap().entries.map((e) {
        final i = e.key;
        final label = e.value.key;
        return _LegendItem(color: _colors[i % _colors.length], label: label);
      }).toList(),
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

class _IncomeExpensePieChart extends StatelessWidget {
  final List<dynamic> data;
  final AppLocalizations l10n;

  const _IncomeExpensePieChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final totalIncome = data.fold<double>(0, (s, e) => s + (e['income'] as num).toDouble());
    final totalExpense = data.fold<double>(0, (s, e) => s + (e['expense'] as num).toDouble());
    if (totalIncome <= 0 && totalExpense <= 0) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final incomeColor = const Color(0xFF4CAF50);
    final expenseColor = const Color(0xFFF44336);
    final sections = <PieChartSectionData>[];
    final legend = <_LegendItem>[];
    if (totalIncome > 0) {
      sections.add(
        PieChartSectionData(
          value: totalIncome,
          title: totalIncome >= 1000 ? '${(totalIncome / 1000).toStringAsFixed(1)}k' : totalIncome.toStringAsFixed(0),
          color: incomeColor,
          radius: 56,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      );
      legend.add(_LegendItem(color: incomeColor, label: l10n.income));
    }
    if (totalExpense > 0) {
      sections.add(
        PieChartSectionData(
          value: totalExpense,
          title: totalExpense >= 1000 ? '${(totalExpense / 1000).toStringAsFixed(1)}k' : totalExpense.toStringAsFixed(0),
          color: expenseColor,
          radius: 56,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      );
      legend.add(_LegendItem(color: expenseColor, label: l10n.expenses));
    }
    return _ResponsivePieWithLegend(sections: sections, legendItems: legend);
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

class _UsersByRoleLineChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _UsersByRoleLineChart({required this.data, required this.l10n});

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
    if (data.isEmpty) return Center(child: Text(AppLocalizations.of(context).noData));
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
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList();
    final maxY = (entries.map<int>((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 2).clamp(4.0, 120.0);
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
                if (i >= 0 && i < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(roleLabel(entries[i].key), style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface)),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 36,
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
            color: _roleColors[0],
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: _roleColors[0].withValues(alpha: 0.12)),
          ),
        ],
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
    final legendItems = entries.asMap().entries.map((entry) {
      final index = entry.key;
      final role = entry.value.key;
      final label = role == 'patient' ? l10n.patients : (role == 'doctor' ? l10n.ourDoctors : (role == 'admin' ? l10n.admin : role));
      return _LegendItem(color: _roleColors[index % _roleColors.length], label: label);
    }).toList();
    return _ResponsivePieWithLegend(sections: sections, legendItems: legendItems);
  }
}

String _appointmentStatusValueLabel(String value, AppLocalizations l10n) {
  final s = AppointmentStatusExt.fromString(value);
  switch (s) {
    case AppointmentStatus.pending: return l10n.pending;
    case AppointmentStatus.confirmed: return l10n.confirmed;
    case AppointmentStatus.completed: return l10n.attended;
    case AppointmentStatus.cancelled: return l10n.cancelled;
    case AppointmentStatus.noShow: return l10n.noShow;
    case AppointmentStatus.absentWithCause: return l10n.apologized;
    case AppointmentStatus.absentWithoutCause: return l10n.absentWithoutCause;
  }
}

class _AppointmentStatusBarChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _AppointmentStatusBarChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _kAppointmentStatusOrder.map((k) => MapEntry(k, data[k] ?? 0)).where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final maxY = (entries.map<int>((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() * 1.25 + 2).clamp(6.0, 120.0);
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
              return BarTooltipItem(
                rod.toY.toInt().toString(),
                TextStyle(
                  color: theme.brightness == Brightness.light ? theme.colorScheme.onSurface : theme.colorScheme.surface,
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
                if (i >= 0 && i < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _appointmentStatusValueLabel(entries[i].key, l10n),
                      style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 44,
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
            barRods: [BarChartRodData(toY: count, color: _kAppointmentStatusColors[i % _kAppointmentStatusColors.length], width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
            showingTooltipIndicators: [0],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _AppointmentStatusLineChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _AppointmentStatusLineChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _kAppointmentStatusOrder.map((k) => MapEntry(k, data[k] ?? 0)).where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble())).toList();
    final maxY = (entries.map<int>((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble() + 2).clamp(4.0, 120.0);
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
                if (i >= 0 && i < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _appointmentStatusValueLabel(entries[i].key, l10n),
                      style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface),
                      maxLines: 2,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 44,
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
            color: _kAppointmentStatusColors[0],
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: _kAppointmentStatusColors[0].withValues(alpha: 0.1)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _AppointmentStatusPieChart extends StatelessWidget {
  final Map<String, int> data;
  final AppLocalizations l10n;

  const _AppointmentStatusPieChart({required this.data, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _kAppointmentStatusOrder.map((k) => MapEntry(k, data[k] ?? 0)).where((e) => e.value > 0).toList();
    if (entries.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final sections = entries.asMap().entries.map((e) {
      final i = e.key;
      final count = e.value.value;
      return PieChartSectionData(
        value: count.toDouble(),
        title: '$count',
        color: _kAppointmentStatusColors[i % _kAppointmentStatusColors.length],
        radius: 50,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
        ),
      );
    }).toList();
    final legendItems = entries.asMap().entries.map((e) {
      final i = e.key;
      return _LegendItem(color: _kAppointmentStatusColors[i % _kAppointmentStatusColors.length], label: _appointmentStatusValueLabel(e.value.key, l10n));
    }).toList();
    return _ResponsivePieWithLegend(sections: sections, legendItems: legendItems);
  }
}

class _LabeledAmountBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final AppLocalizations l10n;
  /// Firestore field: `income` (doctor income), `expense` (expense by doctor), `amount` (expense by category).
  final String amountKey;

  const _LabeledAmountBarChart({required this.data, required this.l10n, required this.amountKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final maxY = (data.map<double>((e) => (e[amountKey] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.2 + 2).clamp(4.0, double.infinity);
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
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                TextStyle(
                  color: theme.brightness == Brightness.light ? theme.colorScheme.onSurface : theme.colorScheme.surface,
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
                  final name = (data[i]['name'] as String?) ?? '';
                  final short = name.length > 10 ? '${name.substring(0, 10)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(short, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface)),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 36,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final y = (data[i][amountKey] as num).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: y,
                color: _kAmountChartColors[i % _kAmountChartColors.length],
                width: 14,
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

class _LabeledAmountLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final AppLocalizations l10n;
  final String amountKey;

  const _LabeledAmountLineChart({required this.data, required this.l10n, required this.amountKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value[amountKey] as num).toDouble())).toList();
    final maxY = (data.map<double>((e) => (e[amountKey] as num).toDouble()).reduce((a, b) => a > b ? a : b) * 1.15 + 2).clamp(4.0, double.infinity);
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
                  final name = (data[i]['name'] as String?) ?? '';
                  final short = name.length > 8 ? '${name.substring(0, 8)}…' : name;
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(short, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface)));
                }
                return const SizedBox.shrink();
              },
              reservedSize: 34,
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _kAmountChartColors[0],
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: _kAmountChartColors[0].withValues(alpha: 0.12)),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

class _LabeledAmountPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final AppLocalizations l10n;
  final String amountKey;

  const _LabeledAmountPieChart({required this.data, required this.l10n, required this.amountKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final total = data.fold<double>(0, (s, e) => s + (e[amountKey] as num).toDouble());
    if (total <= 0) return Center(child: Text(l10n.noData, style: theme.textTheme.bodyMedium));
    final sections = data.asMap().entries.map((e) {
      final i = e.key;
      final row = e.value;
      final amount = (row[amountKey] as num).toDouble();
      return PieChartSectionData(
        value: amount,
        title: amount >= 1000 ? '${(amount / 1000).toStringAsFixed(1)}k' : amount.toStringAsFixed(0),
        color: _kAmountChartColors[i % _kAmountChartColors.length],
        radius: 52,
        titleStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.onSurface,
        ),
      );
    }).toList();
    final legendItems = data.asMap().entries.map((e) {
      final i = e.key;
      final name = (e.value['name'] as String?) ?? '';
      return _LegendItem(color: _kAmountChartColors[i % _kAmountChartColors.length], label: name);
    }).toList();
    return _ResponsivePieWithLegend(sections: sections, legendItems: legendItems);
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
