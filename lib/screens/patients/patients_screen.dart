import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _searchController = TextEditingController();
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final list = await _firestore.getPatients();
      if (!mounted) return;
      setState(() {
        _all = list;
        _applyFilter();
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('PatientsScreen _load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_all));
      return;
    }
    setState(() {
      _filtered = _all.where((u) {
        final name = u.displayName.toLowerCase();
        final email = u.email.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.patients),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
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
                                Text(_errorMessage!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                FilledButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
                              ],
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                          ? Center(child: Text(l10n.noData))
                          : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: responsiveListPadding(context),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final u = _filtered[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(u.displayName),
                                  subtitle: Text(u.email),
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
