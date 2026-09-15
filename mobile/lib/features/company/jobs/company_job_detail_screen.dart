import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/job_location_channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/data/bid_repository.dart';
import '../../jobs/data/company_job_repository.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/gps_status_card.dart';
import '../../jobs/job_geo.dart';
import '../../jobs/job_status.dart';
import '../../jobs/live_gps_tracking_screen.dart';
import '../../jobs/messages_screen.dart';
import 'assign_job_screen.dart';
import 'data/job_assignment_repository.dart';

/// Company's Job Detail + Place Bid (AppFlow §2.4): "Tap a job -> details
/// -> Place Bid (price, ETA, note) -> quota check (shows remaining bids/
/// reset time if close to the limit) -> submit." Restyled to the mockup's
/// two states — "Submit a Bid" (open, not yet assigned) and "Active Job"
/// (assigned to this company). Note: a company never sees competitors'
/// bid prices (BidController::index() is Customer-only, to keep the
/// bidding sealed) — only its own bid count, unlike the mockup's "5 ·
/// lowest 720,000" line.
class CompanyJobDetailScreen extends StatefulWidget {
  CompanyJobDetailScreen({
    super.key,
    required this.jobId,
    CompanyJobRepository? jobRepository,
    BidRepository? bidRepository,
    JobAssignmentRepository? assignmentRepository,
    JobLocationChannel? locationChannel,
  }) : jobRepository = jobRepository ?? CompanyJobRepository(),
       bidRepository = bidRepository ?? BidRepository(),
       assignmentRepository = assignmentRepository ?? JobAssignmentRepository(),
       locationChannel = locationChannel ?? JobLocationChannel(jobId: jobId);

  final int jobId;
  final CompanyJobRepository jobRepository;
  final BidRepository bidRepository;
  final JobAssignmentRepository assignmentRepository;
  final JobLocationChannel locationChannel;

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
  GpsLocation? _liveLocation;
  List<Job> _returnLoadSuggestions = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.locationChannel
      ..onLocationUpdated = _handleLiveLocation
      ..connect();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    widget.locationChannel.dispose();
    super.dispose();
  }

  void _handleLiveLocation(Map<String, dynamic> locationJson) {
    if (!mounted) return;
    setState(() => _liveLocation = GpsLocation.fromJson(locationJson));
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
        _liveLocation = job.lastKnownLocation;
      });
      if (job.isAssignedToViewer &&
          (job.status == 'delivered' || job.status == 'completed')) {
        _loadReturnLoadSuggestions();
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load this job.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Featured-only on the backend (403 for anyone else) — a non-Featured
  /// company simply never sees this section, no separate "are you
  /// Featured" check needed here.
  Future<void> _loadReturnLoadSuggestions() async {
    try {
      final suggestions = await widget.jobRepository.returnLoadSuggestions(
        widget.jobId,
      );
      if (mounted) setState(() => _returnLoadSuggestions = suggestions);
    } catch (_) {
      // Silently skip — this is a bonus prompt, not core functionality.
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
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
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

  Future<void> _openAssignScreen() async {
    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssignJobScreen(
          job: _job!,
          assignmentRepository: widget.assignmentRepository,
        ),
      ),
    );
    if (assigned == true) _load();
  }

  Future<void> _viewDriverLink() async {
    try {
      final link = await widget.assignmentRepository.currentDriverLink(
        widget.jobId,
      );
      if (!mounted) return;
      if (link == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No driver link yet.')));
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Driver link'),
          content: SelectableText(link.url),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link.url));
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final isActiveJob =
        job != null && job.isAssignedToViewer && job.isAssignable;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isActiveJob
              ? 'Active Job'
              : (job != null && job.isOpen ? 'Submit a Bid' : 'Job Detail'),
        ),
        actions: [
          if (job?.isAssignedToViewer == true)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MessagesScreen(jobId: widget.jobId),
                ),
              ),
            ),
        ],
      ),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isActiveJob)
                    _ActiveJobCard(job: job, liveLocation: _liveLocation)
                  else
                    _JobInfoCard(job: job!),
                  const SizedBox(height: 16),
                  if (job.isAssignable && job.isAssignedToViewer) ...[
                    const _SectionLabel('Assignment'),
                    const SizedBox(height: 8),
                    _AssignmentCard(
                      job: job,
                      onAssign: _openAssignScreen,
                      onViewDriverLink: job.assignedTruckRegistration != null
                          ? _viewDriverLink
                          : null,
                    ),
                    if (job.assignedTruckRegistration != null) ...[
                      const SizedBox(height: 16),
                      GpsStatusCard(
                        trackingActive: job.gpsTrackingActive,
                        signalStatus: job.gpsSignalStatus,
                        location: _liveLocation,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveGpsTrackingScreen(job: job),
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 16),
                        label: const Text('View route on map'),
                      ),
                    ],
                    if (_returnLoadSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel('Find a return load'),
                      const SizedBox(height: 8),
                      for (final suggestion in _returnLoadSuggestions)
                        _ReturnLoadTile(
                          job: suggestion,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CompanyJobDetailScreen(jobId: suggestion.id),
                            ),
                          ),
                        ),
                    ],
                  ] else if (!job.isOpen)
                    Text(
                      'This job is no longer open for bidding.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else if (_placedBid != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.infoTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bid placed: TZS ${_placedBid!.price.toStringAsFixed(0)} — pending review.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ctaBluePressed,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      'Your price',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLabel,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.ctaBlue,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'TZS',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              key: const Key('bidPriceField'),
                              controller: _priceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Barlow Condensed',
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_quotaRemaining != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$_quotaRemaining bid(s) remaining',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Note to customer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLabel,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(hintText: 'Optional'),
                      maxLines: 2,
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: (_isSubmitting || _quotaRemaining == 0)
                          ? null
                          : _placeBid,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('SUBMIT BID'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textLabel,
        letterSpacing: 0.7,
      ),
    );
  }
}

