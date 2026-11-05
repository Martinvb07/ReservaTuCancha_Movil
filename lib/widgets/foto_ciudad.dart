import 'package:flutter/material.dart';

import '../data/ciudades.dart';

/// Foto de una ciudad, a todo el tamaño de su contenedor. Si no carga, usa
/// [respaldo] (por ejemplo, una cancha de esa ciudad) y, si tampoco, no pinta
/// nada: queda el fondo de quien la contiene.
class FotoCiudad extends StatelessWidget {
  const FotoCiudad({super.key, required this.ciudad, this.respaldo = ''});

  final String ciudad;
  final String respaldo;

  @override
  Widget build(BuildContext context) {
    final propia = kFotoCiudad[ciudad] ?? '';
    final primera = propia.isNotEmpty ? propia : respaldo;
    if (primera.isEmpty) return const SizedBox.shrink();
    return Image.network(
      primera,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) =>
          primera != respaldo && respaldo.isNotEmpty
          ? Image.network(
              respaldo,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            )
          : const SizedBox.shrink(),
    );
  }
}
