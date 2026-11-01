import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Las graficas de `recharts` que usa el panel, dibujadas a mano.
///
/// Se copian sus numeros: rejilla `strokeDasharray="3 3"` en `#f0f0f0`, ejes
/// sin linea, etiquetas de 11px en `#9ca3af`, barras con las esquinas de
/// arriba redondeadas y la dona con `innerRadius 50 / outerRadius 78` y
/// `paddingAngle 3`.
///
/// No se suma una dependencia de graficas por esto: son cuatro formas.

/// `<CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />` y los ejes.
class _Ejes {
  const _Ejes(this.canvas, this.size, this.maximo, this.margenIzq);

  final Canvas canvas;
  final Size size;
  final num maximo;
  final double margenIzq;

  static const margenAbajo = 20.0;

  double get alto => size.height - margenAbajo;

  /// `allowDecimals={false}`: las marcas del eje Y van de a un paso ENTERO, no
  /// dividiendo el maximo en cinco — eso dejaba escaleras como 6, 4, 3, 1, 0.
  /// El paso es el mas chico que deje cinco tramos o menos.
  int get _paso {
    if (maximo <= 5) return 1;
    return (maximo / 5).ceil();
  }

  int get _marcas => (maximo / _paso).ceil();

  /// El tope del eje se redondea hacia arriba al paso, para que la marca de
  /// mas arriba caiga en un numero redondo. Las barras y la linea escalan
  /// contra ESTE valor, no contra el maximo crudo: si no, la barra mas alta
  /// toca el techo y no coincide con ninguna marca.
  double get topeEje => (_paso * _marcas).toDouble();

  void rejilla({String Function(double)? etiqueta}) {
    final linea = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= _marcas; i++) {
      final valor = (_paso * i).toDouble();
      final y = alto - alto * (valor / topeEje);
      for (var x = margenIzq; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), linea);
      }
      texto(etiqueta?.call(valor) ?? '${valor.round()}', Offset(0, y - 6), 11);
    }
  }

  void texto(
    String t,
    Offset donde, [
    double tamano = 11,
    bool centrado = false,
  ]) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: tamano,
          color: Gray.c400,
          fontFamily: RtcType.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      centrado ? Offset(donde.dx - tp.width / 2, donde.dy) : donde,
    );
  }
}

/// `<BarChart>` con `<Bar radius={[6,6,0,0]}>`.
class GraficaBarras extends StatelessWidget {
  const GraficaBarras({
    super.key,
    required this.datos,
    required this.color,
    this.alto = 190,
    this.destacar,
    this.colorDestacado,
    this.saltarEtiquetas = 1,
  });

  /// (etiqueta, valor)
  final List<(String, num)> datos;

  final Color color;
  final double alto;

  /// Indice que va con otro color (la barra de hoy en el Inicio).
  final int? destacar;
  final Color? colorDestacado;

  /// `interval={1}` de las horas: dibuja una etiqueta de cada N.
  final int saltarEtiquetas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PintorBarras(
          datos: datos,
          color: color,
          destacar: destacar,
          colorDestacado: colorDestacado,
          saltar: saltarEtiquetas,
        ),
      ),
    );
  }
}

class _PintorBarras extends CustomPainter {
  _PintorBarras({
    required this.datos,
    required this.color,
    required this.destacar,
    required this.colorDestacado,
    required this.saltar,
  });

  final List<(String, num)> datos;
  final Color color;
  final int? destacar;
  final Color? colorDestacado;
  final int saltar;

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final maximo = datos.fold<num>(0, (m, d) => d.$2 > m ? d.$2 : m);
    final tope = maximo == 0 ? 1 : maximo;
    final ejes = _Ejes(canvas, size, tope, 24);
    ejes.rejilla();

    final paso = (size.width - 24) / datos.length;
    final ancho = (paso * 0.6).clamp(0.0, 40.0);

    for (var i = 0; i < datos.length; i++) {
      final (etiqueta, valor) = datos[i];
      final centro = 24 + paso * i + paso / 2;
      final altura = ejes.alto * (valor / ejes.topeEje);
      if (altura > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              centro - ancho / 2,
              ejes.alto - altura,
              ancho,
              altura,
            ),
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
          ),
          Paint()..color = (i == destacar ? colorDestacado ?? color : color),
        );
      }
      if (i % saltar == 0) {
        ejes.texto(etiqueta, Offset(centro, ejes.alto + 4), 11, true);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorBarras old) => old.datos != datos;
}

