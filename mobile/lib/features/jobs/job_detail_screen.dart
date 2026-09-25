import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/realtime/job_bid_channel.dart';
import '../../core/realtime/job_location_channel.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/job_views_badge.dart';
import '../auth/data/auth_repository.dart';
import '../profiles/transporter_profile_screen.dart';
import '../reviews/rate_job_card.dart';
import '../reviews/rate_job_screen.dart';
import 'booking_confirmation_screen.dart';
import 'data/bid_repository.dart';
import 'data/job_repository.dart';
import 'gps_status_card.dart';
import 'job_geo.dart';
import 'job_status.dart';
import 'live_gps_tracking_screen.dart';
import 'messages_screen.dart';
import 'post_job_screen.dart';
import 'truck_details_screen.dart';

/// Job Detail (Customer) — AppFlow §3.3/§3.4: the job summary, its bid
/// list (Featured pinned first, live-updated per TRD §4 while this screen
/// is open), Accept Bid, and (Phase 6) a live GPS status card once a
/// truck's assigned. Restyled to the mockup's "Shipment Details" screen —
/// the timeline shown is derived live from the job's current status, not
/// a fabricated event log (this app has no per-event history endpoint).
class JobDetailScreen extends StatefulWidget {
  JobDetailScreen({
    super.key,
    required this.jobId,
    JobRepository? jobRepository,
    BidRepository? bidRepository,
    JobBidChannel? bidChannel,
    JobLocationChannel? locationChannel,
    AuthRepository? authRepository,
  }) : jobRepository = jobRepository ?? JobRepository(),
       bidRepository = bidRepository ?? BidRepository(),
       bidChannel = bidChannel ?? JobBidChannel(jobId: jobId),
       locationChannel = locationChannel ?? JobLocationChannel(jobId: jobId),
       authRepository = authRepository ?? AuthRepository();

  final int jobId;
  final JobRepository jobRepository;
  final BidRepository bidRepository;
  final JobBidChannel bidChannel;
  final JobLocationChannel locationChannel;
  final AuthRepository authRepository;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  List<Bid> _bids = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isConfirmingDelivery = false;
  bool _isReportingProblem = false;
  int? _confirmingAwardId;
  GpsLocation? _liveLocation;
  bool _isFeatured = false;
  bool _isUploadingPickupPermit = false;
  bool _isUploadingDropoffPermit = false;

