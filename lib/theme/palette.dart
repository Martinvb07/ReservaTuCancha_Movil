/// Escalas crudas de Tailwind que la web usa fuera del sistema de tokens.
///
/// La home no se pinta solo con los tokens de shadcn: usa `lime-*` como color
/// de acento y la escala `gray-*` (que NO es la misma que `slate-*` de los
/// tokens). Estan aca, separadas, para no ensuciar tokens.dart.
library;

import 'package:flutter/material.dart';

/// Superficies de la app. El fondo es un gris apenas verdoso: las tarjetas
/// blancas flotan sobre el sin necesitar bordes.
abstract final class Fondo {
  static const app = Color(0xFFF1F4F2);

  /// Lo que va encima del fondo en reposo: chips, botones circulares.
  static const suave = Color(0xFFE6EBE8);
}

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
  static const c100 = Color(0xFFDCFCE7);
  static const c200 = Color(0xFFBBF7D0);
  static const c300 = Color(0xFF86EFAC);
  static const c500 = Color(0xFF22C55E);
  static const c800 = Color(0xFF166534);
  static const c900 = Color(0xFF14532D);
  static const c950 = Color(0xFF052E16);
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

abstract final class Emerald {
  static const c50 = Color(0xFFECFDF5);
  static const c400 = Color(0xFF34D399);
  static const c500 = Color(0xFF10B981);
  static const c600 = Color(0xFF059669);
}

abstract final class Amber {
  static const c50 = Color(0xFFFFFBEB);
  static const c100 = Color(0xFFFEF3C7);
  static const c200 = Color(0xFFFDE68A);
  static const c400 = Color(0xFFFBBF24);
  static const c500 = Color(0xFFF59E0B);
  static const c600 = Color(0xFFD97706);
  static const c700 = Color(0xFFB45309);
  static const c800 = Color(0xFF92400E);
  static const c900 = Color(0xFF78350F);
}

abstract final class Blue {
  static const c50 = Color(0xFFEFF6FF);
  static const c100 = Color(0xFFDBEAFE);
  static const c200 = Color(0xFFBFDBFE);
  static const c400 = Color(0xFF60A5FA);
  static const c500 = Color(0xFF3B82F6);
  static const c600 = Color(0xFF2563EB);
  static const c700 = Color(0xFF1D4ED8);
  static const c800 = Color(0xFF1E40AF);
}

abstract final class Purple {
  static const c50 = Color(0xFFFAF5FF);
  static const c100 = Color(0xFFF3E8FF);
  static const c600 = Color(0xFF9333EA);
  static const c700 = Color(0xFF7E22CE);
}

abstract final class Indigo {
  static const c50 = Color(0xFFEEF2FF);
  static const c500 = Color(0xFF6366F1);
  static const c600 = Color(0xFF4F46E5);
}

abstract final class Sky {
  static const c100 = Color(0xFFE0F2FE);
  static const c700 = Color(0xFF0369A1);
}
