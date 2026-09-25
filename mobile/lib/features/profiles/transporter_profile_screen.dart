import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/map/app_map.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/plus_badge.dart';
import '../../shared/widgets/rating_stars.dart';
import '../../shared/widgets/verified_badge.dart';
import 'data/profile_repository.dart';
import 'profile_reviews_screen.dart';

/// A transporter company's public profile (Phase: public profiles) —
/// reachable by tapping their name/logo from a job listing, bid, message
/// thread, or review. See CompanyProfileResource's docblock for exactly
/// what's shown vs. kept private (no contact details, no follow field —
/// only a customer can be followed).
class TransporterProfileScreen extends StatefulWidget {
  TransporterProfileScreen({
    super.key,
    required this.companyId,
    ProfileRepository? repository,
  }) : repository = repository ?? ProfileRepository();

  final int companyId;
  final ProfileRepository repository;

  @override
  State<TransporterProfileScreen> createState() =>
      _TransporterProfileScreenState();
}

class _TransporterProfileScreenState extends State<TransporterProfileScreen> {
  late Future<CompanyProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.company(widget.companyId);
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.company(widget.companyId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<CompanyProfile>(
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
                              profile.companyName.isEmpty
                                  ? '?'
                                  : profile.companyName[0].toUpperCase(),
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
                                  profile.companyName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.verified) ...[
                                const SizedBox(width: 5),
                                const VerifiedBadge(),
                              ],
                              if (profile.isFeatured) ...[
                                const SizedBox(width: 5),
                                const PlusBadge(),
                              ],
                            ],
                          ),
                          if (profile.location != null)
                            Text(
                              profile.location!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
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
                    _StatColumn(label: 'Fleet', value: '${profile.fleetSize}'),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile.gpsAvailable ? Icons.gps_fixed : Icons.gps_off,
                        size: 14,
                        color: profile.gpsAvailable
                            ? AppColors.statusLive
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.gpsAvailable
                            ? 'GPS connected'
                            : 'No GPS connected',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (profile.locationLat != null &&
                    profile.locationLng != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLabel,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 140,
                      child: IgnorePointer(
                        // Non-interactive — this is a small at-a-glance
                        // preview, not a real map to pan/zoom; a viewer
                        // wanting the interactive one would expect a
                        // dedicated screen, which nothing here links to yet.
                        child: AppMap(
                          initialCenter: LatLng(
                            profile.locationLat!,
                            profile.locationLng!,
                          ),
                          initialZoom: 13,
                          interactive: false,
                          markers: [
                            Marker(
                              point: LatLng(
                                profile.locationLat!,
                                profile.locationLng!,
                              ),
                              width: 36,
                              height: 36,
                              alignment: Alignment.topCenter,
                              child: const AppMapPin(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
                              loadPage: (page) => widget.repository
                                  .companyReviews(widget.companyId, page: page),
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
