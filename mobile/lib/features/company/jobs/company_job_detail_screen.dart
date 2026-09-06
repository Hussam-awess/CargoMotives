import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../jobs/data/bid_repository.dart';
import '../../jobs/data/company_job_repository.dart';
import '../../jobs/data/job_repository.dart';

/// Company's Job Detail + Place Bid (AppFlow §2.4): "Tap a job -> details
/// -> Place Bid (price, ETA, note) -> quota check (shows remaining bids/
/// reset time if close to the limit) -> submit."
class CompanyJobDetailScreen extends StatefulWidget {
  CompanyJobDetailScreen({
    super.key,
    required this.jobId,
    CompanyJobRepository? jobRepository,
    BidRepository? bidRepository,
  }) : jobRepository = jobRepository ?? CompanyJobRepository(),
       bidRepository = bidRepository ?? BidRepository();

  final int jobId;
  final CompanyJobRepository jobRepository;
  final BidRepository bidRepository;

  @override
  State<CompanyJobDetailScreen> createState() => _CompanyJobDetailScreenState();
}

class _CompanyJobDetailScreenState extends State<CompanyJobDetailScreen> {
  Job? _job;
  int? _quotaRemaining;
  bool _isLoading = true;
  String? _loadError;

  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;
  Bid? _placedBid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final job = await widget.jobRepository.show(widget.jobId);
      final remaining = await widget.bidRepository.companyQuotaRemaining();
      if (!mounted) return;
      setState(() {
        _job = job;
        _quotaRemaining = remaining;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load this job.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _placeBid() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _submitError = 'Enter a valid price.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final bid = await widget.bidRepository.place(
        jobId: widget.jobId,
        price: price,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _placedBid = bid;
        _quotaRemaining = (_quotaRemaining ?? 1) - 1;
      });
    } on ApiException catch (e) {
      final secondsUntilSlotFrees = e.body?['seconds_until_slot_frees'];
      setState(() {
        _submitError = secondsUntilSlotFrees != null
            ? 'Bid limit reached. Try again in ${(secondsUntilSlotFrees as num) ~/ 60} min.'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job detail')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_job!.containerType} · ${_job!.containerSize}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('Pickup: ${_job!.pickupAddress}'),
                          Text('Drop-off: ${_job!.dropoffAddress}'),
                          if (_job!.approxWeightTons != null) Text('Approx. weight: ${_job!.approxWeightTons} tons'),
                          if (_job!.cargoDescription != null) Text(_job!.cargoDescription!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_job!.isOpen)
                    const Text('This job is no longer open for bidding.', style: TextStyle(color: Color(0xFF6B7280)))
                  else if (_placedBid != null)
                    Text('Bid placed: TZS ${_placedBid!.price.toStringAsFixed(0)} — pending review.', style: const TextStyle(fontWeight: FontWeight.w600))
                  else ...[
                    Text('Place a bid', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_quotaRemaining != null)
                      Text('$_quotaRemaining bid(s) remaining', style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (TZS)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(labelText: 'Note (optional)'),
                      maxLines: 2,
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(_submitError!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: (_isSubmitting || _quotaRemaining == 0) ? null : _placeBid,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Place bid'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
