import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/doctor_model.dart';
import '../../providers/data_cache_provider.dart';

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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;
    final cache = context.watch<DataCacheProvider>();

    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? cache.doctors
        : cache.doctors.where((d) {
            final name = (cache.userName(d.userId) ?? d.displayName ?? '').toLowerCase();
            final spec = (d.specializationEn ?? d.specializationAr ?? '').toLowerCase();
            final qual = (d.qualificationsEn ?? d.qualificationsAr ?? '').toLowerCase();
            final cert = (d.certificationsEn ?? d.certificationsAr ?? '').toLowerCase();
            final bio = (d.bio ?? '').toLowerCase();
            return name.contains(q) || spec.contains(q) || qual.contains(q) || cert.contains(q) || bio.contains(q);
          }).toList();

    final showLoading = cache.doctorsLoading && cache.doctors.isEmpty;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.ourDoctors),
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
              child: showLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(child: Text(l10n.noData))
                      : RefreshIndicator(
                          onRefresh: () async => cache.refreshDoctorsCache(),
                          child: ListView.builder(
                            padding: responsiveListPadding(context),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final d = filtered[i];
                              final name = cache.userName(d.userId) ?? d.displayName ?? d.userId;
                              final spec = isRtl ? (d.specializationAr ?? d.specializationEn) : (d.specializationEn ?? d.specializationAr);
                              final qual = isRtl ? (d.qualificationsAr ?? d.qualificationsEn) : (d.qualificationsEn ?? d.qualificationsAr);
                              final cert = isRtl ? (d.certificationsAr ?? d.certificationsEn) : (d.certificationsEn ?? d.certificationsAr);
                              final avail = cache.doctorAvailability(d.id);
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
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.medical_services, size: 18, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('${l10n.specialization}: $spec', style: Theme.of(context).textTheme.bodyMedium),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (qual != null && qual.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.school_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('${l10n.qualifications}: $qual', style: Theme.of(context).textTheme.bodyMedium),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (cert != null && cert.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.verified_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('${l10n.certifications}: $cert', style: Theme.of(context).textTheme.bodyMedium),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (availText != null && availText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.schedule, size: 18, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('${l10n.availableTime}: $availText', style: Theme.of(context).textTheme.bodySmall),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (d.bio != null && d.bio!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(l10n.about, style: Theme.of(context).textTheme.titleSmall),
                                              const SizedBox(height: 4),
                                              Text(d.bio!, style: Theme.of(context).textTheme.bodyMedium),
                                            ],
                                          ),
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
