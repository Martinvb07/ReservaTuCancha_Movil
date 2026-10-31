import 'package:flutter/material.dart';

/// Escala tipografica de Tailwind portada a Flutter.
///
/// El navegador y Flutter reparten el interlineado distinto, y ese es el
/// motivo numero uno de que un port "se vea raro pero no sepas por que".
/// Dos reglas que aplican todos los estilos de abajo:
///
///   1. `height` es un MULTIPLICADOR, no pixeles. `text-sm` (14px/20px)
///      es `fontSize: 14, height: 20 / 14`.
///   2. `leadingDistribution: even` reparte el sobrante arriba y abajo,
///      como hace CSS. Sin esto todo queda corrido 1-2px hacia abajo.
abstract final class RtcType {
  /// La tipografia del sitio, declarada en pubspec.yaml con sus cinco pesos.
  /// En null caeria a la del sistema (San Francisco en iOS, Roboto en
  /// Android): se ve bien, pero no es la marca.
  static const String fontFamily = 'Geist';

  static const _even = TextLeadingDistribution.even;

  static const xs = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    leadingDistribution: _even,
  );

  /// `text-[0.8rem]` — usado por el boton size="sm".
  static const smAlt = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.8,
    height: 18 / 12.8,
    leadingDistribution: _even,
  );

  static const sm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    leadingDistribution: _even,
  );

  static const base = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16,
    leadingDistribution: _even,
  );

  static const lg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: _even,
  );

  static const xl = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 28 / 20,
    leadingDistribution: _even,
  );

  static const xl2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 32 / 24,
    leadingDistribution: _even,
  );

  static const xl3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    height: 36 / 30,
    leadingDistribution: _even,
  );

  static const xl4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    height: 40 / 36,
    leadingDistribution: _even,
  );

  static const xl5 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    height: 1,
    leadingDistribution: _even,
  );

  // Pesos, con los nombres de Tailwind para que el port sea mecanico.
  static const medium = FontWeight.w500; // font-medium
  static const semibold = FontWeight.w600; // font-semibold
  static const bold = FontWeight.w700; // font-bold
}
