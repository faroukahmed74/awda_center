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
import '../../services/firestore_service.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expenseSub;

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
    final isRtl = l10n.isArabic;

    final totalIncome = _income.fold<double>(0, (s, r) => s + r.amount);
    final totalExpense = _expense.fold<double>(0, (s, r) => s + r.amount);
    final net = totalIncome - totalExpense;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.incomeAndExpenses),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          actions: [
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
                              color: Theme.of(context).colorScheme.errorContainer,
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
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.net, style: Theme.of(context).textTheme.titleMedium),
                              Text(NumberFormat.currency(symbol: '').format(net), style: Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.income, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_income.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                      else
                        ..._income.take(50).map((r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(r.source),
                                subtitle: Text(DateFormat.yMd().format(r.incomeDate)),
                                trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
                              ),
                            )),
                      const SizedBox(height: 16),
                      Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_expense.isEmpty)
                        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                      else
                        ..._expense.take(50).map((r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(_expenseTitle(r)),
                                subtitle: Text(DateFormat.yMd().format(r.expenseDate)),
                                trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
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
}
