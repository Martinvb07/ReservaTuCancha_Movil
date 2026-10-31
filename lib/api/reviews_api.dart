/// `reviews.controller.ts`: solo dos rutas y las dos son publicas.
library;

import '../models/review.dart';
import 'rtc_api.dart';

class ReviewsApi {
  const ReviewsApi();

  /// `GET /reviews/court/:courtId`.
  ///
  /// La web lo pide sin cache a proposito: una resena recien publicada tiene
  /// que verse al volver a la ficha.
  Future<List<Review>> byCourt(String courtId) async {
    final data = await RtcApi.instance.get('/reviews/court/$courtId');
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Review.fromJson)
            .toList() ??
        const [];
  }

  /// `POST /reviews`. NO lleva courtId ni nombre: el backend los saca del
  /// `reviewToken`, que llega en el correo posterior al partido y se puede
  /// usar una sola vez (`reviews.service.ts:31`). O sea que resenar, igual que
  /// cancelar y reprogramar, se entra desde el link del correo.
  Future<void> create({
    required String reviewToken,
    required int rating,
    String? comment,
  }) => RtcApi.instance.post(
    '/reviews',
    body: {
      'reviewToken': reviewToken,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    },
  );
}

const reviewsApi = ReviewsApi();
