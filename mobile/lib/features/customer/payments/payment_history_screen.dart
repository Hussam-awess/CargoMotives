import 'package:flutter/material.dart';

import '../../../core/local/local_prefs.dart';
import '../../../core/theme/app_theme.dart';

const _defaultPaymentMethodKey = 'customer.default_payment_method';

/// "Payment History" (mockup) — this app has no real payment-history
/// feature: a customer pays a transporter directly (mobile money or bank,
/// outside the app) and Cargo Motives never records or holds that money,
/// so there is no backend ledger of these transactions to show. The
/// summary figures and transaction list below are illustrative sample
/// data, clearly a placeholder for a real payments ledger if one is ever
/// built — only the default-payment-method row is real (locally saved on
/// this device via LocalPrefs, not synced anywhere).
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key, this.prefs = const LocalPrefs()});

  final LocalPrefs prefs;

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String _defaultMethod = 'M-Pesa';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Payment History')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.brandChip,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paid for shipments this month',
                  style: TextStyle(fontSize: 12.5, color: AppColors.lightBlue),
                ),
                Text(
                  'TZS 3,560,000',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          _Stat(
                            label: 'Latest payment',
                            value: 'TZS 1,173,000',
                          ),
                          SizedBox(width: 20),
                          _Stat(label: 'Shipments paid', value: '4'),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Cargo Motives holds no balance for you. Each shipment is paid directly from your mobile money or bank at the time you book it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.lightBlue,
                          height: 1.5,
                        ),
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
                        _defaultMethod,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Default payment method',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _changeMethod,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 24, 0, 6),
            child: Text(
              'Transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            'SEPTEMBER',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          _TransactionRow(
            icon: Icons.arrow_downward,
            title: 'Payment · CM-421-Q01',
            subtitle: '12 Sep, 07:02 · M-Pesa · Paid',
            amount: '1,173,000',
            color: AppColors.textPrimary,
          ),
          _TransactionRow(
            icon: Icons.arrow_downward,
            title: 'Payment · CM-418-M44',
            subtitle: '09 Sep, 12:30 · Bank transfer',
            amount: '−1,672,800',
            color: AppColors.textPrimary,
          ),
          const _TransactionRow(
            icon: Icons.receipt_long_outlined,
            title: 'Service fee refund',
            subtitle: '04 Sep, 08:10 · CM-401-T18 cancelled',
            amount: '+15,600',
            color: AppColors.statusLive,
          ),
          _TransactionRow(
            icon: Icons.arrow_downward,
            title: 'Payment · CM-388-K07',
            subtitle: '02 Sep, 16:44 · M-Pesa · Released',
            amount: '−652,800',
            color: AppColors.textPrimary,
            isLast: true,
          ),
        ],
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
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.lightBlue),
        ),
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
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
            child: Icon(icon, size: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
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

  static const _methods = [
    'M-Pesa',
    'Airtel Money',
    'Tigo Pesa',
    'Bank transfer',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final method in _methods)
            ListTile(
              title: Text(method),
              trailing: method == current
                  ? const Icon(Icons.check, color: AppColors.ctaBlue)
                  : null,
              onTap: () => Navigator.of(context).pop(method),
            ),
        ],
      ),
    );
  }
}
