/// Escalas crudas de Tailwind que la web usa fuera del sistema de tokens.
///
/// La home no se pinta solo con los tokens de shadcn: usa `lime-*` como color
/// de acento y la escala `gray-*` (que NO es la misma que `slate-*` de los
/// tokens). Estan aca, separadas, para no ensuciar tokens.dart.
library;

import 'package:flutter/material.dart';

/// Modo de color actual. Lo fija la app según el modo del teléfono
/// (`RtcApp`), y las escalas de abajo devuelven el tono que corresponde: los
/// fondos claros pasan a oscuros y los textos oscuros a claros. Los tonos
/// medios (400-600) son iguales en los dos modos.
abstract final class RtcModo {
  static bool oscuro = false;
}

/// Superficies que en claro son blancas: tarjetas, hojas, diálogos.
abstract final class Superficie {
  static Color get tarjeta =>
      RtcModo.oscuro ? const Color(0xFF161C1A) : const Color(0xFFFFFFFF);
}

/// Grises que NO cambian con el modo: los bloques que son oscuros siempre
/// (héroes, botones negros) y el texto oscuro sobre fondos de color fijos
/// (verde lima, amarillo).
abstract final class GrisFijo {
  // Claros: textos sobre los bloques oscuros fijos.
  static const c200 = Color(0xFFE5E7EB);
  static const c300 = Color(0xFFD1D5DB);
  static const c400 = Color(0xFF9CA3AF);
  static const c500 = Color(0xFF6B7280);
  static const c700 = Color(0xFF374151);
  static const c800 = Color(0xFF1F2937);
  static const c900 = Color(0xFF111827);
}

/// Superficies de la app. El fondo es un gris apenas verdoso: las tarjetas
/// blancas flotan sobre el sin necesitar bordes.
abstract final class Fondo {
  static Color get app =>
      RtcModo.oscuro ? const Color(0xFF0E1311) : const Color(0xFFF1F4F2);

  /// Lo que va encima del fondo en reposo: chips, botones circulares.
  static Color get suave =>
      RtcModo.oscuro ? const Color(0xFF1C2421) : const Color(0xFFE6EBE8);
}

abstract final class Lime {
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF283E10) : const Color(0xFFECFCCB);
  static const c400 = Color(0xFFA3E635); // acento del hero
  static const c500 = Color(0xFF84CC16);
  static const c600 = Color(0xFF65A30D); // titulillos de seccion
}

abstract final class Green {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF0F291A) : const Color(0xFFF0FDF4);
  static const c400 = Color(0xFF4ADE80); // el anillo de foco de los inputs
  static const c600 = Color(0xFF16A34A); // marca
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF10341E) : const Color(0xFFDCFCE7);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF114425) : const Color(0xFFBBF7D0);
  static Color get c300 =>
      RtcModo.oscuro ? const Color(0xFF68B885) : const Color(0xFF86EFAC);
  static const c500 = Color(0xFF22C55E);
  static Color get c800 =>
      RtcModo.oscuro ? const Color(0xFFBBF7D0) : const Color(0xFF166534);
  static Color get c900 =>
      RtcModo.oscuro ? const Color(0xFFDCFCE7) : const Color(0xFF14532D);
  static Color get c950 =>
      RtcModo.oscuro ? const Color(0xFFF0FDF4) : const Color(0xFF052E16);
}

abstract final class Gray {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF131917) : const Color(0xFFF9FAFB);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF1C2321) : const Color(0xFFF3F4F6);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF2A322F) : const Color(0xFFE5E7EB);
  static Color get c300 =>
      RtcModo.oscuro ? const Color(0xFF3B4441) : const Color(0xFFD1D5DB);
  static Color get c400 =>
      RtcModo.oscuro ? const Color(0xFF6B7471) : const Color(0xFF9CA3AF);
  static Color get c500 =>
      RtcModo.oscuro ? const Color(0xFF9AA29F) : const Color(0xFF6B7280);
  static Color get c600 =>
      RtcModo.oscuro ? const Color(0xFFB9C0BD) : const Color(0xFF4B5563);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFD3D8D6) : const Color(0xFF374151);
  static Color get c800 =>
      RtcModo.oscuro ? const Color(0xFFE5E8E7) : const Color(0xFF1F2937);
  static Color get c900 =>
      RtcModo.oscuro ? const Color(0xFFF3F5F4) : const Color(0xFF111827);
}

abstract final class Yellow {
  static const c400 = Color(0xFFFACC15); // estrella del rating
}

