import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/local/local_prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../data/payment_repository.dart';

const _defaultPaymentMethodKey = 'customer.default_payment_method';

/// The method names double as the values saved in [LocalPrefs], so they
/// stay fixed English identifiers — only 'Bank transfer' needs translating
/// for display; the rest are brand names.
String _methodLabel(String method, AppLocalizations l10n) =>
    method == 'Bank transfer' ? l10n.bankTransferLabel : method;

/// Real Payment History (shared between Customer and Company — a `Payment`
/// belongs to whichever role's own User row made it). Every payment shown
/// here today is a Cargo Motives Plus purchase (`featured_company`/
/// `featured_customer`) — `commission_payment` exists on the backend enum
/// but nothing writes it yet, so it just won't appear until it does.
/// `Payment` has no stored currency (Plus pricing has never offered a
/// currency choice), so amounts are shown in TZS — the only currency Plus
/// has ever actually been priced in.
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({
    super.key,
    required this.repository,
    this.prefs = const LocalPrefs(),
  });

  final PaymentRepository repository;
  final LocalPrefs prefs;

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<Payment>? _payments;
  bool _isLoading = true;
  bool _loadFailed = false;
  String _defaultMethod = 'M-Pesa';

  @override
  void initState() {
    super.initState();
    _load();
    _loadDefaultMethod();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final payments = await widget.repository.list();
      if (mounted) setState(() => _payments = payments);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDefaultMethod() async {
    final saved = await widget.prefs.getString(_defaultPaymentMethodKey);
    if (mounted && saved != null) setState(() => _defaultMethod = saved);
  }

  Future<void> _changeMethod() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => _MethodPicker(current: _defaultMethod),
    );
    if (selected == null) return;
    await widget.prefs.setString(_defaultPaymentMethodKey, selected);
    if (mounted) setState(() => _defaultMethod = selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final payments = _payments;
    final succeeded = payments?.where((p) => p.succeeded).toList() ?? const [];
    final totalPaid = succeeded.fold<double>(0, (sum, p) => sum + p.amount);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentHistoryTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.couldNotLoadPaymentHistory),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: Text(l10n.tryAgainLabel)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: AppColors.brandChip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.totalPaidLabel,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.lightBlue),
                        ),
                        Text(
                          'TZS ${NumberFormat('#,###').format(totalPaid)}',
                          style: const TextStyle(
                            fontFamily: 'Barlow Condensed',
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  _Stat(
                                    label: l10n.latestPaymentLabel,
                                    value: succeeded.isEmpty
                                        ? '—'
                                        : 'TZS ${NumberFormat('#,###').format(succeeded.first.amount)}',
                                  ),
                                  const SizedBox(width: 20),
                                  _Stat(label: l10n.paymentsCountLabel, value: '${succeeded.length}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initialsFor(_defaultMethod),
                            style: TextStyle(
                              fontFamily: 'Barlow Condensed',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textLabel,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _methodLabel(_defaultMethod, l10n),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                l10n.defaultPaymentMethodLabel,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(onPressed: _changeMethod, child: Text(l10n.changeLabel)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 6),
                    child: Text(l10n.transactionsLabel, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (payments == null || payments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        l10n.noPaymentsYet,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (var i = 0; i < payments.length; i++)
                      _PaymentRow(payment: payments[i], isLast: i == payments.length - 1),
                ],
              ),
            ),
    );
  }

  String _initialsFor(String method) => switch (method) {
    'M-Pesa' => 'MP',
    'Airtel Money' => 'AM',
    'Tigo Pesa' => 'TP',
    'Bank transfer' => 'BK',
    _ => method.isNotEmpty ? method[0] : '?',
  };
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
          style: const TextStyle(
            fontFamily: 'Barlow Condensed',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, this.isLast = false});

  final Payment payment;
  final bool isLast;

  Color get _statusColor => switch (payment.status) {
    'succeeded' => AppColors.statusLive,
    'failed' => AppColors.statusError,
    _ => AppColors.textSecondary,
  };

  String _purposeLabel(AppLocalizations l10n) => switch (payment.purpose) {
    'featured_company' || 'featured_customer' => l10n.cargoMotivesPlusLabel,
    'commission_payment' => l10n.commissionPaymentLabel,
    _ => payment.purpose,
  };

  String _statusLabel(AppLocalizations l10n) => switch (payment.status) {
    'succeeded' => l10n.paymentStatusPaid,
    'pending_confirmation' => l10n.paymentStatusPending,
    'initiated' => l10n.paymentStatusInitiated,
    'failed' => l10n.paymentStatusFailed,
    _ => payment.status,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: isLast
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.bolt, size: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _purposeLabel(l10n),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '${DateFormat('d MMM yyyy').format(payment.createdAt)}'
                  '${payment.mobileMoneyProvider != null ? ' · ${payment.mobileMoneyProvider}' : ''}'
                  ' · ${_statusLabel(l10n)}',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat('#,###').format(payment.amount),
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({required this.current});

  final String current;

  static const _methods = ['M-Pesa', 'Airtel Money', 'Tigo Pesa', 'Bank transfer'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final method in _methods)
            ListTile(
              title: Text(_methodLabel(method, l10n)),
              trailing: method == current ? const Icon(Icons.check, color: AppColors.ctaBlue) : null,
              onTap: () => Navigator.of(context).pop(method),
            ),
        ],
      ),
    );
  }
}
