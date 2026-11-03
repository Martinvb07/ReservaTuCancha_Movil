/// Fila de medios de pago que acepta el checkout de ePayco. Port de
/// `Frontend/src/components/bookings/MediosPago.tsx`.
///
/// Van dibujados con widgets, sin imagenes: cargan con el formulario y se ven
/// nitidos en cualquier pantalla.
library;

import 'package:flutter/material.dart';

class MediosPago extends StatelessWidget {
  const MediosPago({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(
          nombre: 'Visa',
          child: _Texto('VISA', Color(0xFF1A1F71), italic: true, size: 12),
        ),
        _Chip(nombre: 'Mastercard', child: _Mastercard()),
        _Chip(nombre: 'Nequi', child: _Nequi()),
        _Chip(nombre: 'PSE', child: _Pse()),
        _Chip(
          nombre: 'DaviPlata',
          child: _Texto('DaviPlata', Color(0xFFED1C27), size: 10),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.nombre, required this.child});

  final String nombre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: nombre,
      // Sin `alignment`: con él el Container se estira a todo el ancho y
      // cada logo quedaba en su propia fila.
      child: Container(
        height: 26,
        constraints: const BoxConstraints(minWidth: 40),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        /* Blanco en los dos modos, como en cualquier checkout: los logos
           son azul marino y casi negro, y sobre la tarjeta oscura se
           perdían (VISA y Nequi desaparecían). */
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(6)),
          border: Border.fromBorderSide(BorderSide(color: Color(0xFFE5E7EB))),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Center(widthFactor: 1, child: ExcludeSemantics(child: child)),
      ),
    );
  }
}

class _Texto extends StatelessWidget {
  const _Texto(
    this.texto,
    this.color, {
    this.italic = false,
    required this.size,
  });

  final String texto;
  final Color color;
  final bool italic;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: size,
        fontWeight: FontWeight.w900,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: color,
        height: 1,
        letterSpacing: italic ? 0.4 : 0,
      ),
    );
  }
}

class _Mastercard extends StatelessWidget {
  const _Mastercard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 16,
      child: Stack(
        children: [
          _circulo(0, const Color(0xFFEB001B)),
          _circulo(10, const Color(0xE6F79E1B)),
        ],
      ),
    );
  }

  Widget _circulo(double left, Color color) => Positioned(
    left: left,
    child: Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

class _Nequi extends StatelessWidget {
  const _Nequi();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 3,
          margin: const EdgeInsets.only(top: 1, right: 1),
          color: const Color(0xFFDA0081),
        ),
        const _Texto('Nequi', Color(0xFF200020), size: 11),
      ],
    );
  }
}

class _Pse extends StatelessWidget {
  const _Pse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1B3A6B),
      ),
      child: const _Texto('pse', Colors.white, italic: true, size: 7.5),
    );
  }
}
