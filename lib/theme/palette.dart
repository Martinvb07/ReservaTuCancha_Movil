/// Escalas crudas de Tailwind que la web usa fuera del sistema de tokens.
///
/// La home no se pinta solo con los tokens de shadcn: usa `lime-*` como color
/// de acento y la escala `gray-*` (que NO es la misma que `slate-*` de los
/// tokens). Estan aca, separadas, para no ensuciar tokens.dart.
library;

import 'package:flutter/material.dart';

abstract final class Lime {
  static const c100 = Color(0xFFECFCCB);
  static const c400 = Color(0xFFA3E635); // acento del hero
  static const c500 = Color(0xFF84CC16);
  static const c600 = Color(0xFF65A30D); // titulillos de seccion
}

abstract final class Green {
  static const c50 = Color(0xFFF0FDF4);
  static const c400 = Color(0xFF4ADE80); // el anillo de foco de los inputs
  static const c600 = Color(0xFF16A34A); // marca
  static const c700 = Color(0xFF15803D);
}

abstract final class Gray {
  static const c50 = Color(0xFFF9FAFB);
  static const c100 = Color(0xFFF3F4F6);
  static const c200 = Color(0xFFE5E7EB);
  static const c300 = Color(0xFFD1D5DB);
  static const c400 = Color(0xFF9CA3AF);
  static const c500 = Color(0xFF6B7280);
  static const c600 = Color(0xFF4B5563);
  static const c700 = Color(0xFF374151);
  static const c800 = Color(0xFF1F2937);
  static const c900 = Color(0xFF111827);
}

abstract final class Yellow {
  static const c400 = Color(0xFFFACC15); // estrella del rating
}

/// El acento de la pantalla de bloqueos, de punta a punta.
abstract final class Orange {
  static const c50 = Color(0xFFFFF7ED);
  static const c100 = Color(0xFFFFEDD5);
  static const c200 = Color(0xFFFED7AA);
  static const c400 = Color(0xFFFB923C);
  static const c500 = Color(0xFFF97316);
  static const c600 = Color(0xFFEA580C);
  static const c700 = Color(0xFFC2410C);
  static const c800 = Color(0xFF9A3412);
  static const c900 = Color(0xFF7C2D12);
}

/// Los errores de formulario, el estado "reagendada" y el boton de cerrar
/// sesion. Estaban sueltos en los widgets con el hex a mano.
abstract final class Red {
  static const c50 = Color(0xFFFEF2F2);
  static const c100 = Color(0xFFFEE2E2);
  static const c200 = Color(0xFFFECACA);
  static const c300 = Color(0xFFFCA5A5);
  static const c400 = Color(0xFFF87171);
  static const c500 = Color(0xFFEF4444);
  static const c600 = Color(0xFFDC2626);
  static const c700 = Color(0xFFB91C1C);
}

/// El panel del propietario NO usa la escala `gray` del sitio publico: usa
/// `slate`, que es la de los tokens de shadcn. Son distintas — slate tira a
/// azul y gray es neutra — y mezclarlas se nota en los bordes.
abstract final class Slate {
  static const c50 = Color(0xFFF8FAFC);
  static const c100 = Color(0xFFF1F5F9);
  static const c200 = Color(0xFFE2E8F0);
  static const c300 = Color(0xFFCBD5E1);
  static const c400 = Color(0xFF94A3B8);
  static const c500 = Color(0xFF64748B);
  static const c600 = Color(0xFF475569);
  static const c700 = Color(0xFF334155);
  static const c900 = Color(0xFF0F172A);
}