/// `<LineChart>` con `<Line strokeWidth={2.5} dot={{ r: 4 }}>`.
class GraficaLinea extends StatelessWidget {
  const GraficaLinea({
    super.key,
    required this.datos,
    required this.color,
    this.alto = 190,
    this.formatoY,
  });

  final List<(String, num)> datos;
  final Color color;
  final double alto;

  /// `tickFormatter` del eje Y.
  final String Function(double)? formatoY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PintorLinea(datos: datos, color: color, formatoY: formatoY),
      ),
    );
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea({
    required this.datos,
    required this.color,
    required this.formatoY,
  });

  final List<(String, num)> datos;
  final Color color;
  final String Function(double)? formatoY;

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final maximo = datos.fold<num>(0, (m, d) => d.$2 > m ? d.$2 : m);
    final tope = maximo == 0 ? 1 : maximo;
    // El eje Y de ingresos lleva textos anchos ("$100K"): mas margen.
    final margen = formatoY == null ? 24.0 : 44.0;
    final ejes = _Ejes(canvas, size, tope, margen);
    ejes.rejilla(etiqueta: formatoY);

    final paso = datos.length == 1
        ? 0.0
        : (size.width - margen - 8) / (datos.length - 1);
    final puntos = <Offset>[];
    for (var i = 0; i < datos.length; i++) {
      final x = datos.length == 1
          ? margen + (size.width - margen) / 2
          : margen + paso * i;
      final y = ejes.alto - ejes.alto * (datos[i].$2 / ejes.topeEje);
      puntos.add(Offset(x, y));
      ejes.texto(datos[i].$1, Offset(x, ejes.alto + 4), 11, true);
    }

    if (puntos.length > 1) {
      final trazo = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (final p in puntos.skip(1)) {
        trazo.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        trazo,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final p in puntos) {
      canvas.drawCircle(p, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PintorLinea old) => old.datos != datos;
}

/// `<PieChart>` con `innerRadius 50`, `outerRadius 78` y `paddingAngle 3`,
/// mas la leyenda de puntitos debajo.
class GraficaDona extends StatelessWidget {
  const GraficaDona({
    super.key,
    required this.datos,
    required this.colores,
    this.alto = 190,
  });

  /// (etiqueta, valor)
  final List<(String, num)> datos;
  final List<Color> colores;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: alto - 30,
          child: CustomPaint(
            size: Size.infinite,
            painter: _PintorDona(datos: datos, colores: colores),
          ),
        ),
        const SizedBox(height: RtcSpace.s2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: RtcSpace.s3,
          runSpacing: 4,
          children: [
            for (var i = 0; i < datos.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colores[i % colores.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    datos[i].$1,
                    style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _PintorDona extends CustomPainter {
  _PintorDona({required this.datos, required this.colores});

  final List<(String, num)> datos;
  final List<Color> colores;

  @override
  void paint(Canvas canvas, Size size) {
    final total = datos.fold<num>(0, (s, d) => s + d.$2);
    if (total == 0) return;

    // `cx="50%" cy="48%"`
    final centro = Offset(size.width / 2, size.height * 0.48);
    const interior = 50.0;
    const exterior = 78.0;
    // `paddingAngle={3}` en grados.
    const separacion = 3 * math.pi / 180;

    var angulo = -math.pi / 2;
    for (var i = 0; i < datos.length; i++) {
      final barrido = (datos[i].$2 / total) * 2 * math.pi - separacion;
      if (barrido > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: centro, radius: (interior + exterior) / 2),
          angulo + separacion / 2,
          barrido,
          false,
          Paint()
            ..color = colores[i % colores.length]
            ..strokeWidth = exterior - interior
            ..style = PaintingStyle.stroke,
        );
      }
      angulo += barrido + separacion;
    }
  }

  @override
  bool shouldRepaint(_PintorDona old) => old.datos != datos;
}

/// `EmptyChart`.
class GraficaVacia extends StatelessWidget {
  const GraficaVacia({super.key, required this.alto});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: Center(
        child: Text(
          'Sin datos suficientes aún',
          style: RtcType.sm.copyWith(color: Gray.c300),
        ),
      ),
    );
  }
}