  static const _permitFileExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadFeaturedStatus();
    widget.bidChannel
      ..onBidPlaced = _handleLiveBid
      ..connect();
    widget.locationChannel
      ..onLocationUpdated = _handleLiveLocation
      ..connect();
  }

  /// Only powers the "Post return shipment" Plus benefit below — a failed
  /// fetch just leaves that button hidden rather than blocking the rest
  /// of this screen, which doesn't otherwise need the customer's own
  /// profile at all.
  Future<void> _loadFeaturedStatus() async {
    try {
      final profile = await widget.authRepository.me();
      if (mounted) setState(() => _isFeatured = profile.isFeatured);
    } catch (_) {
      // Non-critical — see docblock above.
    }
  }

  void _openReturnShipment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostJobScreen(prefillReturnFrom: _job!),
      ),
    );
  }

  /// Bidding Deadline epic: "Repost Job" and "Edit & Repost" are the same
  /// prefilled-form flow — a straight (non-reversed) prefill of every
  /// field, opened for the customer to review/adjust before submitting.
  /// There's no true one-tap silent repost anywhere else in this app, so
  /// building a separate auto-submit path for "Repost Job" alone would be
  /// inventing a flow with no precedent, not saving the customer a step.
  void _openRepost() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostJobScreen(prefillClone: _job!)),
    );
  }

  /// While still 'open' (before any bid is accepted — JobController's own
  /// assertEditable()), the customer can correct a mistaken pickup/drop-off
  /// pin. Editing the route auto-withdraws any pending bids server-side, so
  /// this warns first when there's at least one to lose.
  Future<void> _openEditShipment() async {
    final pendingBids = _job!.bidsCount ?? 0;
    if (pendingBids > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit shipment?'),
          content: Text(
            'This job has $pendingBids pending bid${pendingBids == 1 ? '' : 's'}. '
            'Editing the pickup/drop-off location will withdraw ${pendingBids == 1 ? 'it' : 'them'} '
            'so companies can bid again at the new distance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    final result = await Navigator.of(
      context,
    ).push<Job>(MaterialPageRoute(builder: (_) => PostJobScreen(editJob: _job!)));
    if (result != null && mounted) setState(() => _job = result);
  }

  void _openMessages(BuildContext context) {
    final companyId = _job?.assignedCompanyId;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          jobId: widget.jobId,
          counterpartyName: _job?.assignedCompanyName,
          // Messaging itself is with the company (its owner sends/reads
          // this thread — the driver has no login), but the customer still
          // wants to know who's actually driving their shipment.
          counterpartySubtitle: _job?.assignedDriverName != null
              ? 'Driver: ${_job!.assignedDriverName}'
              : null,
          onOpenCounterpartyProfile: companyId != null
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TransporterProfileScreen(companyId: companyId),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _openRateJob() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RateJobScreen(
          jobId: widget.jobId,
          direction: RatingDirection.customerRatingTransporter,
        ),
      ),
    );
    if (submitted == true) await _load();
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
      _bids = [bid, ..._bids.where((b) => b.id != bid.id)]
        ..sort((a, b) => (b.isPriority ? 1 : 0) - (a.isPriority ? 1 : 0));
    });
  }

  void _handleLiveLocation(Map<String, dynamic> locationJson) {
    if (!mounted) return;
    setState(() => _liveLocation = GpsLocation.fromJson(locationJson));
  }

  Future<void> _accept(Bid bid) async {
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          job: _job!,
          bid: bid,
          bidRepository: widget.bidRepository,
        ),
      ),
    );
    if (confirmed == true) await _load();
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isConfirmingDelivery = true);
    try {
      await widget.jobRepository.confirmDelivery(widget.jobId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isConfirmingDelivery = false);
    }
  }

  /// Multi-Company Split Awards epic: confirms one company's own slice of
  /// a split job — the per-award equivalent of [_confirmDelivery], used
  /// whenever the job has any awards (there's no single "the" delivery to
  /// confirm at the job level once a job has 2+ companies).
  Future<void> _confirmAwardDelivery(int awardId) async {
    setState(() => _confirmingAwardId = awardId);
    try {
      await widget.jobRepository.confirmAwardDelivery(widget.jobId, awardId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _confirmingAwardId = null);
    }
  }

  Future<void> _reportProblem() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportProblemDialog(),
    );
    if (reason == null) return;

    setState(() => _isReportingProblem = true);
    try {
      await widget.jobRepository.reportProblem(widget.jobId, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reported. Our team will review this delivery.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isReportingProblem = false);
    }
  }

  /// Uploads (or replaces) a cargo-authority checkpoint permit — see
  /// [Job.pickupPermitUrl]/[Job.dropoffPermitUrl]'s docblock for why the
  /// drop-off one matters more than the pickup one (it's a hard blocker on
  /// the company/driver being able to end the job).
  Future<void> _uploadPermit({required bool isPickup}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _permitFileExtensions,
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return;

    setState(
      () => isPickup
          ? _isUploadingPickupPermit = true
          : _isUploadingDropoffPermit = true,
    );
    try {
      final updated = isPickup
          ? await widget.jobRepository.uploadPickupPermit(widget.jobId, file)
          : await widget.jobRepository.uploadDropoffPermit(
              widget.jobId,
              file,
            );
      if (mounted) setState(() => _job = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(
          () => isPickup
              ? _isUploadingPickupPermit = false
              : _isUploadingDropoffPermit = false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipment Details'),
        actions: [
          if (_job?.isOpen == true)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit shipment',
              onPressed: _openEditShipment,
            ),
          if (_job?.assignedCompanyName != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
              onPressed: () => _openMessages(context),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _JobSummaryCard(job: _job!, liveLocation: _liveLocation),
                  // Multi-Company Split Awards epic: once a job has ANY
                  // award, the legacy single-company block below (GPS/
                  // Timeline/Transporter/Fleet/PoD, all keyed off the job's
                  // own permanently-null assigned_* fields) has nothing
                  // real to show — _AwardedCompaniesList renders each
                  // company's own slice instead.
                  if (_job!.awards.isEmpty) ...[
                    if (_job!.isAssignable) ...[
                      const SizedBox(height: 16),
                      GpsStatusCard(
                        trackingActive: _job!.gpsTrackingActive,
                        signalStatus: _job!.gpsSignalStatus,
                        location: _liveLocation,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveGpsTrackingScreen(
                              job: _job!,
                              onRefresh: () =>
                                  widget.jobRepository.show(_job!.id),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.near_me_outlined, size: 16),
                        label: const Text('Open live tracking'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _SectionLabel('Timeline'),
                    const SizedBox(height: 4),
                    _StatusTimeline(
                      status: _job!.status,
                      pickupPermitUrl: _job!.pickupPermitUrl,
                      dropoffPermitUrl: _job!.dropoffPermitUrl,
                    ),
                    if (_job!.assignedDriverName != null) ...[
                      const SizedBox(height: 20),
                      const _SectionLabel('Transporter'),
                      const SizedBox(height: 4),
                      _TransporterCard(
                        job: _job!,
                        onChat: () => _openMessages(context),
                      ),
                    ],
                    if (_job!.isMultiTruck &&
                        _job!.assignedFleet.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionLabel(
                        'Assigned fleet (${_job!.assignedFleet.length}/${_job!.trucksNeeded})',
                      ),
                      const SizedBox(height: 4),
                      _FleetRosterCard(fleet: _job!.assignedFleet),
                    ],
                    const SizedBox(height: 20),
                    const _SectionLabel('Cargo'),
                    const SizedBox(height: 4),
                    _CargoDetailsCard(job: _job!),
                    if (_job!.proofOfDelivery != null) ...[
                      const SizedBox(height: 16),
                      _ProofOfDeliveryCard(
                        proofOfDelivery: _job!.proofOfDelivery!,
                        completedAt: _job!.completedAt,
                        canConfirm: _job!.isAwaitingDeliveryConfirmation,
                        isConfirming: _isConfirmingDelivery,
                        isReportingProblem: _isReportingProblem,
                        onConfirm: _confirmDelivery,
                        onReportProblem: _reportProblem,
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 20),
                    _AwardedCompaniesList(
                      job: _job!,
                      jobRepository: widget.jobRepository,
                      confirmingAwardId: _confirmingAwardId,
                      onConfirmDelivery: _confirmAwardDelivery,
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Cargo'),
                    const SizedBox(height: 4),
                    _CargoDetailsCard(job: _job!),
                  ],
                  // Cargo-authority checkpoint permits (job-level even for
                  // a split-award job — see the backend permit migrations'
                  // docblocks) — shown once a truck/driver is actually
                  // assigned, not while the job is still just 'open'.
                  if (_job!.isAssignable || _job!.isAwaitingDeliveryConfirmation || _job!.status == 'completed') ...[
                    const SizedBox(height: 20),
                    const _SectionLabel('Permits'),
                    const SizedBox(height: 8),
                    _PermitCard(
                      title: 'Pickup permit',
                      subtitle: 'Optional — hand this to the driver before pickup.',
                      permitUrl: _job!.pickupPermitUrl,
                      isUploading: _isUploadingPickupPermit,
                      onUpload: () => _uploadPermit(isPickup: true),
                    ),
                    const SizedBox(height: 8),
                    _PermitCard(
                      title: 'Drop-off permit',
                      subtitle: 'Required before this job can be marked delivered.',
                      permitUrl: _job!.dropoffPermitUrl,
                      isUploading: _isUploadingDropoffPermit,
                      onUpload: () => _uploadPermit(isPickup: false),
                    ),
                  ],
                  // Ratings are deferred for a split job (JobResource.
                  // isViewerAParticipant() already returns false whenever
                  // assigned_company_id is null, which holds for every job
                  // with any award) — reviewable stays false/null there
                  // already, this check is just belt-and-suspenders.
                  if (_job!.reviewable == true && _job!.awards.isEmpty) ...[
                    const SizedBox(height: 16),
                    RateJobCard(onTap: _openRateJob),
                  ],
                  if (_job!.status == 'completed' && _isFeatured) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openReturnShipment,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Post return shipment'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bids (${_bids.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_isFeatured && _job!.jobViewsCount != null)
                        JobViewsBadge(count: _job!.jobViewsCount!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bidding Deadline epic: two derived states once the
                  // deadline passes — 🔴 nothing to show if no one bid
                  // (Repost is the only next step), 🟡 the bid list/Accept
                  // flow below stays completely untouched otherwise; the
                  // customer still explicitly chooses who to accept, this
                  // banner is purely informational.
                  if (_job!.biddingClosed == true) ...[
                    _BiddingClosedBanner(
                      hasBids: _bids.isNotEmpty,
                      onRepost: _openRepost,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_bids.isEmpty && _job!.biddingClosed != true)
                    Text(
                      'No bids yet.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  for (final bid in _bids) ...[
                    _BidCard(
                      job: _job!,
                      bid: bid,
                      canAccept: _job!.isOpen,
                      onAccept: () => _accept(bid),
                      onOpenDetails: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TruckDetailsScreen(
                            job: _job!,
                            bid: bid,
                            onAccept: () => _accept(bid),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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

/// A cargo-authority checkpoint permit's upload/replace/view row — used for
/// both the pickup permit (informational) and drop-off permit (a hard
/// blocker on the job being marked delivered, enforced server-side).
class _PermitCard extends StatelessWidget {
  const _PermitCard({
    required this.title,
    required this.subtitle,
    required this.permitUrl,
    required this.isUploading,
    required this.onUpload,
  });

  final String title;
  final String subtitle;
  final String? permitUrl;
  final bool isUploading;
  final VoidCallback onUpload;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(permitUrl!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final attached = permitUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              attached ? Icons.task_alt : Icons.upload_file_outlined,
              color: attached ? AppColors.statusLive : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (attached)
                TextButton(
                  onPressed: () => _open(context),
                  child: const Text('View'),
                ),
              TextButton(
                onPressed: onUpload,
                child: Text(attached ? 'Replace' : 'Upload'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.job, required this.liveLocation});

  final Job job;
  final GpsLocation? liveLocation;

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
          if (distance != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.only(top: 13),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _SummaryStat(
                      label: 'Distance',
                      value: '${distance.toStringAsFixed(0)} km',
                    ),
                    if (remaining != null) ...[
                      const SizedBox(width: 20),
                      _SummaryStat(
                        label: 'Remaining',
                        value: '${remaining.toStringAsFixed(0)} km',
                      ),
                    ],
                    if (job.agreedPrice != null) ...[
                      const SizedBox(width: 20),
                      _SummaryStat(
                        label: 'Price',
                        value:
                            '${job.currency} ${job.agreedPrice!.toStringAsFixed(0)}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

/// The job's own status vocabulary — unchanged from before the permit
/// stages existed. [_StatusTimeline] interleaves two more synthetic rows
/// ("Waiting for pickup/drop-off permit") around these, computed from
/// permit presence rather than [Job.status] (which has no state for
/// "a permit is pending").
const _realTimelineStages = [
  'open',
  'assigned',
  'picked_up',
  'in_transit',
  'delivered',
  'completed',
];
enum _TimelineStageState { done, current, upcoming }

/// A live status ladder, not a fabricated event history — this app has no
/// per-event audit trail exposed to Customers, only the job's current
/// status, so each stage is shown as done/current/upcoming relative to
/// that one value.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.status,
    this.pickupPermitUrl,
    this.dropoffPermitUrl,
  });

  final String status;

  /// Always the JOB-level permit fields (Job.pickupPermitUrl/
  /// dropoffPermitUrl) — never an award's own, since permits stay job-level
  /// even for a split-award job. Callers rendering this for one award's own
  /// status still pass the enclosing job's permit fields, not anything
  /// from that award.
  final String? pickupPermitUrl;
  final String? dropoffPermitUrl;

  int get _realStageIndex {
    // 'en_route_pickup' has no timeline row of its own — it still reads
    // as "Transporter assigned" until the truck is actually loaded.
    final effective = status == 'en_route_pickup' ? 'assigned' : status;
    final index = _realTimelineStages.indexOf(effective);
    return index == -1 ? 0 : index;
  }

  _TimelineStageState _realStageState(int realIndex, int real) {
    if (realIndex < real) return _TimelineStageState.done;
    if (realIndex == real) return _TimelineStageState.current;
    return _TimelineStageState.upcoming;
  }

  /// Informational only — pickup permit never blocks progress (unlike the
  /// drop-off one below), so it reads "done" once the job has clearly moved
  /// on even if no permit was ever attached.
  _TimelineStageState _pickupPermitState(int real) {
    if (pickupPermitUrl != null || real > 1) return _TimelineStageState.done;
    return real == 1 ? _TimelineStageState.current : _TimelineStageState.upcoming;
  }

  /// A real gate — the backend hard-blocks 'delivered' without this
  /// attached, so by construction real > 3 here always means it's set.
  _TimelineStageState _dropoffPermitState(int real) {
    if (dropoffPermitUrl != null || real > 3) return _TimelineStageState.done;
    return real == 3 ? _TimelineStageState.current : _TimelineStageState.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Text(
        'This shipment was cancelled.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    final real = _realStageIndex;
    final states = [
      _realStageState(0, real), // Shipment posted
      _realStageState(1, real), // Transporter assigned
      _pickupPermitState(real), // Waiting for pickup permit
      _realStageState(2, real), // Loading cargo
      _realStageState(3, real), // In transit
      _dropoffPermitState(real), // Waiting for drop-off permit
      _realStageState(4, real), // Delivered
      _realStageState(5, real), // Completed
    ];
    const labels = [
      'Shipment posted',
      'Transporter assigned',
      'Waiting for pickup permit',
      'Loading cargo',
      'In transit',
      'Waiting for drop-off permit',
      'Delivered',
      'Completed',
    ];
    const icons = [
      Icons.description_outlined,
      Icons.local_shipping_outlined,
      Icons.assignment_outlined,
      Icons.inventory_2_outlined,
      Icons.local_shipping,
      Icons.assignment_outlined,
      Icons.check_circle_outline,
      Icons.task_alt,
    ];

    return Column(
      children: [
        for (var i = 0; i < states.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: states[i] != _TimelineStageState.upcoming
                              ? AppColors.ctaBlue
                              : AppColors.surface,
                          border: states[i] != _TimelineStageState.upcoming
                              ? null
                              : Border.all(color: AppColors.border, width: 2),
                          boxShadow: states[i] == _TimelineStageState.current
                              ? const [
                                  BoxShadow(
                                    color: Color(0xFFDCE9F7),
                                    blurRadius: 0,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icons[i],
                          size: 15,
                          color: states[i] != _TimelineStageState.upcoming
                              ? Colors.white
                              : AppColors.textTertiary,
                        ),
                      ),
                      if (i != states.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            color: states[i] == _TimelineStageState.done
                                ? AppColors.ctaBlue
                                : AppColors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom: i == states.length - 1 ? 0 : 18,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: states[i] != _TimelineStageState.upcoming
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransporterCard extends StatelessWidget {
  const _TransporterCard({required this.job, required this.onChat});

  final Job job;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.local_shipping_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: job.assignedCompanyId == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransporterProfileScreen(
                          companyId: job.assignedCompanyId!,
                        ),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.assignedDriverName ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      if (job.assignedCompanyName != null)
                        job.assignedCompanyName!,
                      if (job.assignedTruckRegistration != null)
                        job.assignedTruckRegistration!,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onChat,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bidding Deadline epic: the two derived states once a job's deadline
/// passes. 🔴 "Bidding Closed" (no bids ever came in) offers Repost/Edit &
/// Repost — the job's own bid list stays empty, nothing here to review. 🟡
/// "Bidding Closed — Select a Transporter" is purely informational: the
/// bid list and Accept flow right below this banner are completely
/// unchanged, since the job is still `status === 'open'` and the customer
/// can still accept any of the bids already in.
class _BiddingClosedBanner extends StatelessWidget {
  const _BiddingClosedBanner({required this.hasBids, required this.onRepost});

  final bool hasBids;
  final VoidCallback onRepost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasBids ? AppColors.infoTint : AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(hasBids ? '🟡' : '🔴', style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasBids
                      ? 'Bidding Closed — Select a Transporter'
                      : 'Bidding Closed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (!hasBids) ...[
            const SizedBox(height: 4),
            Text(
              'Nobody bid before the deadline.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRepost,
                    child: const Text('Edit & Repost'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRepost,
                    child: const Text('Repost Job'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'The bids below are still available — choose who you\'d like to work with.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _CargoDetailsCard extends StatelessWidget {
  const _CargoDetailsCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Type', '${job.containerType} · ${job.containerSize}'),
      if (job.trucksNeeded > 1) ('Trucks needed', '${job.trucksNeeded}'),
      if (job.approxWeightTons != null)
        ('Weight', '${job.approxWeightTons!.toStringAsFixed(0)} tons'),
      if (job.cargoDescription != null && job.cargoDescription!.isNotEmpty)
        ('Description', job.cargoDescription!),
      if (job.budgetPrice != null)
        (
          'Your budget',
          '${job.currency} ${job.budgetPrice!.toStringAsFixed(0)}',
        ),
      (
        'Pickup window',
        DateFormat('d MMM, HH:mm').format(job.preferredPickupWindowStart),
      ),
      // Bidding Deadline epic: informational only while still open — once
      // closed, the banner above the bid list takes over communicating
      // that (job_detail_screen.dart's _BiddingClosedBanner).
      if (job.biddingExpiresAt != null && job.biddingClosed != true)
        (
          'Bidding closes',
          DateFormat('d MMM, HH:mm').format(job.biddingExpiresAt!.toLocal()),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
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
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
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

/// Bulk Cargo epic: a read-only list of every truck+driver committed to a
/// multi-truck job so far — the job's own shared status/GPS still comes
/// from the lead truck only (shown separately in _TransporterCard above),
/// this is purely "who's on the fleet."
class _FleetRosterCard extends StatelessWidget {
  const _FleetRosterCard({required this.fleet});

  final List<AssignedTruckSummary> fleet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < fleet.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: i == fleet.length - 1
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
                    fleet[i].registrationNumber ?? '',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    fleet[i].driverName ?? '',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
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

/// Multi-Company Split Awards epic: one card per company that ended up
/// covering only part of this job — each fully self-contained (its own
/// status timeline, GPS, fleet roster, proof of delivery), since two
/// unrelated companies' progress can never share one shared job-level
/// status the way Tier 1/2 does.
class _AwardedCompaniesList extends StatelessWidget {
  const _AwardedCompaniesList({
    required this.job,
    required this.jobRepository,
    required this.confirmingAwardId,
    required this.onConfirmDelivery,
  });

  final Job job;
  final JobRepository jobRepository;
  final int? confirmingAwardId;
  final void Function(int awardId) onConfirmDelivery;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final award in job.awards) ...[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransporterProfileScreen(
                              companyId: award.companyId,
                            ),
                          ),
                        ),
                        child: Text(
                          award.companyName ?? 'Transporter',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${award.trucksOffered} truck${award.trucksOffered == 1 ? '' : 's'} · ${job.currency} ${award.agreedPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusTimeline(
                  status: award.status,
                  pickupPermitUrl: job.pickupPermitUrl,
                  dropoffPermitUrl: job.dropoffPermitUrl,
                ),
                if (award.assignedFleet.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GpsStatusCard(
                    trackingActive: award.gpsTrackingActive,
                    signalStatus: award.gpsSignalStatus,
                    location: award.lastKnownLocation,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveGpsTrackingScreen(
                          job: job.forAwardMapView(award),
                          onRefresh: () async {
                            final fresh = await jobRepository.show(job.id);
                            return fresh.forAwardMapView(
                              fresh.awards.firstWhere((a) => a.id == award.id),
                            );
                          },
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.near_me_outlined, size: 16),
                    label: const Text('Open live tracking'),
                  ),
                  const SizedBox(height: 12),
                  _FleetRosterCard(fleet: award.assignedFleet),
                ],
                if (award.proofOfDelivery != null) ...[
                  const SizedBox(height: 16),
                  _ProofOfDeliveryCard(
                    proofOfDelivery: award.proofOfDelivery!,
                    completedAt: award.completedAt,
                    canConfirm: award.isAwaitingDeliveryConfirmation,
                    isConfirming: confirmingAwardId == award.id,
                    onConfirm: () => onConfirmDelivery(award.id),
                  ),
                ],
              ],
            ),
          ),
          if (award != job.awards.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// UI/UX Brief §5.1: company name + verification checkmark, truck count,
/// rating — the trust line — plus a calm GPS status dot/label, price large
/// and clear, a simple Accept button. Featured/priority bids get a small
/// text label, not a heavy visual treatment (per the brief's "GPS is a
/// badge, not a gate" / "one clean design system" direction).
class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.job,
    required this.bid,
    required this.canAccept,
    required this.onAccept,
    required this.onOpenDetails,
  });

  final Job job;
  final Bid bid;
  final bool canAccept;
  final VoidCallback onAccept;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final company = bid.company;

    return InkWell(
      onTap: onOpenDetails,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bid.isReturnLoadClaim) ...[
              Row(
                children: [
                  Icon(
                    Icons.replay_outlined,
                    size: 13,
                    color: AppColors.ctaBluePressed,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'RETURN LOAD MATCH · NO NEGOTIATION',
                    style: TextStyle(
                      color: AppColors.ctaBluePressed,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ] else if (bid.isPriority) ...[
              const Text(
                'FEATURED',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TransporterProfileScreen(companyId: company.id),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: company.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (company.verified)
                            const TextSpan(
                              text: '  ✓',
                              style: TextStyle(color: AppColors.statusLive),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Text(
                  '${job.currency} ${bid.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontFamily: 'Barlow Condensed',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${company.truckCount} verified trucks',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: company.gpsAvailable
                        ? AppColors.statusLive
                        : AppColors.statusIdle,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  company.gpsAvailable
                      ? 'Live GPS Available'
                      : 'GPS Tracking Not Available',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  company.rating != null
                      ? '⭐ ${company.rating!.toStringAsFixed(1)}'
                      : 'New',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (bid.note != null && bid.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bid.note!, style: const TextStyle(fontSize: 13)),
            ],
            if (canAccept && bid.status == 'pending') ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                ),
                child: const Text('Accept'),
              ),
            ] else if (bid.status != 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  bid.status,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// AppFlow §3.5: the driver's submitted proof — photos, optional recipient
/// name/notes — plus Confirm Receipt while the job is still 'delivered'
/// (not yet 'completed'), or its alternative, Report a Problem (raises a
/// Dispute, JobController::reportProblem()). Once confirmed, this just
/// shows the same information read-only (confirmedByCustomerAt is set).
class _ProofOfDeliveryCard extends StatelessWidget {
  const _ProofOfDeliveryCard({
    required this.proofOfDelivery,
    required this.completedAt,
    required this.canConfirm,
    required this.isConfirming,
    this.isReportingProblem = false,
    required this.onConfirm,
    this.onReportProblem,
  });

  final ProofOfDelivery proofOfDelivery;

  /// The real completion moment (Job.completedAt) — set the instant
  /// confirmedByCustomerAt is, so this is only null while a render happens
  /// to race a just-sent confirm-delivery response (vanishingly rare, and
  /// harmless: the "Confirmed" label below still shows on its own).
  final DateTime? completedAt;
  final bool canConfirm;
  final bool isConfirming;
  final bool isReportingProblem;
  final VoidCallback onConfirm;

  /// Null for a Multi-Company Split Awards epic per-award card — there's
  /// no award-scoped dispute endpoint (JobController::reportProblem()
  /// gates on the JOB reaching 'delivered', which a split job's own
  /// status never does), so that action simply isn't offered there yet.
  final VoidCallback? onReportProblem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Proof of delivery'),
          const SizedBox(height: 12),
          if (proofOfDelivery.isSystemGenerated)
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Expanded(child: Text('Automatically completed')),
              ],
            )
          else
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
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
                      color: AppColors.background,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (proofOfDelivery.recipientName != null) ...[
            const SizedBox(height: 12),
            Text('Received by: ${proofOfDelivery.recipientName}'),
          ],
          if (proofOfDelivery.notes != null &&
              proofOfDelivery.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(proofOfDelivery.notes!),
          ],
          if (canConfirm) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConfirming ? null : onConfirm,
                    child: isConfirming
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirm Receipt'),
                  ),
                ),
                if (onReportProblem != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isReportingProblem ? null : onReportProblem,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusError,
                        side: BorderSide(color: AppColors.dangerBorder),
                      ),
                      child: isReportingProblem
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Report issue'),
                    ),
                  ),
                ],
              ],
            ),
          ] else if (proofOfDelivery.confirmedByCustomerAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirmed',
                    style: TextStyle(
                      color: AppColors.statusLive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (completedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Completed on ${DateFormat('d MMMM yyyy').format(completedAt!.toLocal())}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportProblemDialog extends StatefulWidget {
  const _ReportProblemDialog();

  @override
  State<_ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<_ReportProblemDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 10) {
      setState(
        () => _error = 'Please describe the issue in at least 10 characters.',
      );
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report an issue'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'What went wrong with this delivery?',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
