import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/data/job_repository.dart';
import '../data/driver_repository.dart';
import '../data/truck_repository.dart';
import 'data/job_assignment_repository.dart';

/// Assign Job (AppFlow §2.5): "pick a verified, idle truck -> pick a driver
/// from the roster -> Confirm." Issues a Driver Link, shown in-app so the
/// company can copy/re-share it even if the SMS itself didn't go through
/// (TRD §5.3's graceful-degradation principle) — the link is never
/// SMS-only.
class AssignJobScreen extends StatefulWidget {
  AssignJobScreen({
    super.key,
    required this.job,
    TruckRepository? truckRepository,
    DriverRepository? driverRepository,
    JobAssignmentRepository? assignmentRepository,
  }) : truckRepository = truckRepository ?? TruckRepository(),
       driverRepository = driverRepository ?? DriverRepository(),
       assignmentRepository = assignmentRepository ?? JobAssignmentRepository();

  final Job job;
  final TruckRepository truckRepository;
  final DriverRepository driverRepository;
  final JobAssignmentRepository assignmentRepository;

  @override
  State<AssignJobScreen> createState() => _AssignJobScreenState();
}

class _AssignJobScreenState extends State<AssignJobScreen> {
  List<Truck> _trucks = [];
  List<Driver> _drivers = [];
  bool _isLoading = true;
  String? _loadError;

  int? _selectedTruckId;
  int? _selectedDriverId;
  bool _isSubmitting = false;
  String? _submitError;
  DriverLink? _link;

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
      final trucks = await widget.truckRepository.list();
      final drivers = await widget.driverRepository.list();
      if (!mounted) return;
      setState(() {
        // An already-idle-or-assigned-to-this-job truck is eligible — the
        // backend applies the same "already on this job" carve-out.
        _trucks = trucks.where((t) => t.isApproved && t.isIdle).toList();
        _drivers = drivers.where((d) => d.isActive).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load trucks and drivers.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assign() async {
    if (_selectedTruckId == null || _selectedDriverId == null) {
      setState(() => _submitError = 'Pick a truck and a driver.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final link = await widget.assignmentRepository.assign(
        jobId: widget.job.id,
        truckId: _selectedTruckId!,
        driverId: _selectedDriverId!,
      );
      if (mounted) setState(() => _link = link);
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _copyLink() async {
    final link = _link;
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign truck & driver')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(_loadError!), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Try again'))],
              ),
            )
          : _link != null
          ? _AssignedConfirmation(link: _link!, onCopy: _copyLink, onDone: () => Navigator.of(context).pop(true))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_trucks.isEmpty)
                    const Text('No idle, approved trucks available.', style: TextStyle(color: AppColors.textSecondary))
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedTruckId,
                      decoration: const InputDecoration(labelText: 'Truck'),
                      items: _trucks
                          .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.registrationNumber} — ${t.makeModel}')))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedTruckId = value),
                    ),
                  const SizedBox(height: 16),
                  if (_drivers.isEmpty)
                    const Text('No active drivers in your roster.', style: TextStyle(color: AppColors.textSecondary))
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDriverId,
                      decoration: const InputDecoration(labelText: 'Driver'),
                      items: _drivers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.fullName))).toList(),
                      onChanged: (value) => setState(() => _selectedDriverId = value),
                    ),
                  if (_submitError != null) ...[
                    const SizedBox(height: 16),
                    Text(_submitError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (_isSubmitting || _trucks.isEmpty || _drivers.isEmpty) ? null : _assign,
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AssignedConfirmation extends StatelessWidget {
  const _AssignedConfirmation({required this.link, required this.onCopy, required this.onDone});

  final DriverLink link;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, color: AppColors.statusLive, size: 48),
          const SizedBox(height: 16),
          const Text('Assigned. The driver link has been texted to the driver.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SelectableText(link.url, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onCopy, child: const Text('Copy link')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
