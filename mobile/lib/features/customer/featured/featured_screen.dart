import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/phone_input.dart';
import '../data/featured_repository.dart';

/// Plus's own premium palette — deliberately distinct from the app's
/// navy/steel-blue system (a "gold tier" reads as premium precisely
/// because it doesn't reuse the everyday CTA color).
const _plusInk = Color(0xFF1F1B12);
const _plusGold = Color(0xFFE8C34A);
const _plusTint = Color(0xFFFCF8EE);
const _plusTintBorder = Color(0xFFE2D3A8);
const _plusTextDark = Color(0xFF5C4409);
const _plusTextMuted = Color(0xFF8A6410);

/// Upgrade to Featured (Customer) — AppFlow §3.6: "explains the [daily
/// post quota] → pay via mobile money → unlocks immediately."
/// JobPostQuotaService already reads users.is_featured — Plus now removes
/// the post quota outright rather than just raising it; this screen is
/// only the purchase flow.
class CustomerFeaturedScreen extends StatefulWidget {
  CustomerFeaturedScreen({super.key, CustomerFeaturedRepository? repository})
    : repository = repository ?? CustomerFeaturedRepository();

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
      if (mounted) {
        setState(() => _loadError = 'Could not load Featured status.');
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check your phone to approve the payment.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _PlusHero(status: _status!),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: _status!.isFeatured
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _plusTint,
                                border: Border.all(color: _plusTintBorder),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: _plusTextDark,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _status!.featuredUntil != null
                                          ? 'You\'re on Plus until ${_status!.featuredUntil!.toLocal().toString().split(' ').first}.'
                                          : 'You\'re on Plus.',
                                      style: const TextStyle(
                                        color: _plusTextDark,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const _CustomerBenefitsList(),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'TZS',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _status!.price.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontFamily: 'Barlow Condensed',
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '/ ${_status!.durationDays} days',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const _CustomerBenefitsList(),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _openPurchaseForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _plusInk,
                                foregroundColor: _plusGold,
                                side: const BorderSide(
                                  color: Color(0xFFC9A227),
                                ),
                              ),
                              child: Text(
                                'GET PLUS · TZS ${_status!.price.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _PlusHero extends StatelessWidget {
  const _PlusHero({required this.status});

  final CustomerFeaturedStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      color: _plusInk,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: _plusGold,
                    size: 18,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _plusGold.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _plusGold,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.bolt, color: _plusInk, size: 22),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CARGO MOTIVES',
                      style: TextStyle(
                        fontFamily: 'Barlow Condensed',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _plusGold,
                        letterSpacing: 0.6,
                        height: 1,
                      ),
                    ),
                    Text(
                      'PLUS',
                      style: TextStyle(
                        fontFamily: 'Barlow Condensed',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 4,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Post more, and never be blocked by the daily shipment cap.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFFC4B896),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The benefit list (Phase 3a) — shown both to a prospective subscriber
/// deciding whether to buy Plus, and to an existing subscriber revisiting
/// this screen to see what they're paying for.
class _CustomerBenefitsList extends StatelessWidget {
  const _CustomerBenefitsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WHAT YOU GET',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.all_inclusive,
          title: 'Unlimited job posting',
          body: 'No daily cap — post as many new shipments as you need.',
        ),
        const SizedBox(height: 10),
        const _BenefitCard(
          icon: Icons.trending_up,
          title: 'Priority visibility for your jobs',
          body:
              'Your posted jobs are shown to transporters ahead of standard customers\' jobs, so you get bids sooner.',
        ),
        const SizedBox(height: 10),
        const _BenefitCard(
          icon: Icons.swap_horiz,
          title: 'One-tap return shipments',
          body:
              'Once a shipment is completed, post the return leg in one tap — the route comes pre-filled, reversed.',
        ),
        const SizedBox(height: 10),
        const _BenefitCard(
          icon: Icons.place_outlined,
          title: 'Unlimited saved addresses',
          body:
              'Standard accounts can save up to 3 addresses for quick re-use — Plus removes the limit.',
        ),
        const SizedBox(height: 10),
        const _BenefitCard(
          icon: Icons.support_agent,
          title: 'Priority support',
          body:
              'Your Help & Support requests are flagged for faster handling by our team.',
        ),
      ],
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _plusTint,
        border: Border.all(color: _plusTintBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _plusInk,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: _plusGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _plusTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _plusTextMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your mobile money phone number.');
      return;
    }
    if (!isValidTanzanianPhone(phone)) {
      setState(
        () => _error =
            'Enter a valid 10-digit phone number starting with 0 (e.g. 0712345678).',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final payment = await widget.repository.purchase(
        provider: _provider,
        phoneNumber: _phoneController.text.trim(),
      );
      if (!mounted) return;
      if (payment.isPending) {
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _error = 'The payment could not be started. Please try again.',
        );
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
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay via Mobile Money',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: const [
              DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
              DropdownMenuItem(value: 'tigopesa', child: Text('Tigo Pesa')),
              DropdownMenuItem(
                value: 'airtelmoney',
                child: Text('Airtel Money'),
              ),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _provider = value!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Mobile money phone number',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: tanzanianPhoneInputFormatters,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Pay now'),
          ),
        ],
      ),
    );
  }
}
