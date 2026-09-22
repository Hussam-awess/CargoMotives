import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'data/review_repository.dart';

/// Which side of a completed job is being rated — decides both the
/// category-rating labels shown and which of JobReviewController's two
/// directions the submission becomes. A customer only ever rates a
/// transporter, and vice versa; this is never chosen by the user.
enum RatingDirection { customerRatingTransporter, transporterRatingCustomer }

/// "How was your experience?" (Phase: ratings) — a star rating (required)
/// plus three direction-specific category ratings and an optional written
/// comment. Reached only from a completed job whose [RateJobCard] shows a
/// non-blocking prompt; never forced on the user.
class RateJobScreen extends StatefulWidget {
  RateJobScreen({super.key, required this.jobId, required this.direction, ReviewRepository? repository})
    : repository = repository ?? ReviewRepository();

  final int jobId;
  final RatingDirection direction;
  final ReviewRepository repository;

  @override
  State<RateJobScreen> createState() => _RateJobScreenState();
}

class _RateJobScreenState extends State<RateJobScreen> {
  int _rating = 0;
  final _comment = TextEditingController();
  late final Map<String, int> _categoryRatings = {for (final key in _categoryKeys) key: 0};
  bool _isSubmitting = false;
  String? _errorText;

  List<String> get _categoryKeys => widget.direction == RatingDirection.customerRatingTransporter
      ? const ['punctuality', 'vehicle_condition', 'professionalism']
      : const ['communication', 'cargo_accuracy', 'payment_promptness'];

  String _categoryLabel(String key) => switch (key) {
    'punctuality' => 'On-time pickup',
    'vehicle_condition' => 'Vehicle condition',
    'professionalism' => 'Professionalism',
    'communication' => 'Communication',
    'cargo_accuracy' => 'Accurate cargo information',
    'payment_promptness' => 'Payment promptness',
    _ => key,
  };

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _errorText = 'Choose a star rating.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final givenCategoryRatings = Map<String, int>.fromEntries(_categoryRatings.entries.where((e) => e.value > 0));
      await widget.repository.submit(
        jobId: widget.jobId,
        rating: _rating,
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        categoryRatings: givenCategoryRatings.isEmpty ? null : givenCategoryRatings,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your experience')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('How was your experience?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Center(
              child: _StarRow(value: _rating, size: 36, onChanged: (v) => setState(() => _rating = v)),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            for (final key in _categoryKeys) ...[
              Text(_categoryLabel(key), style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              _StarRow(value: _categoryRatings[key]!, size: 22, onChanged: (v) => setState(() => _categoryRatings[key] = v)),
              const SizedBox(height: 16),
            ],
            const Text('Comment (optional)', style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 6),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Anything you want to add?'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.value, required this.onChanged, this.size = 28});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(i <= value ? Icons.star : Icons.star_border, size: size, color: Colors.amber),
            ),
          ),
      ],
    );
  }
}
