import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../widgets/notifications_button.dart';
import 'add_patient_dialog.dart';

class PatientsScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final bool focusSearch;

  const PatientsScreen({super.key, this.initialSearchQuery, this.focusSearch = false});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!;
    }
    _searchController.addListener(() => setState(() {}));
    if (widget.focusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;
    final cache = context.watch<DataCacheProvider>();

    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? cache.patients
        : cache.patients.where((u) {
            final name = u.displayName.toLowerCase();
            final email = u.email.toLowerCase();
            final phone = (u.phone ?? '').toLowerCase();
            final code = (u.patientCode ?? '').toLowerCase();
            return name.contains(q) || email.contains(q) || phone.contains(q) || code.contains(q);
          }).toList();

    final showLoading = cache.usersLoading && cache.patients.isEmpty;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.patients),
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
        floatingActionButton: context.watch<AuthProvider>().currentUser?.canAccessPatients == true
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final patientId = await showDialog<String>(
                    context: context,
                    builder: (_) => const AddPatientDialog(),
                  );
                  if (patientId != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.patientAdded)),
                    );
                    context.push('/patients/$patientId');
                  }
                },
                icon: const Icon(Icons.person_add),
                label: Text(l10n.addNewPatient),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: l10n.searchByPatientCodeHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: showLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cache.patients.isEmpty ? l10n.noPatientsYet : l10n.noSearchResults,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (cache.patients.isEmpty && context.watch<AuthProvider>().currentUser?.canAccessPatients == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(l10n.addNewPatient, style: Theme.of(context).textTheme.bodySmall),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => setState(() {}),
                          child: ListView.builder(
                            padding: responsiveListPadding(context),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final u = filtered[i];
                              final subtitle = u.patientCode != null && u.patientCode!.isNotEmpty
                                  ? '${u.email} • ${l10n.patientCode}: ${u.patientCode}'
                                  : u.email;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(u.displayName),
                                  subtitle: Text(subtitle),
                                  onTap: () => context.push('/patients/${u.id}'),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
