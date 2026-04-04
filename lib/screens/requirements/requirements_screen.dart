import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/center_requirement_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/main_app_bar_actions.dart';

/// Center requirements / to-buy list. Admin (or users with requirements permission) can CRUD.
class RequirementsScreen extends StatefulWidget {
  const RequirementsScreen({super.key});

  @override
  State<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<CenterRequirementModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getCenterRequirements();
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showAdd(BuildContext context, AppLocalizations l10n, String? uid) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final quantity = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addRequirement),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: InputDecoration(labelText: l10n.name)),
              const SizedBox(height: 8),
              TextField(controller: description, decoration: InputDecoration(labelText: l10n.description), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: quantity, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.text),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              await _firestore.addCenterRequirement(CenterRequirementModel(
                id: '',
                title: title.text.trim(),
                description: description.text.trim().isEmpty ? null : description.text.trim(),
                quantity: quantity.text.trim().isEmpty ? null : quantity.text.trim(),
                createdByUserId: uid,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleComplete(CenterRequirementModel r) async {
    await _firestore.updateCenterRequirement(r.id, {'completed': !r.completed});
    _load();
  }

  Future<void> _delete(CenterRequirementModel r, BuildContext context, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text('Delete "${r.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.deleteCenterRequirement(r.id);
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
          title: Text(l10n.requirements),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            ...MainAppBarActions.notificationsLanguageTheme(context),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addRequirement,
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
                          final r = _list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: r.completed,
                                onChanged: (_) => _toggleComplete(r),
                              ),
                              title: Text(
                                r.title,
                                style: r.completed ? TextStyle(decoration: TextDecoration.lineThrough) : null,
                              ),
                              subtitle: (r.description != null || r.quantity != null)
                                  ? Text([if (r.quantity != null) 'Qty: ${r.quantity}', r.description].where((e) => e != null && e.toString().isNotEmpty).join(' • '))
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _delete(r, context, l10n),
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
