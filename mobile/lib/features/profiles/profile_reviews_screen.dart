import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/rating_stars.dart';
import 'data/profile_repository.dart';

/// The full, paginated review list behind a profile's "See all reviews" —
/// shared by both CustomerProfileScreen and TransporterProfileScreen via
/// [loadPage], since the review shape/anonymity rules are identical for
/// both directions.
class ProfileReviewsScreen extends StatefulWidget {
  const ProfileReviewsScreen({super.key, required this.loadPage});

  final Future<List<ProfileReview>> Function(int page) loadPage;

  @override
  State<ProfileReviewsScreen> createState() => _ProfileReviewsScreenState();
}

class _ProfileReviewsScreenState extends State<ProfileReviewsScreen> {
  final List<ProfileReview> _reviews = [];
  int _page = 1;
  bool _isLoading = true;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.loadPage(_page);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page);
        _hasMore = page.isNotEmpty;
        _page++;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load reviews.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: _reviews.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty && _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _loadNextPage, child: const Text('Try again')),
                ],
              ),
            )
          : _reviews.isEmpty
          ? Center(child: Text('No reviews yet.', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _reviews.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (context, index) {
                if (index == _reviews.length) {
                  if (!_hasMore) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : OutlinedButton(onPressed: _loadNextPage, child: const Text('Load more')),
                    ),
                  );
                }

                final review = _reviews[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RatingStars(rating: review.rating.toDouble(), count: 1, showCount: false),
                        Text(
                          DateFormat('d MMM yyyy').format(review.createdAt.toLocal()),
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    if (review.comment != null && review.comment!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(review.comment!),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
