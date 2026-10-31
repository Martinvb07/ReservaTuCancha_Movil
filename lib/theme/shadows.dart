import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'tokens.dart';

/// Convierte un `box-shadow` de CSS a un [BoxShadow] de Flutter.
///
/// Las dos plataformas NO miden el desenfoque igual y por eso copiar los
/// numeros tal cual deja todas las sombras mas difusas de lo que deberian:
///
///   * CSS:     sigma = blur / 2
///   * Flutter: sigma = blurRadius * 0.57735 + 0.5
///
/// Igualando ambas queda `blurRadius = (blur / 2 - 0.5) / 0.57735`, que es
/// lo que hace esta funcion. Pasa siempre el valor tal como esta en el CSS.
BoxShadow cssShadow({
  double dx = 0,
  double dy = 0,
  double blur = 0,
  double spread = 0,
  required Color color,
}) {
  final sigma = blur / 2;
  final blurRadius = math.max(0.0, (sigma - 0.5) / 0.57735);
  return BoxShadow(
    color: color,
    offset: Offset(dx, dy),
    blurRadius: blurRadius,
    spreadRadius: spread,
  );
}

/// Sombras que ya existen en el sitio, con su origen anotado.
abstract final class RtcShadows {
  /// `.rtc-card` en reposo — globals.css
  static List<BoxShadow> get card => [
    cssShadow(dy: 2, blur: 10, color: Colors.black.withValues(alpha: 0.05)),
  ];

  /// `.rtc-card:hover`. En movil no hay hover: usalo como estado *presionado*
  /// o para la tarjeta destacada, no como reaccion al dedo que pasa.
  static List<BoxShadow> get cardRaised => [
    cssShadow(dy: 22, blur: 50, color: Colors.black.withValues(alpha: 0.13)),
  ];

  /// `rtc-searchReady` — reposo del boton que "respira".
  static List<BoxShadow> get readyLow => [
    cssShadow(
      dy: 4,
      blur: 16,
      color: RtcBrand.green600.withValues(alpha: 0.40),
    ),
  ];

  /// `rtc-searchReady` — pico del ciclo (50%).
  static List<BoxShadow> get readyHigh => [
    cssShadow(
      dy: 8,
      blur: 26,
      color: RtcBrand.green600.withValues(alpha: 0.65),
    ),
  ];

  /// `.rtc-pin` — pildora de precio del mapa.
  static List<BoxShadow> get mapPin => [
    cssShadow(dy: 2, blur: 8, color: Colors.black.withValues(alpha: 0.20)),
  ];

  /// `.rtc-map-popup` — ficha de la cancha sobre el mapa.
  static List<BoxShadow> get mapPopup => [
    cssShadow(dy: 12, blur: 32, color: Colors.black.withValues(alpha: 0.22)),
  ];

  /// `cardShadow` de MobileStackSheet — seccion activa del sheet.
  static List<BoxShadow> get sheetCard => [
    cssShadow(
      dy: 10,
      blur: 36,
      color: const Color(0xFF141E16).withValues(alpha: 0.16),
    ),
  ];

  /// `rowShadow` de MobileStackSheet — filas colapsadas.
  static List<BoxShadow> get sheetRow => [
    cssShadow(
      dy: 2,
      blur: 16,
      color: const Color(0xFF141E16).withValues(alpha: 0.10),
    ),
  ];

  /// Thumb del slider de precio — `.price-thumb::-webkit-slider-thumb`.
  static List<BoxShadow> get priceThumb => [
    cssShadow(dy: 2, blur: 8, color: RtcBrand.green600.withValues(alpha: 0.40)),
  ];
}
