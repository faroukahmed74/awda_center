import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/admin_todo_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Admin to-do list with due date and reminder. Reschedules local reminders on change.
class AdminTodosScreen extends StatefulWidget {
  const AdminTodosScreen({super.key});

  @override
  State<AdminTodosScreen> createState() => _AdminTodosScreenState();
}

class _AdminTodosScreenState extends State<AdminTodosScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<AdminTodoModel> _list = [];
  bool _loading = true;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getAdminTodos(includeCompleted: _showCompleted);
    setState(() {
      _list = list;
      _loading = false;
    });
    if (mounted) {
      final uid = context.read<AuthProvider>().currentUser?.id;
      NotificationService().rescheduleRemindersForUser(uid);
    }
  }

  Future<void> _showAdd(BuildContext context, AppLocalizations l10n, String? uid) async {
    final title = TextEditingController();
    final description = TextEditingController();
    DateTime? dueDate;
    DateTime? reminderAt;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.addTodo),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: InputDecoration(labelText: l10n.name)),
                const SizedBox(height: 8),
                TextField(controller: description, decoration: InputDecoration(labelText: l10n.description), maxLines: 2),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(dueDate == null ? l10n.dueDate : DateFormat.yMd().format(dueDate!)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => dueDate = d);
                  },
                ),
                ListTile(
                  title: Text(reminderAt == null ? l10n.reminder : DateFormat.yMd().add_Hm().format(reminderAt!)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: reminderAt ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null && ctx.mounted) {
                      final t = await showTimePicker(context: ctx, initialTime: reminderAt != null ? TimeOfDay(hour: reminderAt!.hour, minute: reminderAt!.minute) : TimeOfDay.now());
                      if (t != null) setState(() => reminderAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                await _firestore.addAdminTodo(AdminTodoModel(
                  id: '',
                  title: title.text.trim(),
                  description: description.text.trim().isEmpty ? null : description.text.trim(),
                  dueDate: dueDate,
                  reminderAt: reminderAt,
                  createdByUserId: uid,
                ));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComplete(AdminTodoModel t) async {
    await _firestore.updateAdminTodo(t.id, {'completed': !t.completed});
    _load();
  }

  Future<void> _delete(AdminTodoModel t, BuildContext context, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text('Delete "${t.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteAdminTodo(t.id);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;
    final uid = context.watch<AuthProvider>().currentUser?.id;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.toDoList),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            IconButton(
              icon: Icon(_showCompleted ? Icons.filter_list_off : Icons.done_all),
              tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
              onPressed: () {
                setState(() {
                  _showCompleted = !_showCompleted;
                  _load();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addTodo,
              onPressed: () => _showAdd(context, l10n, uid),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _list.isEmpty
                    ? Center(child: Text(l10n.noData))
                    : ListView.builder(
                        padding: responsiveListPadding(context),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final t = _list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: t.completed,
                                onChanged: (_) => _toggleComplete(t),
                              ),
                              title: Text(
                                t.title,
                                style: t.completed ? TextStyle(decoration: TextDecoration.lineThrough) : null,
                              ),
                              subtitle: Text([
                                if (t.dueDate != null) '${l10n.dueDate}: ${DateFormat.yMd().format(t.dueDate!)}',
                                if (t.reminderAt != null) '${l10n.reminder}: ${DateFormat.yMd().add_Hm().format(t.reminderAt!)}',
                                t.description,
                              ].where((e) => e != null && e.toString().isNotEmpty).join(' • ')),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(t, context, l10n),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
