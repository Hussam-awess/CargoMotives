import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/commission_repository.dart';

/// Earnings (AppFlow §2.6/§2.7): the running commission balance, an On
/// Hold banner when the balance has crossed the configurable threshold
/// (bidding is paused server-side either way — BidController — this is
/// just making the same rule visible before a company tries to bid and
/// hits the error), a Pay via Mobile Money form, and the ledger history.
class EarningsScreen extends StatefulWidget {
  EarningsScreen({super.key, CommissionRepository? repository}) : repository = repository ?? CommissionRepository();

  final CommissionRepository repository;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  CommissionSummary? _summary;
  List<CommissionLedgerEntry> _ledger = [];
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
      final summary = await widget.repository.summary();
      final ledger = await widget.repository.ledger();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _ledger = ledger;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load your earnings.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPayForm() async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PayCommissionSheet(repository: widget.repository, maxAmount: _summary!.outstandingBalance),
    );
    if (paid == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary!.isOnHold) ...[
                    const _OnHoldBanner(),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Commission due', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(
                            'TZS ${_summary!.outstandingBalance.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _summary!.outstandingBalance > 0 ? _openPayForm : null,
                            child: const Text('Pay via Mobile Money'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('History', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_ledger.isEmpty) const Text('No commission activity yet.', style: TextStyle(color: AppColors.textSecondary)),
                  for (final entry in _ledger) ...[
                    _LedgerRow(entry: entry),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OnHoldBanner extends StatelessWidget {
  const _OnHoldBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.statusError.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.statusError),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account is on hold. Bidding is paused until the balance is paid down.',
              style: TextStyle(color: AppColors.statusError, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final CommissionLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            entry.isCharge ? Icons.arrow_upward : Icons.arrow_downward,
            color: entry.isCharge ? AppColors.statusError : AppColors.statusLive,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isCharge ? 'Commission charge' : 'Payment', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(entry.createdAt.toLocal().toString(), style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Text(
            '${entry.isCharge ? '+' : '-'}TZS ${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: entry.isCharge ? AppColors.statusError : AppColors.statusLive),
          ),
        ],
      ),
    );
  }
}

class _PayCommissionSheet extends StatefulWidget {
  const _PayCommissionSheet({required this.repository, required this.maxAmount});

  final CommissionRepository repository;
  final double maxAmount;

  @override
  State<_PayCommissionSheet> createState() => _PayCommissionSheetState();
}

class _PayCommissionSheetState extends State<_PayCommissionSheet> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String _provider = 'mpesa';
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.maxAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Enter your mobile money phone number.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payment = await widget.repository.payCommission(
        amount: amount,
        provider: _provider,
        phoneNumber: _phoneController.text.trim(),
      );
      if (!mounted) return;
      if (payment.isPending) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your phone to approve the payment.')),
        );
      } else {
        setState(() => _error = 'The payment could not be started. Please try again.');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.firstErrorFor('amount') ?? e.message);
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
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount (TZS)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
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
