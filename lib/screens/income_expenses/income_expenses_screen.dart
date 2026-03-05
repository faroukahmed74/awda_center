import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/income_expense_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;

class IncomeExpensesScreen extends StatefulWidget {
  const IncomeExpensesScreen({super.key});

  @override
  State<IncomeExpensesScreen> createState() => _IncomeExpensesScreenState();
}

class _IncomeExpensesScreenState extends State<IncomeExpensesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<IncomeRecordModel> _income = [];
  List<ExpenseRecordModel> _expense = [];
  bool _loading = true;
  DateTime? _filterDay;
  int? _filterYear;
  int? _filterMonth;
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expenseSub;

  List<IncomeRecordModel> get _filteredIncome {
    var out = _income;
    if (_filterDay != null) {
      final d = _filterDay!;
      out = out.where((r) => r.incomeDate.year == d.year && r.incomeDate.month == d.month && r.incomeDate.day == d.day).toList();
    } else if (_filterYear != null && _filterMonth != null) {
      out = out.where((r) => r.incomeDate.year == _filterYear && r.incomeDate.month == _filterMonth).toList();
    } else if (_filterYear != null) {
      out = out.where((r) => r.incomeDate.year == _filterYear).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((r) {
        final source = (r.source).toLowerCase();
        final notes = (r.notes ?? '').toLowerCase();
        final amountStr = r.amount.toString().toLowerCase();
        return source.contains(q) || notes.contains(q) || amountStr.contains(q);
      }).toList();
    }
    return out;
  }

  List<ExpenseRecordModel> get _filteredExpense {
    var out = _expense;
    if (_filterDay != null) {
      final d = _filterDay!;
      out = out.where((r) => r.expenseDate.year == d.year && r.expenseDate.month == d.month && r.expenseDate.day == d.day).toList();
    } else if (_filterYear != null && _filterMonth != null) {
      out = out.where((r) => r.expenseDate.year == _filterYear && r.expenseDate.month == _filterMonth).toList();
    } else if (_filterYear != null) {
      out = out.where((r) => r.expenseDate.year == _filterYear).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((r) {
        final category = (r.category).toLowerCase();
        final desc = (r.description ?? '').toLowerCase();
        final amountStr = r.amount.toString().toLowerCase();
        final recipient = (r.recipientName ?? '').toLowerCase();
        return category.contains(q) || desc.contains(q) || amountStr.contains(q) || recipient.contains(q);
      }).toList();
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }

  void _listen() {
    setState(() => _loading = true);
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    _incomeSub = _firestore.incomeRecordsStream().listen((snapshot) {
      final list = snapshot.docs
          .map((d) => IncomeRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (mounted) setState(() {
        _income = list;
        _loading = false;
      });
    }, onError: (e) {
      if (mounted) setState(() => _loading = false);
    });
    _expenseSub = _firestore.expenseRecordsStream().listen((snapshot) {
      final list = snapshot.docs
          .map((d) => ExpenseRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (mounted) setState(() {
        _expense = list;
        _loading = false;
      });
    }, onError: (e) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = context.read<AuthProvider>().currentUser?.id;
    final cache = context.watch<DataCacheProvider>();
    final isRtl = l10n.isArabic;

    final filteredIncome = _filteredIncome;
    final filteredExpense = _filteredExpense;
    final totalIncome = filteredIncome.fold<double>(0, (s, r) => s + r.amount);
    final totalExpense = filteredExpense.fold<double>(0, (s, r) => s + r.amount);
    final net = totalIncome - totalExpense;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.incomeAndExpenses),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddIncome(context, uid, l10n),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _showAddExpense(context, uid, l10n),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  _incomeSub?.cancel();
                  _expenseSub?.cancel();
                  _listen();
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: SingleChildScrollView(
                  padding: ResponsivePadding.all(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            FilterChip(
                              label: Text(l10n.filterDay),
                              selected: _filterDay != null,
                              onSelected: (_) async {
                                if (_filterDay != null) {
                                  setState(() => _filterDay = null);
                                  return;
                                }
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() {
                                  _filterDay = d;
                                  _filterMonth = null;
                                  _filterYear = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(l10n.filterMonth),
                              selected: _filterMonth != null && _filterYear != null,
                              onSelected: (_) async {
                                if (_filterMonth != null && _filterYear != null) {
                                  setState(() { _filterMonth = null; _filterYear = null; _filterDay = null; });
                                  return;
                                }
                                final now = DateTime.now();
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(now.year + 1),
                                );
                                if (d != null) setState(() {
                                  _filterMonth = d.month;
                                  _filterYear = d.year;
                                  _filterDay = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(l10n.filterYear),
                              selected: _filterYear != null && _filterMonth == null,
                              onSelected: (_) async {
                                if (_filterYear != null && _filterMonth == null) {
                                  setState(() { _filterYear = null; _filterDay = null; });
                                  return;
                                }
                                final y = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) {
                                    final years = List.generate(6, (i) => DateTime.now().year - 2 + i);
                                    return AlertDialog(
                                      title: Text(l10n.filterYear),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: years.map((y) => ListTile(title: Text('$y'), onTap: () => Navigator.pop(ctx, y))).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (y != null) setState(() {
                                  _filterYear = y;
                                  _filterMonth = null;
                                  _filterDay = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: l10n.search,
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
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.totalIncome, style: Theme.of(context).textTheme.titleSmall),
                                    Text(NumberFormat.currency(symbol: '').format(totalIncome), style: Theme.of(context).textTheme.headlineSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: net >= 0
                                  ? const Color(0xFFC8E6C9)
                                  : const Color(0xFFFFCDD2),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.netProfit, style: Theme.of(context).textTheme.titleSmall),
                                    Text(
                                      NumberFormat.currency(symbol: '').format(net),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: net >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.totalExpenses, style: Theme.of(context).textTheme.titleSmall),
                                    Text(NumberFormat.currency(symbol: '').format(totalExpense), style: Theme.of(context).textTheme.headlineSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.income, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (filteredIncome.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                      else
                        ...filteredIncome.take(50).map((r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(r.source, style: Theme.of(context).textTheme.titleMedium),
                                        ),
                                        Text(
                                          NumberFormat.currency(symbol: r.currency).format(r.amount),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (v) async {
                                            if (v == 'edit') await _showEditIncome(context, r, uid, l10n);
                                            else if (v == 'delete') await _showDeleteIncome(context, r, l10n);
                                            if (mounted) { _incomeSub?.cancel(); _expenseSub?.cancel(); _listen(); }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${l10n.date}: ${DateFormat.yMd().format(r.incomeDate)}', style: Theme.of(context).textTheme.bodySmall),
                                    if (r.notes != null && r.notes!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${l10n.notes}: ${r.notes}', style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      ),
                                    if (r.patientId != null && r.patientId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.patient}: ${cache.userName(r.patientId) ?? r.patientId}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                    if (r.doctorId != null && r.doctorId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.doctor}: ${cache.doctorDisplayName(r.doctorId) ?? cache.userName(r.doctorId) ?? r.doctorId}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                  ],
                                ),
                              ),
                            )),
                      const SizedBox(height: 16),
                      Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (filteredExpense.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                      else
                        ...filteredExpense.take(50).map((r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(_expenseTitle(r), style: Theme.of(context).textTheme.titleMedium),
                                        ),
                                        Text(
                                          NumberFormat.currency(symbol: '').format(r.amount),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (v) async {
                                            if (v == 'edit') await _showEditExpense(context, r, uid, l10n);
                                            else if (v == 'delete') await _showDeleteExpense(context, r, l10n);
                                            if (mounted) { _incomeSub?.cancel(); _expenseSub?.cancel(); _listen(); }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${l10n.date}: ${DateFormat.yMd().format(r.expenseDate)}', style: Theme.of(context).textTheme.bodySmall),
                                    Text('${l10n.category}: ${r.category}', style: Theme.of(context).textTheme.bodySmall),
                                    if (r.description != null && r.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${l10n.description}: ${r.description}', style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      ),
                                    if (r.recipientName != null && r.recipientName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.employeeOptional}: ${r.recipientName}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// For salary expenses with recipient, show "Salary – Name"; otherwise category.
  static String _expenseTitle(ExpenseRecordModel r) {
    if (r.category == 'Salary' && r.recipientName != null && r.recipientName!.isNotEmpty) {
      return 'Salary – ${r.recipientName}';
    }
    return r.category;
  }

  Future<void> _showAddIncome(BuildContext context, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController();
    final sourceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.addIncome),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sourceController,
                  decoration: InputDecoration(labelText: l10n.source),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(DateFormat.yMd().format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || sourceController.text.trim().isEmpty) return;
                await _firestore.addIncomeRecord(IncomeRecordModel(
                  id: '',
                  amount: amount,
                  source: sourceController.text.trim(),
                  recordedByUserId: uid,
                  incomeDate: selectedDate,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditIncome(BuildContext context, IncomeRecordModel r, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController(text: r.amount.toString());
    final sourceController = TextEditingController(text: r.source);
    final notesController = TextEditingController(text: r.notes ?? '');
    final currencyController = TextEditingController(text: r.currency);
    DateTime selectedDate = r.incomeDate;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sourceController,
                  decoration: InputDecoration(labelText: l10n.source),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(labelText: 'Currency'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.notes),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(DateFormat.yMd().format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || sourceController.text.trim().isEmpty) return;
                await _firestore.updateIncomeRecord(r.id, {
                  'amount': amount,
                  'currency': currencyController.text.trim().isEmpty ? 'EGP' : currencyController.text.trim(),
                  'source': sourceController.text.trim(),
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  'incomeDate': Timestamp.fromDate(selectedDate),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteIncome(BuildContext context, IncomeRecordModel r, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmAction)),
        ],
      ),
    );
    if (confirmed == true) await _firestore.deleteIncomeRecord(r.id);
  }

  static const List<String> _expenseCategories = ['Salary', 'Rent', 'Utilities', 'Supplies', 'Equipment', 'Other'];

  Future<void> _showAddExpense(BuildContext context, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController();
    final categoryController = TextEditingController(text: 'Salary');
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    UserModel? selectedEmployee;
    final staff = await _firestore.getUsers();
    final staffList = staff.where((u) => u.hasAnyRole([UserRole.doctor, UserRole.secretary, UserRole.trainee])).toList();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isSalary = categoryController.text == 'Salary';
          return AlertDialog(
          title: Text(l10n.addExpense),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _expenseCategories.contains(categoryController.text) ? categoryController.text : _expenseCategories.first,
                  decoration: InputDecoration(labelText: l10n.category),
                  items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    categoryController.text = v ?? 'Salary';
                    if (v != 'Salary') selectedEmployee = null;
                    setState(() {});
                  },
                ),
                if (isSalary) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserModel?>(
                    value: selectedEmployee,
                    decoration: InputDecoration(labelText: l10n.employeeOptional),
                    items: [
                      const DropdownMenuItem<UserModel?>(value: null, child: Text('—')),
                      ...staffList.map((u) => DropdownMenuItem<UserModel?>(value: u, child: Text(u.displayName))),
                    ],
                    onChanged: (u) => setState(() => selectedEmployee = u),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: l10n.description),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(DateFormat.yMd().format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || categoryController.text.trim().isEmpty) return;
                final category = categoryController.text.trim().isEmpty ? 'Salary' : categoryController.text.trim();
                await _firestore.addExpenseRecord(ExpenseRecordModel(
                  id: '',
                  amount: amount,
                  category: category,
                  description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                  recipientUserId: selectedEmployee?.id,
                  recipientName: selectedEmployee?.displayName,
                  recordedByUserId: uid,
                  expenseDate: selectedDate,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _showEditExpense(BuildContext context, ExpenseRecordModel r, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController(text: r.amount.toString());
    final categoryController = TextEditingController(text: r.category);
    final descriptionController = TextEditingController(text: r.description ?? '');
    DateTime selectedDate = r.expenseDate;
    final staff = await _firestore.getUsers();
    final staffList = staff.where((u) => u.hasAnyRole([UserRole.doctor, UserRole.secretary, UserRole.trainee])).toList();
    UserModel? selectedEmployee;
    if (r.recipientUserId != null) {
      try {
        selectedEmployee = staffList.firstWhere((u) => u.id == r.recipientUserId);
      } catch (_) {
        selectedEmployee = null;
      }
    }

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isSalary = categoryController.text == 'Salary';
          return AlertDialog(
            title: Text(l10n.edit),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.amount),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _expenseCategories.contains(categoryController.text) ? categoryController.text : _expenseCategories.first,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      categoryController.text = v ?? 'Salary';
                      if (v != 'Salary') selectedEmployee = null;
                      setState(() {});
                    },
                  ),
                  if (isSalary) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UserModel?>(
                      value: selectedEmployee,
                      decoration: InputDecoration(labelText: l10n.employeeOptional),
                      items: [
                        const DropdownMenuItem<UserModel?>(value: null, child: Text('—')),
                        ...staffList.map((u) => DropdownMenuItem<UserModel?>(value: u, child: Text(u.displayName))),
                      ],
                      onChanged: (u) => setState(() => selectedEmployee = u),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: l10n.description),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(DateFormat.yMd().format(selectedDate)),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => selectedDate = d);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0 || categoryController.text.trim().isEmpty) return;
                  final category = categoryController.text.trim().isEmpty ? 'Salary' : categoryController.text.trim();
                  await _firestore.updateExpenseRecord(r.id, {
                    'amount': amount,
                    'category': category,
                    'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    'recipientUserId': selectedEmployee?.id,
                    'recipientName': selectedEmployee?.displayName,
                    'expenseDate': Timestamp.fromDate(selectedDate),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteExpense(BuildContext context, ExpenseRecordModel r, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmAction)),
        ],
      ),
    );
    if (confirmed == true) await _firestore.deleteExpenseRecord(r.id);
  }
}