/// El acento de la pantalla de bloqueos, de punta a punta.
abstract final class Orange {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF321C10) : const Color(0xFFFFF7ED);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF44210F) : const Color(0xFFFFEDD5);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF5F280F) : const Color(0xFFFED7AA);
  static const c400 = Color(0xFFFB923C);
  static const c500 = Color(0xFFF97316);
  static const c600 = Color(0xFFEA580C);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFEABCAA) : const Color(0xFFC2410C);
  static Color get c800 =>
      RtcModo.oscuro ? const Color(0xFFFED7AA) : const Color(0xFF9A3412);
  static Color get c900 =>
      RtcModo.oscuro ? const Color(0xFFFFEDD5) : const Color(0xFF7C2D12);
}

/// Los errores de formulario, el estado "reagendada" y el boton de cerrar
/// sesion. Estaban sueltos en los widgets con el hex a mano.
abstract final class Red {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF301513) : const Color(0xFFFEF2F2);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF411614) : const Color(0xFFFEE2E2);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF5B1716) : const Color(0xFFFECACA);
  static Color get c300 =>
      RtcModo.oscuro ? const Color(0xFFC08080) : const Color(0xFFFCA5A5);
  static const c400 = Color(0xFFF87171);
  static const c500 = Color(0xFFEF4444);
  static const c600 = Color(0xFFDC2626);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
}

/// El panel del propietario NO usa la escala `gray` del sitio publico: usa
/// `slate`, que es la de los tokens de shadcn. Son distintas — slate tira a
/// azul y gray es neutra — y mezclarlas se nota en los bordes.
abstract final class Slate {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF131917) : const Color(0xFFF8FAFC);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF1C2321) : const Color(0xFFF1F5F9);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF2A322F) : const Color(0xFFE2E8F0);
  static Color get c300 =>
      RtcModo.oscuro ? const Color(0xFF3B4441) : const Color(0xFFCBD5E1);
  static Color get c400 =>
      RtcModo.oscuro ? const Color(0xFF6B7471) : const Color(0xFF94A3B8);
  static Color get c500 =>
      RtcModo.oscuro ? const Color(0xFF9AA29F) : const Color(0xFF64748B);
  static Color get c600 =>
      RtcModo.oscuro ? const Color(0xFFB9C0BD) : const Color(0xFF475569);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFD3D8D6) : const Color(0xFF334155);
  static Color get c900 =>
      RtcModo.oscuro ? const Color(0xFFF3F5F4) : const Color(0xFF0F172A);
}

abstract final class Emerald {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF0C2D23) : const Color(0xFFECFDF5);
  static const c400 = Color(0xFF34D399);
  static const c500 = Color(0xFF10B981);
  static const c600 = Color(0xFF059669);
}

abstract final class Amber {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF2F200F) : const Color(0xFFFFFBEB);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF40260F) : const Color(0xFFFEF3C7);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF59300D) : const Color(0xFFFDE68A);
  static const c400 = Color(0xFFFBBF24);
  static const c500 = Color(0xFFF59E0B);
  static const c600 = Color(0xFFD97706);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFE5C3A9) : const Color(0xFFB45309);
  static Color get c800 =>
      RtcModo.oscuro ? const Color(0xFFFDE68A) : const Color(0xFF92400E);
  static Color get c900 =>
      RtcModo.oscuro ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);
}

abstract final class Blue {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF111F39) : const Color(0xFFEFF6FF);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF12254D) : const Color(0xFFDBEAFE);
  static Color get c200 =>
      RtcModo.oscuro ? const Color(0xFF152E6B) : const Color(0xFFBFDBFE);
  static const c400 = Color(0xFF60A5FA);
  static const c500 = Color(0xFF3B82F6);
  static const c600 = Color(0xFF2563EB);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFB0C1F1) : const Color(0xFF1D4ED8);
  static Color get c800 =>
      RtcModo.oscuro ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF);
}

abstract final class Purple {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF241637) : const Color(0xFFFAF5FF);
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF30184A) : const Color(0xFFF3E8FF);
  static const c600 = Color(0xFF9333EA);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFD2B2EE) : const Color(0xFF7E22CE);
}

abstract final class Indigo {
  static Color get c50 =>
      RtcModo.oscuro ? const Color(0xFF1B1D3B) : const Color(0xFFEEF2FF);
  static const c500 = Color(0xFF6366F1);
  static const c600 = Color(0xFF4F46E5);
}

abstract final class Sky {
  static Color get c100 =>
      RtcModo.oscuro ? const Color(0xFF0B2D3C) : const Color(0xFFE0F2FE);
  static Color get c700 =>
      RtcModo.oscuro ? const Color(0xFFA7CADE) : const Color(0xFF0369A1);
}
