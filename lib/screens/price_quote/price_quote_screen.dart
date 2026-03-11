import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_logo.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/package_model.dart';
import '../../models/service_model.dart';
import '../../services/firestore_service.dart';

/// Price Quote: lists all active services and packages with price and description.
/// Available to all users from the side drawer.
class PriceQuoteScreen extends StatefulWidget {
  const PriceQuoteScreen({super.key});

  @override
  State<PriceQuoteScreen> createState() => _PriceQuoteScreenState();
}

class _PriceQuoteScreenState extends State<PriceQuoteScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ServiceModel> _services = [];
  List<PackageModel> _packages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = await _firestore.getAllServices();
      final packages = await _firestore.getAllPackages();
      setState(() {
        _services = services.where((s) => s.isActive).toList();
        _packages = packages.where((p) => p.isActive).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;
    final theme = Theme.of(context);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 28),
              const SizedBox(width: 10),
              Text(l10n.priceQuote),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: ResponsivePadding.all(context),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_services.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    l10n.services,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth >= Breakpoint.tablet) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: _services
                                                  .asMap()
                                                  .entries
                                                  .where((e) => e.key % 2 == 0)
                                                  .map((e) => _ServiceCard(service: e.value))
                                                  .toList(),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              children: _services
                                                  .asMap()
                                                  .entries
                                                  .where((e) => e.key % 2 == 1)
                                                  .map((e) => _ServiceCard(service: e.value))
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: _services
                                          .map((s) => _ServiceCard(service: s))
                                          .toList(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),
                              ],
                              if (_packages.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    l10n.packages,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth >= Breakpoint.tablet) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: _packages
                                                  .asMap()
                                                  .entries
                                                  .where((e) => e.key % 2 == 0)
                                                  .map((e) => _PackageCard(package: e.value))
                                                  .toList(),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              children: _packages
                                                  .asMap()
                                                  .entries
                                                  .where((e) => e.key % 2 == 1)
                                                  .map((e) => _PackageCard(package: e.value))
                                                  .toList(),
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Column(
                                      children: _packages
                                          .map((p) => _PackageCard(package: p))
                                          .toList(),
                                    );
                                  },
                                ),
                              ],
                              if (_services.isEmpty && _packages.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text(l10n.noData, style: theme.textTheme.bodyLarge),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = service.description;
    final bullets = desc != null && desc.isNotEmpty
        ? desc.split(RegExp(r'[\n\r]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services_outlined, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${service.amount != null ? service.amount!.toStringAsFixed(0) : '—'} LE',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...bullets.map((line) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                        Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PackageModel package;

  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final desc = package.description;
    final bullets = desc != null && desc.isNotEmpty
        ? desc.split(RegExp(r'[\n\r]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: theme.colorScheme.secondary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    package.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${package.amount.toStringAsFixed(0)} LE',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${l10n.numberOfSessions}: ${package.numberOfSessions}',
              style: theme.textTheme.bodySmall,
            ),
            if (bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...bullets.map((line) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary)),
                        Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
