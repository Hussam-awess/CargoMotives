import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary!.isOnHold) ...[const _OnHoldBanner(), const SizedBox(height: 16)],
                  _CommissionCard(summary: _summary!, ledger: _ledger, onPay: _openPayForm),
                  const SizedBox(height: 24),
                  const Text(
                    'HISTORY',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
                  ),
                  const SizedBox(height: 8),
                  if (_ledger.isEmpty) const Text('No commission activity yet.', style: TextStyle(color: AppColors.textSecondary)),
                  for (final entry in _ledger) _LedgerRow(entry: entry),
                ],
              ),
            ),
    );
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({required this.summary, required this.ledger, required this.onPay});

  final CommissionSummary summary;
  final List<CommissionLedgerEntry> ledger;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final charged = ledger.where((e) => e.isCharge).fold<double>(0, (sum, e) => sum + e.amount);
    final paid = ledger.where((e) => !e.isCharge).fold<double>(0, (sum, e) => sum + e.amount);
    final trips = ledger.where((e) => e.isCharge).length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Commission due', style: TextStyle(fontSize: 12.5, color: AppColors.lightBlue, letterSpacing: 0.4)),
          Text(
            'TZS ${summary.outstandingBalance.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.13))),
              ),
              child: Row(
                children: [
                  _Stat(label: 'Charged', value: 'TZS ${charged.toStringAsFixed(0)}'),
                  const SizedBox(width: 22),
                  _Stat(label: 'Paid', value: 'TZS ${paid.toStringAsFixed(0)}'),
                  const SizedBox(width: 22),
                  _Stat(label: 'Trips', value: '$trips'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: summary.outstandingBalance > 0 ? onPay : null,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.ctaBlue, minimumSize: const Size.fromHeight(44)),
              child: const Text('Pay via Mobile Money'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.lightBlue)),
        Text(
          value,
          style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F2))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: Icon(
              entry.isCharge ? Icons.arrow_upward : Icons.arrow_downward,
              color: entry.isCharge ? AppColors.statusError : AppColors.statusLive,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isCharge ? 'Commission charge' : 'Payment', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  DateFormat('d MMM, HH:mm').format(entry.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
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
      final payment = await widget.repository.payCommission(amount: amount, provider: _provider, phoneNumber: _phoneController.text.trim());
      if (!mounted) return;
      if (payment.isPending) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check your phone to approve the payment.')));
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
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
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
