import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../jobs/data/job_repository.dart';
import 'data/job_assignment_repository.dart';

/// The manual "end job" escape hatch (Backend: JobAssignmentController::
/// submitProofOfDelivery()) for exactly the case GPS-based auto-advancement
/// can't handle: the truck has genuinely reached the drop-off but a
/// stale/inaccurate GPS fix never crossed the arrival radius, so the job
/// would otherwise sit at "In transit" forever. Submits the same proof of
/// delivery a driver would from the separate Driver Link page — the
/// customer/company/Admin views of it afterward are identical regardless
/// of who submitted it.
class EndJobScreen extends StatefulWidget {
  EndJobScreen({
    super.key,
    required this.jobId,
    this.truckId,
    JobAssignmentRepository? repository,
  }) : repository = repository ?? JobAssignmentRepository();

  final int jobId;

  /// Disambiguates which roster truck's driver link this ends, on a
  /// multi-truck job — omitted (or on an ordinary job) ends the job's one
  /// active link exactly as before.
  final int? truckId;
  final JobAssignmentRepository repository;

  @override
  State<EndJobScreen> createState() => _EndJobScreenState();
}

class _EndJobScreenState extends State<EndJobScreen> {
  static const _allowedExtensions = ['jpg', 'jpeg', 'png', 'heic'];

  final _recipientName = TextEditingController();
  final _notes = TextEditingController();
  final List<PlatformFile> _photos = [];
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _recipientName.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() => _photos.addAll(result.files.take(5 - _photos.length)));
    }
  }

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      setState(() => _errorText = 'Add at least one photo as proof of delivery.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final job = await widget.repository.submitProofOfDelivery(
        jobId: widget.jobId,
        photos: _photos,
        recipientName: _recipientName.text.trim().isEmpty ? null : _recipientName.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop<Job>(job);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('End job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Submit proof of delivery to mark this job delivered — '
              'useful when the truck has genuinely arrived but the live '
              'map hasn\'t caught up yet.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Proof photos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_photos.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Chip(
                      label: Text(_photos[i].name, overflow: TextOverflow.ellipsis),
                      onDeleted: () => setState(() => _photos.removeAt(i)),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _photos.length >= 5 ? null : _pickPhotos,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_photos.isEmpty ? 'Add photos' : 'Add more photos'),
            ),
            const SizedBox(height: 20),
            const Text('Recipient name (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _recipientName,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Who received the cargo?'),
            ),
            const SizedBox(height: 16),
            const Text('Notes (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Anything worth noting?'),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mark as delivered'),
            ),
          ],
        ),
      ),
    );
  }
}
