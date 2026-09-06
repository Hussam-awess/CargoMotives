import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/realtime/job_location_channel.dart';
import '../../jobs/data/bid_repository.dart';
import '../../jobs/data/company_job_repository.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/gps_status_card.dart';
import '../../jobs/messages_screen.dart';
import 'assign_job_screen.dart';
import 'data/job_assignment_repository.dart';

/// Company's Job Detail + Place Bid (AppFlow §2.4): "Tap a job -> details
/// -> Place Bid (price, ETA, note) -> quota check (shows remaining bids/
/// reset time if close to the limit) -> submit."
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
      if (job.isAssignedToViewer && (job.status == 'delivered' || job.status == 'completed')) {
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
      final suggestions = await widget.jobRepository.returnLoadSuggestions(widget.jobId);
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

  Future<void> _openAssignScreen() async {
    final assigned = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AssignJobScreen(job: _job!, assignmentRepository: widget.assignmentRepository)),
    );
    if (assigned == true) _load();
  }

  Future<void> _viewDriverLink() async {
    try {
      final link = await widget.assignmentRepository.currentDriverLink(widget.jobId);
      if (!mounted) return;
      if (link == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No driver link yet.')));
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job detail'),
        actions: [
          if (_job?.isAssignedToViewer == true)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Messages',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(jobId: widget.jobId))),
            ),
        ],
      ),
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
                  if (_job!.isAssignable && _job!.isAssignedToViewer) ...[
                    Text('Assignment', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_job!.assignedTruckRegistration != null)
                      Text('${_job!.assignedTruckRegistration} · ${_job!.assignedDriverName}')
                    else
                      const Text('No truck/driver assigned yet.', style: TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _openAssignScreen,
                      child: Text(_job!.assignedTruckRegistration != null ? 'Reassign truck & driver' : 'Assign truck & driver'),
                    ),
                    if (_job!.assignedTruckRegistration != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _viewDriverLink, child: const Text('View driver link')),
                      const SizedBox(height: 16),
                      GpsStatusCard(
                        trackingActive: _job!.gpsTrackingActive,
                        signalStatus: _job!.gpsSignalStatus,
                        location: _liveLocation,
                      ),
                    ],
                    if (_returnLoadSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Find a return load', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final suggestion in _returnLoadSuggestions)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${suggestion.containerType} · ${suggestion.containerSize}'),
                            subtitle: Text('${suggestion.pickupAddress} → ${suggestion.dropoffAddress}'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CompanyJobDetailScreen(jobId: suggestion.id)),
                            ),
                          ),
                        ),
                    ],
                  ] else if (!_job!.isOpen)
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