/// The bidding-stage summary — mockup's light "Submit a Bid" header card.
class _JobInfoCard extends StatelessWidget {
  const _JobInfoCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final distance =
        (job.pickupLat != null &&
            job.pickupLng != null &&
            job.dropoffLat != null &&
            job.dropoffLng != null)
        ? kmBetween(
            job.pickupLat!,
            job.pickupLng!,
            job.dropoffLat!,
            job.dropoffLng!,
          )
        : null;

    final rows = <(String, String)>[
      if (job.budgetPrice != null)
        (
          'Customer\'s budget',
          '${job.currency} ${job.budgetPrice!.toStringAsFixed(0)}',
        ),
      (
        'Pickup window',
        DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart),
      ),
      if (job.bidsCount != null) ('Current bids', '${job.bidsCount}'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            color: AppColors.surfaceSubtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CM-${job.id.toString().padLeft(4, '0')}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${job.pickupAddress} → ${job.dropoffAddress}',
                  style: TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${job.containerType} · ${job.containerSize}'
                  '${job.approxWeightTons != null ? ' · ${job.approxWeightTons!.toStringAsFixed(0)} t' : ''}'
                  '${distance != null ? ' · ${distance.toStringAsFixed(0)} km' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: i == rows.length - 1
                  ? null
                  : BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.background),
                      ),
                    ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].$1,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    rows[i].$2,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          if (job.cargoDescription != null && job.cargoDescription!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Text(
                job.cargoDescription!,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The assigned-and-in-progress state — mockup's navy "Active Job" hero
/// card. "You earn" is the company's own accepted bid price (agreedPrice);
/// "Remaining" is a real great-circle distance from the truck's live
/// position to drop-off, not a fabricated ETA.
class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.liveLocation});

  final Job job;
  final GpsLocation? liveLocation;

  @override
  Widget build(BuildContext context) {
    final remaining =
        (liveLocation != null &&
            job.dropoffLat != null &&
            job.dropoffLng != null)
        ? kmBetween(
            liveLocation!.lat,
            liveLocation!.lng,
            job.dropoffLat!,
            job.dropoffLng!,
          )
        : null;
    final customer = job.customerCompanyName ?? job.customerName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandChip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CM-${job.id.toString().padLeft(4, '0')}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.lightBlue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.lightBlue,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      jobStatusLabel(job.status),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${job.pickupAddress} → ${job.dropoffAddress}',
            style: const TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (customer != null)
            Text(
              customer,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.lightBlue,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.13)),
                ),
              ),
              child: Row(
                children: [
                  if (job.agreedPrice != null)
                    _SummaryStat(
                      label: 'You earn',
                      value: job.agreedPrice!.toStringAsFixed(0),
                    ),
                  if (remaining != null) ...[
                    const SizedBox(width: 20),
                    _SummaryStat(
                      label: 'Remaining',
                      value: '${remaining.toStringAsFixed(0)} km',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

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

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.job,
    required this.onAssign,
    required this.onViewDriverLink,
  });

  final Job job;
  final VoidCallback onAssign;
  final VoidCallback? onViewDriverLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (job.assignedTruckRegistration != null)
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.infoTint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 17,
                    color: AppColors.ctaBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.assignedTruckRegistration!,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        job.assignedDriverName ?? '',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              'No truck/driver assigned yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onAssign,
            child: Text(
              job.assignedTruckRegistration != null
                  ? 'Reassign truck & driver'
                  : 'Assign truck & driver',
            ),
          ),
          if (onViewDriverLink != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onViewDriverLink,
              child: const Text('View driver link'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReturnLoadTile extends StatelessWidget {
  const _ReturnLoadTile({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${job.pickupAddress} → ${job.dropoffAddress}',
                      style: TextStyle(
                        fontFamily: 'Barlow Condensed',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${job.containerType} · ${job.containerSize}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
