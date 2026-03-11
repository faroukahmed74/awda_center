import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/service_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';

/// Admin: Services CRUD. Services appear in the appointment form dropdown.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ServiceModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _firestore.getAllServices();
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm(BuildContext context, AppLocalizations l10n, [ServiceModel? existing]) async {
    final nameAr = TextEditingController(text: existing?.nameAr ?? '');
    final nameEn = TextEditingController(text: existing?.nameEn ?? '');
    final descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    final amountCtrl = TextEditingController(text: existing?.amount != null ? existing!.amount!.toStringAsFixed(2) : '');
    var isActive = existing?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? l10n.addService : l10n.editService),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'Name (Arabic)')),
                const SizedBox(height: 8),
                TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'Name (English)')),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  decoration: InputDecoration(labelText: l10n.description),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(labelText: l10n.serviceAmount),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text(l10n.active),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            if (existing != null)
              TextButton(
                onPressed: () async {
                  final toDelete = existing;
                  Navigator.pop(ctx);
                  await _delete(toDelete, context, l10n);
                },
                child: Text(l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                final description = descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim();
                if (existing != null) {
                  await _firestore.updateService(existing.id, {
                    'nameAr': nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                    'nameEn': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                    'description': description,
                    'amount': amount,
                    'isActive': isActive,
                  });
                } else {
                  await _firestore.addService(ServiceModel(
                    id: '',
                    nameAr: nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                    nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                    description: description,
                    amount: amount,
                    isActive: isActive,
                  ));
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(ServiceModel s, BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text('${l10n.service}: ${s.displayName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.deleteService(s.id);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.services),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(icon: const Icon(Icons.add), tooltip: l10n.addService, onPressed: () => _showForm(context, l10n)),
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
                          final s = _list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(s.displayName),
                              subtitle: Text([
                                s.isActive ? l10n.active : l10n.inactive,
                                if (s.amount != null) '${l10n.amount}: ${s.amount!.toStringAsFixed(2)}',
                                if (s.description != null && s.description!.isNotEmpty) s.description!,
                              ].where((e) => e.isNotEmpty).join(' · ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(context, l10n, s)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s, context, l10n)),
                                ],
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
