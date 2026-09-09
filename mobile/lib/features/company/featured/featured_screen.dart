import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/featured_repository.dart';

/// Upgrade to Featured (Company) — AppFlow §2.7: "explains the
/// higher/faster bid quota, priority placement, fleet map, route filter,
/// and return-load suggestions → pay via mobile money → unlocks
/// immediately." The tools themselves are automatic once is_featured
/// flips (bid quota/priority: BidQuotaService/BidController, Phase 4;
/// fleet map/route filter/return-load: Phase 8's other endpoints) — this
/// screen is only the purchase flow and the preferred-routes setting.
class CompanyFeaturedScreen extends StatefulWidget {
  CompanyFeaturedScreen({super.key, CompanyFeaturedRepository? repository}) : repository = repository ?? CompanyFeaturedRepository();

  final CompanyFeaturedRepository repository;

  @override
  State<CompanyFeaturedScreen> createState() => _CompanyFeaturedScreenState();
}

class _CompanyFeaturedScreenState extends State<CompanyFeaturedScreen> {
  CompanyFeaturedStatus? _status;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final status = await widget.repository.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load Featured status.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPurchaseForm() async {
    final purchased = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PurchaseSheet(repository: widget.repository),
    );
    if (purchased == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check your phone to approve the payment.')));
    }
  }

  Future<void> _editPreferredRoutes() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PreferredRoutesScreen(repository: widget.repository, initialRoutes: _status!.preferredRoutes)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Featured')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_status!.isFeatured) ...[
                  const Icon(Icons.star, color: AppColors.accent, size: 48),
                  const SizedBox(height: 12),
                  Text('You\'re Featured', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  if (_status!.featuredUntil != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Until ${_status!.featuredUntil!.toLocal().toString().split(' ').first}',
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text('Preferred routes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_status!.preferredRoutes.isEmpty)
                    const Text('No preferred routes set.', style: TextStyle(color: AppColors.textSecondary))
                  else
                    for (final route in _status!.preferredRoutes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('${route.origin} → ${route.destination}'),
                      ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _editPreferredRoutes, child: const Text('Edit preferred routes')),
                ] else ...[
                  Text('Upgrade to Featured', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const _BenefitRow(text: 'Higher, faster bid quota'),
                  const _BenefitRow(text: 'Priority placement on your bids'),
                  const _BenefitRow(text: 'A map of your own GPS-connected fleet'),
                  const _BenefitRow(text: 'Filter Open Jobs to your preferred routes'),
                  const _BenefitRow(text: 'Return-load suggestions after a delivery'),
                  const SizedBox(height: 24),
                  Text(
                    'TZS ${_status!.price.toStringAsFixed(0)} for ${_status!.durationDays} days',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _openPurchaseForm, child: const Text('Pay via Mobile Money')),
                ],
              ],
            ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.statusLive, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({required this.repository});

  final CompanyFeaturedRepository repository;

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  final _phoneController = TextEditingController();
  String _provider = 'mpesa';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your mobile money phone number.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payment = await widget.repository.purchase(provider: _provider, phoneNumber: _phoneController.text.trim());
      if (!mounted) return;
      if (payment.isPending) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'The payment could not be started. Please try again.');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pay via Mobile Money', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
              DropdownMenuItem(value: 'tigopesa', child: Text('Tigo Pesa')),
              DropdownMenuItem(value: 'airtelmoney', child: Text('Airtel Money')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _provider = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Mobile money phone number'),
            keyboardType: TextInputType.phone,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Pay now'),
          ),
        ],
      ),
    );
  }
}

/// A simple add/remove list editor for preferred_routes (AppFlow §2.7) —
/// plain text fields, no map picker, matching the same lat/lng-as-text
/// scope decision Post a Job made back in Phase 4.
class PreferredRoutesScreen extends StatefulWidget {
  const PreferredRoutesScreen({super.key, required this.repository, required this.initialRoutes});

  final CompanyFeaturedRepository repository;
  final List<PreferredRoute> initialRoutes;

  @override
  State<PreferredRoutesScreen> createState() => _PreferredRoutesScreenState();
}

class _PreferredRoutesScreenState extends State<PreferredRoutesScreen> {
  late List<PreferredRoute> _routes;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _routes = List.of(widget.initialRoutes);
  }

  Future<void> _addRoute() async {
    final added = await showDialog<PreferredRoute>(context: context, builder: (context) => const _AddRouteDialog());
    if (added != null) setState(() => _routes.add(added));
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.repository.updatePreferredRoutes(_routes);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferred routes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _routes.isEmpty
                  ? const Center(child: Text('No preferred routes yet.', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      itemCount: _routes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final route = _routes[index];

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text('${route.origin} → ${route.destination}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setState(() => _routes.removeAt(index)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _addRoute, child: const Text('Add route')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRouteDialog extends StatefulWidget {
  const _AddRouteDialog();

  @override
  State<_AddRouteDialog> createState() => _AddRouteDialogState();
}

class _AddRouteDialogState extends State<_AddRouteDialog> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add route'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _originController, decoration: const InputDecoration(labelText: 'Origin')),
          const SizedBox(height: 12),
          TextField(controller: _destinationController, decoration: const InputDecoration(labelText: 'Destination')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (_originController.text.trim().isEmpty || _destinationController.text.trim().isEmpty) return;
            Navigator.of(context).pop(PreferredRoute(origin: _originController.text.trim(), destination: _destinationController.text.trim()));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
