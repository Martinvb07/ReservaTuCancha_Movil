import 'package:flutter/material.dart';

/// Los íconos 3D de deporte, los mismos de la web (assets/deportes).
/// [clave]: '' (todos), 'futbol', 'padel', 'voley_playa' o 'cerca'.
class IconoDeporte3D extends StatelessWidget {
  const IconoDeporte3D({super.key, required this.clave, this.size = 30});

  final String clave;
  final double size;

  static const _archivos = {
    '': 'todos',
    'futbol': 'futbol',
    'padel': 'padel',
    'voley_playa': 'voley_playa',
    'cerca': 'cerca',
  };

  static bool tiene(String? clave) => _archivos.containsKey(clave ?? '');

  @override
  Widget build(BuildContext context) {
    final archivo = _archivos[clave] ?? 'todos';
    return Image.asset(
      'assets/deportes/$archivo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
