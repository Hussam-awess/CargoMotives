import 'package:cargo_motives/features/reviews/data/review_repository.dart';

class FakeReviewRepository extends ReviewRepository {
  FakeReviewRepository({this.onSubmit});

  final Future<void> Function({required int jobId, required int rating, String? comment, Map<String, int>? categoryRatings})? onSubmit;

  @override
  Future<void> submit({required int jobId, required int rating, String? comment, Map<String, int>? categoryRatings}) {
    return onSubmit?.call(jobId: jobId, rating: rating, comment: comment, categoryRatings: categoryRatings) ?? Future.value();
  }
}
