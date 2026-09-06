import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/featured_repository.dart';

/// Upgrade to Featured (Customer) — AppFlow §3.6: "explains the higher
/// daily post quota → pay via mobile money → unlocks immediately."
/// JobPostQuotaService already reads users.is_featured (Phase 4); this
/// screen is only the purchase flow.
class CustomerFeaturedScreen extends StatefulWidget {
  CustomerFeaturedScreen({super.key, CustomerFeaturedRepository? repository}) : repository = repository ?? CustomerFeaturedRepository();

  final CustomerFeaturedRepository repository;

  @override
  State<CustomerFeaturedScreen> createState() => _CustomerFeaturedScreenState();
}

class _CustomerFeaturedScreenState extends State<CustomerFeaturedScreen> {
  CustomerFeaturedStatus? _status;
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
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_status!.isFeatured) ...[
                    const Icon(Icons.star, color: AppColors.accent, size: 48),
                    const SizedBox(height: 12),
                    Text('You\'re Featured', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    if (_status!.featuredUntil != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Until ${_status!.featuredUntil!.toLocal().toString().split(' ').first}',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    Text('Upgrade to Featured', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text('Post more jobs per day with a higher daily quota.', textAlign: TextAlign.center),
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
            ),
    );
  }
}

class _PurchaseSheet extends StatefulWidget {
  const _PurchaseSheet({required this.repository});

  final CustomerFeaturedRepository repository;

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
