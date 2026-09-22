import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import 'data/bid_repository.dart';
import 'data/job_repository.dart';
import 'job_geo.dart';

/// "Truck details" (mockup) — a fuller view of one bid's transporter,
/// reached by tapping a bid card on Shipment Details. Real data only:
/// company name/verified/rating/rating-count/truck-count/GPS availability
/// all come from BidCompany, and the offer summary (route, pickup, price)
/// from the real Job/Bid. The mockup also shows per-truck trip count and
/// an on-time percentage — this app tracks neither at the truck or bid
/// level, so they're left out rather than invented; the rating and rating
/// count already carry the real trust signal this app actually has.
class TruckDetailsScreen extends StatelessWidget {
  const TruckDetailsScreen({
    super.key,
    required this.job,
    required this.bid,
    required this.onAccept,
  });

  final Job job;
  final Bid bid;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final company = bid.company;
    final distanceKm =
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE4E6E9), Color(0xFFEDEEF0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_shipping_outlined,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (bid.isPriority) ...[
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: company.name,
                              style: TextStyle(
                                fontFamily: 'Barlow Condensed',
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (company.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 13,
                              color: AppColors.statusLive,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.statusLive,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          // "New" (not "0.0"/"—") for a not-yet-rated
                          // company — 0 reviews isn't the same signal as a
                          // genuinely low rating. Matches RatingStars'/
                          // _BidCard's convention elsewhere.
                          value: company.rating != null
                              ? company.rating!.toStringAsFixed(1)
                              : 'New',
                          label: 'Rating',
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.border),
                      Expanded(
                        child: _Stat(
                          value: '${company.ratingCount}',
                          label: 'Ratings',
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.border),
                      Expanded(
                        child: _Stat(
                          value: '${company.truckCount}',
                          label: 'Verified trucks',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoTint,
                    border: Border.all(color: const Color(0xFFD6EBFF)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
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
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          company.gpsAvailable
                              ? 'Live GPS Available'
                              : 'GPS Tracking Not Available',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ctaBluePressed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'THIS OFFER',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLabel,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _Row(
                        label: 'Route',
                        value: '${job.pickupAddress} → ${job.dropoffAddress}',
                      ),
                      if (distanceKm != null)
                        _Row(
                          label: 'Distance',
                          value: '${distanceKm.toStringAsFixed(0)} km',
                        ),
                      _Row(
                        label: 'Pickup',
                        value: DateFormat(
                          'd MMM, HH:mm',
                        ).format(job.preferredPickupWindowStart),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 12,
                        ),
                        color: AppColors.surfaceSubtle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Proposed price',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${job.currency} ${bid.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontFamily: 'Barlow Condensed',
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (bid.note != null && bid.note!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bid.note!,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (job.isOpen && bid.status == 'pending')
                  ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('ACCEPT OFFER'),
                  )
                else
                  Text(
                    bid.status,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.background)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
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
    );
  }
}
