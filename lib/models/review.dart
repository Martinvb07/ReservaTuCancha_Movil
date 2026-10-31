/// Espeja `Review` de `Frontend/src/types/user.types.ts`, tal como la devuelve
/// `GET /reviews/court/:courtId`.
library;

class Review {
  const Review({
    required this.id,
    required this.guestName,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String guestName;

  /// 1 a 5.
  final int rating;

  final DateTime createdAt;
  final String? comment;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: (json['_id'] as String?) ?? '',
    guestName: (json['guestName'] as String?) ?? 'Anonimo',
    rating: (json['rating'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
        DateTime.now(),
    comment: (json['comment'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['comment'] as String).trim(),
  );

  /// La inicial del avatar, como `guestName.charAt(0).toUpperCase()`.
  String get initial =>
      guestName.isEmpty ? '?' : guestName.substring(0, 1).toUpperCase();
}
