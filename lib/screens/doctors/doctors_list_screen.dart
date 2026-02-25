import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor_model.dart';
import '../../services/firestore_service.dart';

const List<String> _dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _availabilityText(List<DoctorAvailabilityModel> list) {
  if (list.isEmpty) return '';
  return list.map((a) => '${_dayNames[a.dayOfWeek]} ${a.startTime}-${a.endTime}').join(', ');
}

class DoctorsListScreen extends StatefulWidget {
  const DoctorsListScreen({super.key});

  @override
  State<DoctorsListScreen> createState() => _DoctorsListScreenState();
}

class _DoctorsListScreenState extends State<DoctorsListScreen> {
  final FirestoreService _firestore = FirestoreService();
  final _searchController = TextEditingController();
  List<DoctorModel> _allDoctors = [];
  List<DoctorModel> _filtered = [];
  Map<String, String> _userNames = {};
  Map<String, List<DoctorAvailabilityModel>> _availability = {};
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

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_allDoctors));
      return;
    }
    setState(() {
      _filtered = _allDoctors.where((d) {
        final name = (_userNames[d.userId] ?? d.displayName ?? '').toLowerCase();
        final spec = (d.specializationEn ?? d.specializationAr ?? '').toLowerCase();
        final qual = (d.qualificationsEn ?? d.qualificationsAr ?? '').toLowerCase();
        return name.contains(q) || spec.contains(q) || qual.contains(q);
      }).toList();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final doctors = await _firestore.getDoctors();
      final names = <String, String>{};
      final availability = <String, List<DoctorAvailabilityModel>>{};
      for (final d in doctors) {
        if (d.userId.isNotEmpty) {
          try {
            final u = await _firestore.getUser(d.userId);
            names[d.userId] = u?.displayName ?? d.displayName ?? d.userId;
          } catch (_) {
            names[d.userId] = d.displayName ?? d.userId;
          }
        }
        try {
          availability[d.id] = await _firestore.getDoctorAvailability(d.id);
        } catch (_) {
          availability[d.id] = [];
        }
      }
      if (!mounted) return;
      setState(() {
        _allDoctors = doctors;
        _filtered = List.from(doctors);
        _userNames = names;
        _availability = availability;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e, st) {
      debugPrint('DoctorsListScreen _load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
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
          title: Text(l10n.ourDoctors),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
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
                                Text(_errorMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  onPressed: _load,
                                ),
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
                              final d = _filtered[i];
                              final name = _userNames[d.userId] ?? d.displayName ?? d.userId;
                              final qual = isRtl ? (d.qualificationsAr ?? d.qualificationsEn) : (d.qualificationsEn ?? d.qualificationsAr);
                              final spec = isRtl ? (d.specializationAr ?? d.specializationEn) : (d.specializationEn ?? d.specializationAr);
                              final avail = _availability[d.id];
                              final availText = avail != null && avail.isNotEmpty ? _availabilityText(avail) : null;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                                      if (spec != null && spec.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text('${l10n.specialization}: $spec', style: Theme.of(context).textTheme.bodyMedium),
                                        ),
                                      if (qual != null && qual.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text('${l10n.qualifications}: $qual', style: Theme.of(context).textTheme.bodySmall),
                                        ),
                                      if (availText != null && availText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.schedule, size: 16, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 6),
                                              Expanded(child: Text('${l10n.availableTime}: $availText', style: Theme.of(context).textTheme.bodySmall)),
                                            ],
                                          ),
                                        ),
                                      if (d.bio != null && d.bio!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(d.bio!, style: Theme.of(context).textTheme.bodySmall),
                                        ),
                                    ],
                                  ),
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
