import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/realtime/job_bid_channel.dart';
import '../../core/realtime/job_location_channel.dart';
import '../../core/theme/app_theme.dart';
import 'data/bid_repository.dart';
import 'data/job_repository.dart';
import 'gps_status_card.dart';

/// Job Detail (Customer) — AppFlow §3.3/§3.4: the job summary, its bid
/// list (Featured pinned first, live-updated per TRD §4 while this screen
/// is open), Accept Bid, and (Phase 6) a live GPS status card once a
/// truck's assigned.
class JobDetailScreen extends StatefulWidget {
  JobDetailScreen({
    super.key,
    required this.jobId,
    JobRepository? jobRepository,
    BidRepository? bidRepository,
    JobBidChannel? bidChannel,
    JobLocationChannel? locationChannel,
  }) : jobRepository = jobRepository ?? JobRepository(),
       bidRepository = bidRepository ?? BidRepository(),
       bidChannel = bidChannel ?? JobBidChannel(jobId: jobId),
       locationChannel = locationChannel ?? JobLocationChannel(jobId: jobId);

  final int jobId;
  final JobRepository jobRepository;
  final BidRepository bidRepository;
  final JobBidChannel bidChannel;
  final JobLocationChannel locationChannel;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  List<Bid> _bids = [];
  bool _isLoading = true;
  String? _loadError;
  int? _acceptingBidId;
  bool _isConfirmingDelivery = false;
  GpsLocation? _liveLocation;

  @override
  void initState() {
    super.initState();
    _load();
    widget.bidChannel
      ..onBidPlaced = _handleLiveBid
      ..connect();
    widget.locationChannel
      ..onLocationUpdated = _handleLiveLocation
      ..connect();
  }

  @override
  void dispose() {
    widget.bidChannel.dispose();
    widget.locationChannel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final job = await widget.jobRepository.show(widget.jobId);
      final bids = await widget.bidRepository.forJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = job;
        _bids = bids;
        // A fresh REST fetch is the source of truth for where things
        // stand right now — a stale live update from before this reload
        // (or from a job that's no longer trackable) must not linger.
        _liveLocation = job.lastKnownLocation;
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load this job.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleLiveBid(Map<String, dynamic> bidJson) {
    if (!mounted) return;
    final bid = Bid.fromJson(bidJson);
    setState(() {
      // Replace if we already have it (e.g. our own optimistic refresh
      // beat the socket), otherwise prepend — Featured/priority bids still
      // get re-sorted to the top below.
      _bids = [bid, ..._bids.where((b) => b.id != bid.id)]..sort((a, b) => (b.isPriority ? 1 : 0) - (a.isPriority ? 1 : 0));
    });
  }

  void _handleLiveLocation(Map<String, dynamic> locationJson) {
    if (!mounted) return;
    setState(() => _liveLocation = GpsLocation.fromJson(locationJson));
  }

  Future<void> _accept(Bid bid) async {
    setState(() => _acceptingBidId = bid.id);
    try {
      await widget.bidRepository.accept(bid.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acceptingBidId = null);
    }
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isConfirmingDelivery = true);
    try {
      await widget.jobRepository.confirmDelivery(widget.jobId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isConfirmingDelivery = false);
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _JobSummaryCard(job: _job!),
                  const SizedBox(height: 16),
                  if (_job!.isAssignable) ...[
                    GpsStatusCard(
                      trackingActive: _job!.gpsTrackingActive,
                      signalStatus: _job!.gpsSignalStatus,
                      location: _liveLocation,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_job!.proofOfDelivery != null) ...[
                    _ProofOfDeliveryCard(
                      proofOfDelivery: _job!.proofOfDelivery!,
                      canConfirm: _job!.isAwaitingDeliveryConfirmation,
                      isConfirming: _isConfirmingDelivery,
                      onConfirm: _confirmDelivery,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Bids (${_bids.length})', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_bids.isEmpty) const Text('No bids yet.', style: TextStyle(color: Color(0xFF6B7280))),
                  for (final bid in _bids) ...[
                    _BidCard(
                      bid: bid,
                      canAccept: _job!.isOpen,
                      isAccepting: _acceptingBidId == bid.id,
                      onAccept: () => _accept(bid),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${job.containerType} · ${job.containerSize}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Pickup: ${job.pickupAddress}'),
            Text('Drop-off: ${job.dropoffAddress}'),
            const SizedBox(height: 8),
            Text('Status: ${job.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (job.agreedPrice != null) Text('Agreed price: ${job.currency} ${job.agreedPrice!.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }
}

/// UI/UX Brief §5.1: company name + verification checkmark, truck count,
/// rating — the trust line — plus a calm GPS status dot/label, price large
/// and clear, a simple Accept button. Featured/priority bids get a small
/// text label, not a heavy visual treatment (per the brief's "GPS is a
/// badge, not a gate" / "one clean design system" direction).
class _BidCard extends StatelessWidget {
  const _BidCard({required this.bid, required this.canAccept, required this.isAccepting, required this.onAccept});

  final Bid bid;
  final bool canAccept;
  final bool isAccepting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final company = bid.company;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bid.isPriority) ...[
              const Text('Featured', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: company.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (company.verified) const TextSpan(text: '  ✓', style: TextStyle(color: AppColors.statusLive)),
                      ],
                    ),
                  ),
                ),
                Text(
                  'TZS ${bid.price.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${company.truckCount} verified trucks', style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: company.gpsAvailable ? AppColors.statusLive : AppColors.statusIdle,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  company.gpsAvailable ? 'Live GPS Available' : 'GPS Tracking Not Available',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  company.rating != null ? '⭐ ${company.rating!.toStringAsFixed(1)}' : 'New',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            if (bid.note != null && bid.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bid.note!),
            ],
            if (canAccept && bid.status == 'pending') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isAccepting ? null : onAccept,
                child: isAccepting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Accept'),
              ),
            ] else if (bid.status != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(bid.status, style: const TextStyle(color: Color(0xFF6B7280))),
              ),
          ],
        ),
      ),
    );
  }
}

/// AppFlow §3.5: the driver's submitted proof — photos, optional recipient
/// name/notes — plus Confirm Receipt while the job is still 'delivered'
/// (not yet 'completed'). Once confirmed, this just shows the same
/// information read-only (confirmedByCustomerAt is set).
class _ProofOfDeliveryCard extends StatelessWidget {
  const _ProofOfDeliveryCard({
    required this.proofOfDelivery,
    required this.canConfirm,
    required this.isConfirming,
    required this.onConfirm,
  });

  final ProofOfDelivery proofOfDelivery;
  final bool canConfirm;
  final bool isConfirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proof of delivery', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: proofOfDelivery.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    proofOfDelivery.photoUrls[index],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9E9E9E)),
                    ),
                  ),
                ),
              ),
            ),
            if (proofOfDelivery.recipientName != null) ...[
              const SizedBox(height: 12),
              Text('Received by: ${proofOfDelivery.recipientName}'),
            ],
            if (proofOfDelivery.notes != null && proofOfDelivery.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(proofOfDelivery.notes!),
            ],
            if (canConfirm) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isConfirming ? null : onConfirm,
                child: isConfirming
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Receipt'),
              ),
            ] else if (proofOfDelivery.confirmedByCustomerAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Confirmed', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
