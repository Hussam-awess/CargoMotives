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

/// Upgrade to Featured (Company) — AppFlow §2.7: "explains the
/// [bid quota], priority placement, route filter, and return-load
/// suggestions → pay via mobile money → unlocks immediately." The tools
/// themselves are automatic once is_featured flips (bid quota/priority:
/// BidQuotaService/BidController — Plus now removes the bid quota
/// outright rather than just raising it; route filter/return-load: Phase
/// 8's other endpoints) — this screen is only the purchase flow and the
/// preferred-routes setting. The fleet map used to be listed here too,
/// but it's no longer Plus-gated (Plus Polish Batch Phase 1) — every
/// transporter can see their own fleet's live positions for free.
class CompanyFeaturedScreen extends StatefulWidget {
  CompanyFeaturedScreen({super.key, CompanyFeaturedRepository? repository})
    : repository = repository ?? CompanyFeaturedRepository();

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

  Future<void> _editPreferredRoutes() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreferredRoutesScreen(
          repository: widget.repository,
          initialRoutes: _status!.preferredRoutes,
          initialHomeRegion: _status!.homeRegion,
        ),
      ),
    );
    if (saved == true) _load();
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
                            const SizedBox(height: 20),
                            Text(
                              'HOME REGION',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLabel,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _status!.homeRegion?.isNotEmpty == true
                                  ? _status!.homeRegion!
                                  : 'Not set — return-load matches near where you drop off, without preferring any direction back home.',
                              style: TextStyle(
                                color: _status!.homeRegion?.isNotEmpty == true
                                    ? null
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'PREFERRED ROUTES',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textLabel,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_status!.preferredRoutes.isEmpty)
                              Text(
                                'No preferred routes set.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < _status!.preferredRoutes.length;
                                      i++
                                    )
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 13,
                                          vertical: 12,
                                        ),
                                        decoration:
                                            i ==
                                                _status!
                                                        .preferredRoutes
                                                        .length -
                                                    1
                                            ? null
                                            : BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: AppColors.background,
                                                  ),
                                                ),
                                              ),
                                        child: Text(
                                          '${_status!.preferredRoutes[i].origin} → ${_status!.preferredRoutes[i].destination}',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _editPreferredRoutes,
                              child: const Text('Edit preferred routes'),
                            ),
                            const SizedBox(height: 24),
                            const _CompanyBenefitsList(),
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
                            const _CompanyBenefitsList(),
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

  final CompanyFeaturedStatus status;

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
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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
              'Bid more, win more, and get seen first on every job.',
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
class _CompanyBenefitsList extends StatelessWidget {
  const _CompanyBenefitsList();

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
          icon: Icons.gavel_outlined,
          title: 'Unlimited bidding',
          body: 'No daily cap — bid on as many jobs as you want.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.push_pin_outlined,
          title: 'Priority placement on your bids',
          body: 'Your bids are pinned above the rest on every job you bid on.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.route_outlined,
          title: 'Filter Open Jobs to your routes',
          body:
              'Save the lanes you run and filter the job board down to just those.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.replay_outlined,
          title: 'Return-load suggestions',
          body:
              'After a delivery, see other open jobs near where you just dropped off.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Plus badge on your bids',
          body:
              'Customers see a Cargo Motives Plus badge next to your company name on every bid you place.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.bolt_outlined,
          title: 'Early visibility on new jobs',
          body:
              'See newly posted jobs immediately — standard accounts see them a couple of minutes later.',
        ),
        const SizedBox(height: 8),
        const _BenefitCard(
          icon: Icons.verified_user_outlined,
          title: 'Customer trust signal',
          body:
              "See a customer's completed-shipment count on the platform before you bid.",
        ),
        const SizedBox(height: 8),
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

/// A simple add/remove list editor for preferred_routes (AppFlow §2.7) —
/// plain text fields, no map picker, matching the same lat/lng-as-text
/// scope decision Post a Job made back in Phase 4.
class PreferredRoutesScreen extends StatefulWidget {
  const PreferredRoutesScreen({
    super.key,
    required this.repository,
    required this.initialRoutes,
    this.initialHomeRegion,
  });

  final CompanyFeaturedRepository repository;
  final List<PreferredRoute> initialRoutes;
  final String? initialHomeRegion;

  @override
  State<PreferredRoutesScreen> createState() => _PreferredRoutesScreenState();
}

class _PreferredRoutesScreenState extends State<PreferredRoutesScreen> {
  late List<PreferredRoute> _routes;
  late final _homeRegionController = TextEditingController(
    text: widget.initialHomeRegion ?? '',
  );
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _routes = List.of(widget.initialRoutes);
  }

  @override
  void dispose() {
    _homeRegionController.dispose();
    super.dispose();
  }

  Future<void> _addRoute() async {
    final added = await showDialog<PreferredRoute>(
      context: context,
      builder: (context) => const _AddRouteDialog(),
    );
    if (added != null) setState(() => _routes.add(added));
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final homeRegion = _homeRegionController.text.trim();
      await widget.repository.updatePreferredRoutes(
        _routes,
        homeRegion: homeRegion.isEmpty ? null : homeRegion,
      );
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
            Text(
              'HOME REGION',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _homeRegionController,
              decoration: const InputDecoration(
                hintText: 'e.g. Dar es Salaam',
                helperText:
                    "Where you're based — return-load suggestions after a delivery prefer jobs heading back here.",
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PREFERRED ROUTES',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textLabel,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _routes.isEmpty
                  ? Center(
                      child: Text(
                        'No preferred routes yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _routes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final route = _routes[index];

                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              '${route.origin} → ${route.destination}',
                            ),
                            trailing: IconButton(
                              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  setState(() => _routes.removeAt(index)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _addRoute,
              child: const Text('Add route'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
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
          TextField(
            controller: _originController,
            decoration: const InputDecoration(labelText: 'Origin'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinationController,
            decoration: const InputDecoration(labelText: 'Destination'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_originController.text.trim().isEmpty ||
                _destinationController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              PreferredRoute(
                origin: _originController.text.trim(),
                destination: _destinationController.text.trim(),
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
