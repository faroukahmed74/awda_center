import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/package_model.dart';
import '../../models/service_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';

/// Admin: Packages CRUD. A package has specific services, number of sessions, and a fixed amount.
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<PackageModel> _list = [];
  List<ServiceModel> _services = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _firestore.getAllPackages(),
        _firestore.getAllServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _list = results[0] as List<PackageModel>;
        _services = results[1] as List<ServiceModel>;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _showForm(BuildContext context, AppLocalizations l10n, [PackageModel? existing]) async {
    final nameAr = TextEditingController(text: existing?.nameAr ?? '');
    final nameEn = TextEditingController(text: existing?.nameEn ?? '');
    final descriptionCtrl = TextEditingController(text: existing?.description ?? '');
    final sessionsCtrl = TextEditingController(text: existing != null ? '${existing.numberOfSessions}' : '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    var selectedServiceIds = List<String>.from(existing?.serviceIds ?? []);
    var isActive = existing?.isActive ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final availableServices = _services.where((s) => !selectedServiceIds.contains(s.id)).toList();
          return AlertDialog(
            title: Text(existing == null ? l10n.addPackage : l10n.editPackage),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Text(l10n.packageServices, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...selectedServiceIds.map((id) {
                        ServiceModel? s;
                        for (final x in _services) if (x.id == id) { s = x; break; }
                        final name = s?.displayName ?? id;
                        return Chip(
                          label: Text(name),
                          onDeleted: () => setState(() => selectedServiceIds = List.from(selectedServiceIds)..remove(id)),
                        );
                      }),
                      if (availableServices.isNotEmpty)
                        InputDecorator(
                          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: null,
                              isExpanded: true,
                              hint: Text(l10n.service, style: Theme.of(context).textTheme.bodyMedium),
                              items: availableServices.map((s) => DropdownMenuItem<String>(value: s.id, child: Text(s.displayName))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => selectedServiceIds = List.from(selectedServiceIds)..add(v));
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sessionsCtrl,
                    decoration: InputDecoration(labelText: l10n.numberOfSessions),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(labelText: l10n.packageAmount),
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
                  final sessions = int.tryParse(sessionsCtrl.text.trim()) ?? 1;
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final description = descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim();
                  if (existing != null) {
                    await _firestore.updatePackage(existing.id, {
                      'nameAr': nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                      'nameEn': nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                      'description': description,
                      'serviceIds': selectedServiceIds,
                      'numberOfSessions': sessions,
                      'amount': amount,
                      'isActive': isActive,
                    });
                  } else {
                    await _firestore.addPackage(PackageModel(
                      id: '',
                      nameAr: nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
                      nameEn: nameEn.text.trim().isEmpty ? null : nameEn.text.trim(),
                      description: description,
                      serviceIds: selectedServiceIds,
                      numberOfSessions: sessions,
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
          );
        },
      ),
    );
  }

  Future<void> _delete(PackageModel pkg, BuildContext context, AppLocalizations l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirm),
        content: Text('${l10n.packages}: ${pkg.displayName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.deletePackage(pkg.id);
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
          title: Text(l10n.packages),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(icon: const Icon(Icons.add), tooltip: l10n.addPackage, onPressed: () => _showForm(context, l10n)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                            onPressed: _load,
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _list.isEmpty
                        ? Center(child: Text(l10n.noData))
                        : ListView.builder(
                        padding: responsiveListPadding(context),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final p = _list[i];
                          String serviceName(String id) {
                            for (final s in _services) if (s.id == id) return s.displayName;
                            return id;
                          }
                          final serviceNames = p.serviceIds.map(serviceName).join(', ');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(p.displayName),
                              subtitle: Text([
                                p.isActive ? l10n.active : l10n.inactive,
                                '${l10n.numberOfSessions}: ${p.numberOfSessions}',
                                '${l10n.amount}: ${p.amount.toStringAsFixed(2)}',
                                if (serviceNames.isNotEmpty) serviceNames,
                                if (p.description != null && p.description!.isNotEmpty) p.description!,
                              ].where((e) => e.isNotEmpty).join(' · ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(context, l10n, p)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(p, context, l10n)),
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
