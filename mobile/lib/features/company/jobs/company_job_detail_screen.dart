import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/job_location_channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../jobs/data/bid_repository.dart';
import '../../jobs/data/company_job_repository.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/gps_status_card.dart';
import '../../jobs/job_geo.dart';
import '../../jobs/job_route_map_screen.dart';
import '../../jobs/job_status.dart';
import '../../jobs/live_gps_tracking_screen.dart';
import '../../jobs/messages_screen.dart';
import '../../profiles/customer_profile_screen.dart';
import '../../reviews/rate_job_card.dart';
import '../../reviews/rate_job_screen.dart';
import '../data/follow_repository.dart';
import 'assign_job_screen.dart';
import 'data/job_assignment_repository.dart';
import 'end_job_screen.dart';

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
    FollowRepository? followRepository,
  }) : jobRepository = jobRepository ?? CompanyJobRepository(),
       bidRepository = bidRepository ?? BidRepository(),
       assignmentRepository = assignmentRepository ?? JobAssignmentRepository(),
       locationChannel = locationChannel ?? JobLocationChannel(jobId: jobId),
       followRepository = followRepository ?? FollowRepository();

  final int jobId;
  final CompanyJobRepository jobRepository;
  final BidRepository bidRepository;
  final JobAssignmentRepository assignmentRepository;
  final JobLocationChannel locationChannel;
  final FollowRepository followRepository;

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
  final _trucksOfferedController = TextEditingController(text: '1');
  bool _isSubmitting = false;
  String? _submitError;
  Bid? _placedBid;
  GpsLocation? _liveLocation;
  List<Job> _returnLoadSuggestions = [];
  int? _claimingReturnLoadId;

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
    _trucksOfferedController.dispose();
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

  /// "Doesn't need to be bid": claims a matched return load at its own
  /// posted price, no price entry. The customer still explicitly confirms
  /// it (BidController::accept(), unchanged) — this only skips the
  /// competitive-pricing step for the transporter's side.
  Future<void> _claimReturnLoad(Job suggestion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim this return load?'),
        content: Text(
          "You'll take ${suggestion.pickupAddress} → ${suggestion.dropoffAddress} at its posted price of "
          "${suggestion.currency} ${suggestion.budgetPrice?.toStringAsFixed(0)}. No bidding — the customer just confirms to assign it to you.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _claimingReturnLoadId = suggestion.id);
    try {
      await widget.jobRepository.claimReturnLoad(
        suggestion.id,
        fromJobId: widget.jobId,
      );
      if (!mounted) return;
      setState(
        () => _returnLoadSuggestions.removeWhere((j) => j.id == suggestion.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Claimed — the customer will confirm to assign it to you.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _claimingReturnLoadId = null);
    }
  }

  Future<void> _placeBid() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      setState(() => _submitError = 'Enter a valid price.');
      return;
    }

    final job = _job!;
    int? trucksOffered;
    if (job.trucksNeeded > 1) {
      trucksOffered = int.tryParse(_trucksOfferedController.text.trim());
      final remaining = job.remainingTrucksNeeded ?? job.trucksNeeded;
      if (trucksOffered == null ||
          trucksOffered < 1 ||
          trucksOffered > remaining) {
        setState(
          () => _submitError =
              'Enter how many trucks you can offer (1–$remaining).',
        );
        return;
      }
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
        trucksOffered: trucksOffered,
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
    final job = _job!;
    // Multi-Company Split Awards epic: CompanyJobController::show() scopes
    // `awards` to the viewer's own company only, so a non-empty list here
    // IS this company's own award — exclude ITS roster, not the job's
    // (which could include other companies' trucks the backend never even
    // shows this company).
    final excludedTruckIds = job.awards.isNotEmpty
        ? job.awards.first.assignedFleet.map((t) => t.truckId).toSet()
        : job.assignedFleet.map((t) => t.truckId).toSet();
    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssignJobScreen(
          job: job,
          excludedTruckIds: excludedTruckIds,
          assignmentRepository: widget.assignmentRepository,
        ),
      ),
    );
    if (assigned == true) _load();
  }

  Future<void> _openRateJob() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RateJobScreen(
          jobId: widget.jobId,
          direction: RatingDirection.transporterRatingCustomer,
        ),
      ),
    );
    if (submitted == true) _load();
  }

  Future<void> _viewDriverLink({int? truckId}) async {
    try {
      final link = await widget.assignmentRepository.currentDriverLink(
        widget.jobId,
        truckId: truckId,
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Whether "End job" is worth offering — anything before 'delivered'
  /// (an already-delivered/completed/cancelled job has nothing left to
  /// manually end).
  static const _endableStatuses = {'assigned', 'en_route_pickup', 'picked_up', 'in_transit'};

  Future<void> _openEndJob({int? truckId}) async {
    final result = await Navigator.of(context).push<Job>(
      MaterialPageRoute(
        builder: (_) => EndJobScreen(
          jobId: widget.jobId,
          truckId: truckId,
          repository: widget.assignmentRepository,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _job = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Job marked as delivered.')));
    }
  }

  /// Opens the drop-off permit (job-level, always an absolute
  /// already-signed URL from DocumentStorage — unlike _openLegal-style
  /// links elsewhere, never prefixed with AppConfig.apiBaseUrl).
  Future<void> _openDropoffPermit() async {
    final uri = Uri.parse(_job!.dropoffPermitUrl!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.couldNotOpenUri(uri.toString()),
          ),
        ),
      );
    }
  }

  /// A one-way note to the driver(s) currently on this job/award — see
  /// JobAssignmentController::updateInstructions()'s own docblock for why
  /// there's no reply channel. Prefilled with whatever's already set so
  /// editing doesn't start from a blank field.
  Future<void> _openEditInstructions(String? existing) async {
    final instructions = await showDialog<String>(
      context: context,
      builder: (_) => _EditInstructionsDialog(initialValue: existing),
    );
    if (instructions == null || !mounted) return;

    try {
      final updated = await widget.assignmentRepository.updateInstructions(
        widget.jobId,
        instructions,
      );
      if (mounted) setState(() => _job = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openMessages(BuildContext context, Job job) {
    final customerId = job.customerId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          jobId: widget.jobId,
          counterpartyName: job.customerCompanyName ?? job.customerName,
          onOpenCounterpartyProfile: customerId != null
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerProfileScreen(customerId: customerId),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    // Multi-Company Split Awards epic: CompanyJobController::show() scopes
    // `awards` to the viewer's own company only, so a non-empty list here
    // IS this company's own award, if it has one. A job with an award can
    // legitimately still be job.status == 'open' (other companies' slices
    // still uncovered), so the OR-branch is needed — the legacy
    // isAssignedToViewer/isAssignable check alone would never catch it.
    final award = job != null && job.awards.isNotEmpty
        ? job.awards.first
        : null;
    final isActiveJob =
        job != null &&
        ((job.isAssignedToViewer && job.isAssignable) || award != null);

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
              onPressed: () => _openMessages(context, job!),
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
                    _ActiveJobCard(
                      job: job,
                      award: award,
                      liveLocation: _liveLocation,
                      followRepository: widget.followRepository,
                    )
                  else
                    _JobInfoCard(
                      job: job!,
                      followRepository: widget.followRepository,
                    ),
                  if (job.reviewable == true) ...[
                    const SizedBox(height: 16),
                    RateJobCard(onTap: _openRateJob),
                  ],
                  if (isActiveJob) ...[
                    const SizedBox(height: 16),
                    _DropoffPermitCard(
                      dropoffPermitUrl: job.dropoffPermitUrl,
                      onOpen: _openDropoffPermit,
                    ),
                    const SizedBox(height: 16),
                    _DriverInstructionsCard(
                      instructions: award?.driverInstructions ?? job.driverInstructions,
                      onEdit: () => _openEditInstructions(
                        award?.driverInstructions ?? job.driverInstructions,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (award != null) ...[
                    const _SectionLabel('Your fleet on this job'),
                    const SizedBox(height: 8),
                    _AwardAssignmentCard(
                      award: award,
                      onAssign: _openAssignScreen,
                      onViewDriverLink: _viewDriverLink,
                    ),
                    if (award.assignedFleet.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GpsStatusCard(
                        trackingActive: award.gpsTrackingActive,
                        signalStatus: award.gpsSignalStatus,
                        location: _liveLocation,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveGpsTrackingScreen(
                              job: job.forAwardMapView(award),
                              // Re-applies the same award's own (freshly
                              // fetched) slice each tick, not the whole
                              // job — award.id, not the closed-over award
                              // itself, so this reflects that award's own
                              // updated status/location, not a stale copy.
                              onRefresh: () async {
                                final fresh = await widget.jobRepository.show(
                                  job.id,
                                );
                                return fresh.forAwardMapView(
                                  fresh.awards.firstWhere(
                                    (a) => a.id == award.id,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 16),
                        label: const Text('View route on map'),
                      ),
                      if (_endableStatuses.contains(award.status)) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          // No truck_id: the backend resolves the award's
                          // own lead truck automatically. Gated on the
                          // job-level (never per-award) drop-off permit —
                          // see _DropoffPermitCard above.
                          onPressed: job.dropoffPermitUrl != null
                              ? _openEndJob
                              : null,
                          icon: const Icon(Icons.task_alt, size: 16),
                          label: const Text('End job'),
                        ),
                      ],
                    ],
                  ] else if (job.isAssignable && job.isAssignedToViewer) ...[
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
                            builder: (_) => LiveGpsTrackingScreen(
                              job: job,
                              onRefresh: () =>
                                  widget.jobRepository.show(job.id),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 16),
                        label: const Text('View route on map'),
                      ),
                      if (_endableStatuses.contains(job.status)) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: job.dropoffPermitUrl != null
                              ? _openEndJob
                              : null,
                          icon: const Icon(Icons.task_alt, size: 16),
                          label: const Text('End job'),
                        ),
                      ],
                    ],
                  ] else if (!job.isOpen)
                    Text(
                      'This job is no longer open for bidding.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else if (job.biddingClosed == true)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bidding closed for this job before you placed a bid.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else if (job.isEligible == false)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'This job needs ${job.trucksNeeded} trucks. Your verified fleet doesn\'t meet that requirement yet — add more approved trucks to bid.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else if (_placedBid != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.infoTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Bid placed: ${job.currency} ${_placedBid!.price.toStringAsFixed(0)} — pending review.',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ctaBluePressed,
                        ),
                      ),
                    )
                  else ...[
                    // Multi-Company Split Awards epic: a bulk job's budget
                    // (shown above, in this same card's rows) is always
                    // per truck — called out again right at the bid form so
                    // a company can't mistake it for a lump sum covering
                    // every truck the job needs and under/overbid as a
                    // result.
                    if (job.trucksNeeded > 1 && job.budgetPrice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.infoTint,
                          border: Border.all(color: const Color(0xFFD6EBFF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.ctaBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The customer\'s budget of ${job.currency} ${job.budgetPrice!.toStringAsFixed(0)} is per truck, not the total for all ${job.trucksNeeded} trucks.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.ctaBluePressed,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                            job.currency,
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
                    if (job.budgetPrice != null) ...[
                      const SizedBox(height: 8),
                      _SuggestedPriceChip(
                        suggestedPrice: _suggestedBidPrice(job.budgetPrice!),
                        currency: job.currency,
                        onTap: () => setState(
                          () => _priceController.text = _suggestedBidPrice(
                            job.budgetPrice!,
                          ).toStringAsFixed(0),
                        ),
                      ),
                    ],
                    if (_quotaRemaining != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        // Cargo Motives Plus: BidQuotaService.remaining()
                        // returns -1 (never a real count) for a company
                        // with no bid limit at all.
                        _quotaRemaining == -1
                            ? 'Unlimited bids (Plus)'
                            : '$_quotaRemaining bid(s) remaining',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                    // Multi-Company Split Awards epic: only meaningful on a
                    // bulk job — an ordinary trucksNeeded=1 job's bid form
                    // never needs to think about this, and the backend
                    // defaults trucks_offered to 1 when it's omitted.
                    if (job.trucksNeeded > 1) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Trucks you can offer (up to ${job.remainingTrucksNeeded ?? job.trucksNeeded})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLabel,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextField(
                        key: const Key('trucksOfferedField'),
                        controller: _trucksOfferedController,
                        keyboardType: TextInputType.number,
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
                  // Shown regardless of which state the job's own bidding/
                  // assignment section above is in (a delivered/completed
                  // job never satisfies job.isAssignable, so this can't
                  // live inside that branch — it needs its own, unconditional
                  // slot at the end of the page).
                  if (_returnLoadSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('Find a return load'),
                    const SizedBox(height: 8),
                    for (final suggestion in _returnLoadSuggestions)
                      _ReturnLoadTile(
                        job: suggestion,
                        isClaiming: _claimingReturnLoadId == suggestion.id,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CompanyJobDetailScreen(jobId: suggestion.id),
                          ),
                        ),
                        onClaim: suggestion.budgetPrice != null
                            ? () => _claimReturnLoad(suggestion)
                            : null,
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// A starting point, not a rule — nudges a transporter toward a
/// competitive price close to (a shade under) the customer's stated
/// budget, rounded to a clean number rather than an odd decimal. Never
/// suggests more than the budget itself, since the whole point is to look
/// attractive against it, not to anchor a company toward overbidding.
double _suggestedBidPrice(double budget) => _roundToNiceIncrement(budget * 0.95);

/// Rounds to an increment scaled to the value's own magnitude, so a small
/// USD budget rounds to the nearest 5 while a large TZS one rounds to the
/// nearest 5,000 — one fixed increment would otherwise be either too
/// coarse or too fine depending on which currency a job happens to use.
double _roundToNiceIncrement(double value) {
  final increment = switch (value.abs()) {
    >= 100000 => 5000.0,
    >= 10000 => 500.0,
    >= 1000 => 50.0,
    >= 100 => 10.0,
    _ => 5.0,
  };
  return (value / increment).round() * increment;
}

class _SuggestedPriceChip extends StatelessWidget {
  const _SuggestedPriceChip({
    required this.suggestedPrice,
    required this.currency,
    required this.onTap,
  });

  final double suggestedPrice;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lightbulb_outline,
            size: 14,
            color: AppColors.ctaBlue,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Suggested: $currency ${suggestedPrice.toStringAsFixed(0)} · tap to use',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ctaBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

/// View-only drop-off permit status (job-level — customer-uploaded via
/// [JobController::submitDropoffPermit]). Purely informational here; the
/// real gate on ending the job is the disabled "End job" button
/// (CompanyJobDetailScreen's own onPressed check) plus the backend's own
/// hard block in submitProofOfDelivery().
class _DropoffPermitCard extends StatelessWidget {
  const _DropoffPermitCard({required this.dropoffPermitUrl, required this.onOpen});

  final String? dropoffPermitUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final attached = dropoffPermitUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              attached ? Icons.task_alt : Icons.hourglass_empty,
              color: attached ? AppColors.statusLive : AppColors.statusPending,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Drop-off permit',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    attached
                        ? 'Attached — required to end this job.'
                        : 'Waiting on the customer to attach it. This is required before the job can be ended.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (attached)
              TextButton(onPressed: onOpen, child: const Text('View')),
          ],
        ),
      ),
    );
  }
}

/// A one-way note the company can set for the driver(s) currently on this
/// job/award — the only channel that exists to reach a driver at all, since
/// they have no account and no push channel. See
/// JobAssignmentController::updateInstructions().
class _DriverInstructionsCard extends StatelessWidget {
  const _DriverInstructionsCard({required this.instructions, required this.onEdit});

  final String? instructions;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hasInstructions = instructions != null && instructions!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sms_outlined, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions for driver',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    hasInstructions
                        ? instructions!
                        : "Send a note to the driver's phone by SMS.",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onEdit,
              child: Text(hasInstructions ? 'Edit' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditInstructionsDialog extends StatefulWidget {
  const _EditInstructionsDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_EditInstructionsDialog> createState() => _EditInstructionsDialogState();
}

class _EditInstructionsDialogState extends State<_EditInstructionsDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter what the driver needs to know.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Instructions for driver'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'e.g. Use the back gate, ask for the warehouse supervisor.',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }
}

/// The bidding-stage summary — mockup's light "Submit a Bid" header card.
class _JobInfoCard extends StatelessWidget {
  const _JobInfoCard({required this.job, required this.followRepository});

  final Job job;
  final FollowRepository followRepository;

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
    final customer = job.customerCompanyName ?? job.customerName;

    final rows = <(String, String)>[
      if (job.budgetPrice != null)
        (
          // Multi-Company Split Awards epic: a bulk job's stated budget is
          // always per truck, never a lump sum for the whole trucks_needed
          // count — otherwise a company bidding for only part of a big job
          // (e.g. 5 of 20 trucks) would have no fair number to bid against.
          job.trucksNeeded > 1
              ? 'Customer\'s budget (per truck)'
              : 'Customer\'s budget',
          '${job.currency} ${job.budgetPrice!.toStringAsFixed(0)}',
        ),
      if (job.trucksNeeded > 1)
        (
          'Trucks needed',
          job.assignedTrucksCount != null
              ? '${job.trucksNeeded} (${job.assignedTrucksCount}/${job.trucksNeeded} assigned)'
              : '${job.trucksNeeded}',
        ),
      (
        'Pickup window',
        DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart),
      ),
      // Bidding Deadline epic: informational only while still open — the
      // "Bidding closed" message below the bid form takes over once it
      // actually passes.
      if (job.biddingExpiresAt != null && job.biddingClosed != true)
        (
          'Bidding closes',
          DateFormat('d MMM, HH:mm').format(job.biddingExpiresAt!.toLocal()),
        ),
      if (job.bidsCount != null) ('Current bids', '${job.bidsCount}'),
      // The real completion moment (Job.completedAt), never the pickup
      // window row above — this only appears once the job has actually
      // reached 'completed'.
      if (job.status == 'completed' && job.completedAt != null)
        (
          'Completed',
          DateFormat('d MMMM yyyy').format(job.completedAt!.toLocal()),
        ),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${job.pickupAddress} → ${job.dropoffAddress}',
                        style: TextStyle(
                          fontFamily: 'Barlow Condensed',
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    // Lets a company still deciding whether to bid preview
                    // the real pickup/drop-off route and distance on a map
                    // — no truck assigned yet at this point, so this is a
                    // route-only preview (JobRouteMapScreen), distinct from
                    // LiveGpsTrackingScreen which needs one.
                    IconButton(
                      icon: const Icon(Icons.map_outlined),
                      tooltip: 'View route on map',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobRouteMapScreen(job: job),
                        ),
                      ),
                    ),
                  ],
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
                if (customer != null && job.customerId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerProfileScreen(
                                customerId: job.customerId!,
                              ),
                            ),
                          ),
                          child: Text(
                            customer,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      _FollowButton(
                        customerId: job.customerId!,
                        initialIsFollowing: job.isFollowingCustomer ?? false,
                        repository: followRepository,
                      ),
                    ],
                  ),
                ],
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
  const _ActiveJobCard({
    required this.job,
    this.award,
    required this.liveLocation,
    required this.followRepository,
  });

  final Job job;

  /// Non-null only when the viewer holds one of the job's awards (Multi-
  /// Company Split Awards epic) — its own status/price are shown instead
  /// of the job's, since a split job's own status can stay 'open' long
  /// after this company's own slice is well underway.
  final JobAward? award;
  final GpsLocation? liveLocation;
  final FollowRepository followRepository;

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
    final statusLabel = jobStatusLabel(award?.status ?? job.status);
    final earnings = award?.agreedPrice ?? job.agreedPrice;

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
                      statusLabel,
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
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: job.customerId != null
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerProfileScreen(
                                customerId: job.customerId!,
                              ),
                            ),
                          )
                        : null,
                    child: Text(
                      customer,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.lightBlue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (job.customerId != null)
                  _FollowButton(
                    customerId: job.customerId!,
                    initialIsFollowing: job.isFollowingCustomer ?? false,
                    repository: followRepository,
                    onDark: true,
                  ),
              ],
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
                  if (earnings != null)
                    _SummaryStat(
                      label: 'You earn',
                      value: earnings.toStringAsFixed(0),
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

/// Follow/unfollow this job's customer (Phase: Follow system) — a company
/// only gets "new job posted" notifications from customers it follows.
/// Self-contained (owns its own toggle state + repository call) so it can
/// drop into either job-header variant without either one needing to track
/// follow state itself.
class _FollowButton extends StatefulWidget {
  const _FollowButton({
    required this.customerId,
    required this.initialIsFollowing,
    required this.repository,
    this.onDark = false,
  });

  final int customerId;
  final bool initialIsFollowing;
  final FollowRepository repository;

  /// _ActiveJobCard's dark navy background needs light-on-dark styling;
  /// _JobInfoCard's light background uses the default outlined style.
  final bool onDark;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late bool _isFollowing = widget.initialIsFollowing;
  bool _isBusy = false;

  Future<void> _toggle() async {
    setState(() => _isBusy = true);
    try {
      final result = _isFollowing
          ? await widget.repository.unfollow(widget.customerId)
          : await widget.repository.follow(widget.customerId);
      if (mounted) setState(() => _isFollowing = result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = widget.onDark ? Colors.white : AppColors.ctaBlue;

    return TextButton.icon(
      onPressed: _isBusy ? null : _toggle,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: _isBusy
          ? SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          : Icon(_isFollowing ? Icons.check : Icons.add, size: 15),
      label: Text(
        _isFollowing ? 'Following' : 'Follow',
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
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
  final void Function({int? truckId})? onViewDriverLink;

  @override
  Widget build(BuildContext context) {
    if (job.isMultiTruck) return _buildRoster(context);

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
          // Once the job has actually started (status moved past
          // 'assigned'), the truck already in motion can no longer be
          // swapped out — the backend rejects it too
          // (JobAssignmentService::assign()), this just avoids offering an
          // action that would fail. First-time assignment is unaffected:
          // a job is always still 'assigned' before any truck exists on it.
          if (job.status == 'assigned')
            ElevatedButton(
              onPressed: onAssign,
              child: Text(
                job.assignedTruckRegistration != null
                    ? 'Reassign truck & driver'
                    : 'Assign truck & driver',
              ),
            )
          else if (job.assignedTruckRegistration != null)
            Text(
              'Truck & driver are locked in — this job is already underway.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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

  /// Bulk Cargo epic: a growing roster of truck+driver pairs, built up
  /// incrementally, instead of the single-row/"Reassign" UI above — the
  /// job's own shared status/GPS still comes from the lead truck only
  /// (unchanged elsewhere on this screen), this card just shows who's on
  /// the fleet so far.
  Widget _buildRoster(BuildContext context) {
    final fleet = job.assignedFleet;
    final isFull = fleet.length >= job.trucksNeeded;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assigned fleet (${fleet.length}/${job.trucksNeeded})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 8),
          if (fleet.isEmpty)
            Text(
              'No trucks assigned yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final truck in fleet)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
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
                            truck.registrationNumber ?? '',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            truck.driverName ?? '',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onViewDriverLink != null)
                      IconButton(
                        onPressed: () =>
                            onViewDriverLink!(truckId: truck.truckId),
                        icon: const Icon(Icons.link, size: 18),
                        tooltip: 'View driver link',
                      ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: isFull ? null : onAssign,
            child: Text(isFull ? 'Fleet fully assigned' : 'Add truck & driver'),
          ),
        ],
      ),
    );
  }
}

/// Multi-Company Split Awards epic: one company's own roster on a job it
/// only won part of — the data shape genuinely differs from
/// [_AssignmentCard] (one award's own fleet/capacity, never the job's),
/// so this is built fresh rather than retrofitting that widget.
class _AwardAssignmentCard extends StatelessWidget {
  const _AwardAssignmentCard({
    required this.award,
    required this.onAssign,
    required this.onViewDriverLink,
  });

  final JobAward award;
  final VoidCallback onAssign;
  final void Function({int? truckId}) onViewDriverLink;

  @override
  Widget build(BuildContext context) {
    final fleet = award.assignedFleet;
    final isFull = fleet.length >= award.trucksOffered;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your fleet (${fleet.length}/${award.trucksOffered})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 8),
          if (fleet.isEmpty)
            Text(
              'No trucks assigned yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final truck in fleet)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
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
                            truck.registrationNumber ?? '',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            truck.driverName ?? '',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onViewDriverLink(truckId: truck.truckId),
                      icon: const Icon(Icons.link, size: 18),
                      tooltip: 'View driver link',
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 4),
          if (award.isAssignable)
            ElevatedButton(
              onPressed: isFull ? null : onAssign,
              child: Text(
                isFull ? 'Fleet fully assigned' : 'Add truck & driver',
              ),
            )
          else
            Text(
              jobStatusLabel(award.status),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _ReturnLoadTile extends StatelessWidget {
  const _ReturnLoadTile({
    required this.job,
    required this.onTap,
    required this.onClaim,
    required this.isClaiming,
  });

  final Job job;
  final VoidCallback onTap;

  /// Null when the job has no stated budget_price — nothing to claim at
  /// without negotiation, so the tile is view-only (tap through to bid
  /// normally instead).
  final VoidCallback? onClaim;
  final bool isClaiming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
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
                          job.budgetPrice != null
                              ? '${job.containerType} · ${job.containerSize} · ${job.currency} ${job.budgetPrice!.toStringAsFixed(0)}'
                              : '${job.containerType} · ${job.containerSize}',
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
            if (onClaim != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isClaiming ? null : onClaim,
                  icon: isClaiming
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.replay_outlined, size: 16),
                  label: Text(
                    isClaiming ? 'Claiming…' : 'Claim this load — no bidding',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
