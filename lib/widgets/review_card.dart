import 'package:flutter/material.dart';

import '../models/review.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'star_rating.dart';

/// Port de `Frontend/src/components/reviews/ReviewCard.tsx`.
///
/// Ojo: no usa `StarRating`. Dibuja sus propias estrellas con
/// `fill-gray-100 text-gray-200` en las vacias, que no es el vacio del
/// componente compartido (`fill-muted text-muted-foreground`).
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar: w-9 h-9 rounded-full bg-green-600, inicial en blanco.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Green.c600,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  review.initial,
                  style: RtcType.sm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.guestName,
                      style: RtcType.sm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                      ),
                    ),
                    const SizedBox(height: 2), // mt-0.5
                    Text(
                      relativeEs(review.createdAt),
                      style: RtcType.xs.copyWith(color: Gray.c500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              StarRating(
                value: review.rating,
                size: StarSize.review,
                emptyFill: Gray.c100,
                emptyStroke: Gray.c200,
              ),
            ],
          ),
          if (review.comment != null) ...[
            const SizedBox(height: RtcSpace.s3),
            // `pl-12 border-l-2 border-green-100`
            Container(
              padding: const EdgeInsets.only(left: 48),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Green.c100, width: 2)),
              ),
              child: Text(
                review.comment!,
                style: RtcType.sm.copyWith(color: Gray.c600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `formatDistanceToNow(date, { addSuffix: true, locale: es })` de date-fns.
///
/// Los cortes son los de date-fns, no aproximaciones: el mismo minuto exacto
/// tiene que dar el mismo texto que en la web.
String relativeEs(DateTime date) {
  final seconds = DateTime.now().difference(date).inSeconds;
  if (seconds < 0) return 'en un momento';

  final minutes = seconds / 60;
  if (seconds < 30) return 'hace menos de un minuto';
  if (minutes < 1.5) return 'hace 1 minuto';
  if (minutes < 45) return 'hace ${minutes.round()} minutos';
  if (minutes < 90) return 'hace alrededor de 1 hora';

  final hours = minutes / 60;
  if (hours < 24) return 'hace alrededor de ${hours.round()} horas';
  if (hours < 42) return 'hace 1 día';

  final days = hours / 24;
  if (days < 30) return 'hace ${days.round()} días';
  if (days < 45) return 'hace alrededor de 1 mes';
  if (days < 60) return 'hace 2 meses';

  final months = days / 30;
  if (days < 365) return 'hace ${months.round()} meses';

  // date-fns: entre 1 y 1.25 años dice "alrededor de N anios", despues
  // "mas de N" y cerca del salto "casi N+1". Se queda en el caso comun.
  final years = days / 365;
  if (years < 1.25) return 'hace alrededor de 1 año';
  return 'hace ${years.floor()} años';
}
