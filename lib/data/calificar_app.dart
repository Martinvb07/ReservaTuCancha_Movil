/// Pide calificar la app en la tienda, en un buen momento y sin insistir.
///
/// Se pide después de un pago confirmado o de una reseña de 4 o 5 estrellas
/// (alguien contento), y como mucho una vez cada 120 días. Además Google y
/// Apple tienen su propio límite: a veces la ventana no aparece, y está bien.
library;

import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalificarApp {
  CalificarApp._();

  static const _kUltimaVez = 'calificar.ultimaVez';
  static const _kMomentos = 'calificar.momentos';
  static const _espera = Duration(days: 120);

  /// Un momento bueno. A partir del segundo se pide: la primera reserva
  /// todavía es muy pronto para opinar de la app.
  static Future<void> momentoFeliz() async {
    try {
      final p = await SharedPreferences.getInstance();
      final momentos = (p.getInt(_kMomentos) ?? 0) + 1;
      await p.setInt(_kMomentos, momentos);
      if (momentos < 2) return;

      final ultima = DateTime.tryParse(p.getString(_kUltimaVez) ?? '');
      if (ultima != null && DateTime.now().difference(ultima) < _espera) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await p.setString(_kUltimaVez, DateTime.now().toIso8601String());
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await review.requestReview();
    } catch (_) {
      // Nunca vale romper una pantalla por esto.
    }
  }
}
