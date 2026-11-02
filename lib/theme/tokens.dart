/// Tokens de diseno portados 1:1 desde el sitio web.
///
/// Fuente: `Frontend/src/app/globals.css` (variables `--*`) y
/// `Frontend/tailwind.config.ts`. Los HSL de shadcn ya vienen convertidos a
/// RGB; si cambias un token en la web, cambialo aca y no en los widgets.
library;

import 'package:flutter/material.dart';

/// Paleta clara — bloque `:root` de globals.css.
abstract final class RtcLight {
  static const background = Color(0xFFFFFFFF); // 0 0% 100%
  static const foreground = Color(0xFF020817); // 222.2 84% 4.9%
  static const card = Color(0xFFFFFFFF);
  static const cardForeground = Color(0xFF020817);
  static const popover = Color(0xFFFFFFFF);
  static const popoverForeground = Color(0xFF020817);
  static const primary = Color(0xFF16A34A); // 142.1 76.2% 36.3% — green-600
  static const primaryForeground = Color(0xFFFFF1F2); // 355.7 100% 97.3%
  static const secondary = Color(0xFFF1F5F9); // 210 40% 96.1%
  static const secondaryForeground = Color(0xFF0F172A); // 222.2 47.4% 11.2%
  static const muted = Color(0xFFF1F5F9);
  static const mutedForeground = Color(0xFF64748B); // 215.4 16.3% 46.9%
  static const accent = Color(0xFFF1F5F9);
  static const accentForeground = Color(0xFF0F172A);
  static const destructive = Color(0xFFEF4444); // 0 84.2% 60.2%
  static const destructiveForeground = Color(0xFFF8FAFC); // 210 40% 98%
  static const border = Color(0xFFE2E8F0); // 214.3 31.8% 91.4%
  static const input = Color(0xFFE2E8F0);
  static const ring = Color(0xFF16A34A);
}

/// Paleta oscura — bloque `.dark` de globals.css.
abstract final class RtcDark {
  /* Los mismos fondos de la paleta en modo oscuro (Fondo.app y
     Superficie.tarjeta), para que diálogos y hojas de Material calcen. */
  static const background = Color(0xFF0E1311);
  static const foreground = Color(0xFFF3F5F4);
  static const card = Color(0xFF161C1A);
  static const cardForeground = Color(0xFFF3F5F4);
  static const popover = Color(0xFF161C1A);
  static const popoverForeground = Color(0xFFF8FAFC);
  static const primary = Color(0xFF22C55E); // 142.1 70.6% 45.3% — green-500
  static const primaryForeground = Color(0xFF052E16); // 144.9 80.4% 10%
  static const secondary = Color(0xFF1C2321);
  static const secondaryForeground = Color(0xFFF8FAFC);
  static const muted = Color(0xFF1C2321);
  static const mutedForeground = Color(0xFF9AA29F);
  static const accent = Color(0xFF1C2321);
  static const accentForeground = Color(0xFFF8FAFC);
  static const destructive = Color(0xFF7F1D1D); // 0 62.8% 30.6%
  static const destructiveForeground = Color(0xFFF8FAFC);
  static const border = Color(0xFF2A322F);
  static const input = Color(0xFF2A322F);
  static const ring = Color(0xFF15803D); // 142.4 71.8% 29.2%
}

/// Colores que el CSS usa en crudo (fuera del sistema de tokens), sobre todo
/// en el mapa y en las sombras de marca.
abstract final class RtcBrand {
  static const green600 = Color(0xFF16A34A);
  static const green700 = Color(0xFF15803D);
  static const gray900 = Color(0xFF111827); // pin activo del mapa
  static const gray700 = Color(0xFF374151); // boton de cierre del popup
  static const zinc300 = Color(0xFFD4D4D8); // scrollbar del chat
  static const zinc400 = Color(0xFFA1A1AA);
  static const mapBackground = Color(0xFFEEF1F5); // .leaflet-container
}

/// Radios. Ojo: la web sobrescribe `lg/md/sm` con `--radius: 0.625rem`, pero
/// `xl`, `xxl` y `full` siguen siendo los de Tailwind por defecto.
abstract final class RtcRadius {
  static const double sm = 6; // calc(var(--radius) - 4px)
  static const double md = 8; // calc(var(--radius) - 2px)
  static const double lg = 10; // var(--radius) = 0.625rem
  static const double xl = 12; // rounded-xl (Card)
  static const double xxl = 16; // rounded-2xl (HeroSearch, popup del mapa)
  static const double full = 9999;

  static const brSm = BorderRadius.all(Radius.circular(sm));
  static const brMd = BorderRadius.all(Radius.circular(md));
  static const brLg = BorderRadius.all(Radius.circular(lg));
  static const brXl = BorderRadius.all(Radius.circular(xl));
  static const brXxl = BorderRadius.all(Radius.circular(xxl));
  static const brFull = BorderRadius.all(Radius.circular(full));
}

/// Escala de espaciado de Tailwind: 1 unidad = 4px. Un logical pixel de
/// Flutter equivale a un CSS px, asi que `p-4` => `RtcSpace.x(4)` = 16.
abstract final class RtcSpace {
  static const double unit = 4;
  static double x(double n) => n * unit;

  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s7 = 28; // space-y-7 del formulario de login
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
}
