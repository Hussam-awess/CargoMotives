import '../../../core/network/api_client.dart';

/// Two-way ratings (Phase: ratings) — submits one side of a completed
/// job's rating (JobReviewController::store()). A job produces at most two
/// reviews (one per direction); the backend rejects a second submission
/// from the same rater with a clean validation error.
class ReviewRepository {
  ReviewRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> submit({required int jobId, required int rating, String? comment, Map<String, int>? categoryRatings}) {
    return _client.post(
      '/jobs/$jobId/reviews',
      data: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (categoryRatings != null) 'category_ratings': categoryRatings,
      },
    );
  }
}
