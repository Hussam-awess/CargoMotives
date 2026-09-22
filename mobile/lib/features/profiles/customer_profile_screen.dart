import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/plus_badge.dart';
import '../../shared/widgets/rating_stars.dart';
import '../company/data/follow_repository.dart';
import 'data/profile_repository.dart';
import 'profile_reviews_screen.dart';

/// A customer's public profile (Phase: public profiles) — reachable by
/// tapping their name/logo from a job listing, bid, message thread, or
/// review. See CustomerProfileResource's docblock for exactly what's shown
/// vs. kept private (no contact details, no verification badge, no
/// location).
class CustomerProfileScreen extends StatefulWidget {
  CustomerProfileScreen({
    super.key,
    required this.customerId,
    ProfileRepository? repository,
    FollowRepository? followRepository,
  }) : repository = repository ?? ProfileRepository(),
       followRepository = followRepository ?? FollowRepository();

  final int customerId;
  final ProfileRepository repository;
  final FollowRepository followRepository;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<CustomerProfile> _future;
  bool _isTogglingFollow = false;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.customer(widget.customerId);
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.customer(widget.customerId);
    });
  }

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    setState(() => _isTogglingFollow = true);
    try {
      if (currentlyFollowing) {
        await widget.followRepository.unfollow(widget.customerId);
      } else {
        await widget.followRepository.follow(widget.customerId);
      }
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<CustomerProfile>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this profile.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          final profile = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.brandChip,
                      backgroundImage: profile.pictureUrl != null
                          ? NetworkImage(profile.pictureUrl!)
                          : null,
                      child: profile.pictureUrl == null
                          ? Text(
                              profile.displayName.isEmpty
                                  ? '?'
                                  : profile.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Barlow Condensed',
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.isFeatured) ...[
                                const SizedBox(width: 6),
                                const PlusBadge(),
                              ],
                            ],
                          ),
                          Text(
                            'Member since ${DateFormat('MMMM yyyy').format(profile.memberSince.toLocal())}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.isFollowing != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isTogglingFollow
                          ? null
                          : () => _toggleFollow(profile.isFollowing!),
                      icon: Icon(
                        profile.isFollowing! ? Icons.check : Icons.add,
                        size: 16,
                      ),
                      label: Text(
                        profile.isFollowing! ? 'Following' : 'Follow',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatColumn(
                      label: 'Rating',
                      child: RatingStars(
                        rating: profile.averageRating,
                        count: profile.ratingCount,
                      ),
                    ),
                    _StatColumn(
                      label: 'Completed',
                      value: '${profile.completedJobsCount}',
                    ),
                    _StatColumn(
                      label: 'Cancelled',
                      value: '${profile.cancelledJobsCount}',
                    ),
                  ],
                ),
                if (profile.recentCompletedJobs.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Recent completed jobs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final job in profile.recentCompletedJobs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${job.route} · ${job.containerType}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'd MMM yyyy',
                            ).format(job.completedAt.toLocal()),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reviews',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLabel,
                      ),
                    ),
                    if (profile.ratingCount > 0)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileReviewsScreen(
                              loadPage: (page) =>
                                  widget.repository.customerReviews(
                                    widget.customerId,
                                    page: page,
                                  ),
                            ),
                          ),
                        ),
                        child: const Text('See all'),
                      ),
                  ],
                ),
                if (profile.recentReviews.isEmpty)
                  Text(
                    'No reviews yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (final review in profile.recentReviews)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingStars(
                            rating: review.rating.toDouble(),
                            count: 1,
                            showCount: false,
                          ),
                          if (review.comment != null &&
                              review.comment!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(review.comment!),
                          ],
                        ],
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child ??
            Text(
              value!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
