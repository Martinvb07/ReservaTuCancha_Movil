import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reservatucancha/main.dart';
import 'package:reservatucancha/theme/app_theme.dart';
import 'package:reservatucancha/theme/tokens.dart';
import 'package:reservatucancha/widgets/motion/rtc_motion.dart';

void main() {
  testWidgets('la app abre en el inicio con el buscador y la barra de abajo', (
    tester,
  ) async {
    await tester.pumpWidget(RtcApp());
    // Nada de pumpAndSettle: las entradas escalonadas y RtcLiveDot son
    // infinitas (igual que sus keyframes en CSS) y el arbol nunca queda quieto.
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('¿Partido hoy?'), findsOneWidget);
    expect(find.text('¿Listo para jugar?'), findsOneWidget);
    // La pestaña activa de la barra inferior es la unica que muestra su
    // nombre.
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
  });

  test('el tema usa los tokens de la web, no los de Material', () {
    // Si alguien "arregla" un color a ojo, esto lo caza.
    expect(RtcTheme.light.colorScheme.primary, RtcLight.primary);
    expect(RtcTheme.dark.colorScheme.primary, RtcDark.primary);
    expect(RtcTheme.light.scaffoldBackgroundColor, RtcLight.background);
  });

  test('el radio lg sale de --radius y no del default de Tailwind', () {
    // La web sobrescribe rounded-lg a 0.625rem = 10px; Tailwind trae 8px.
    expect(RtcRadius.lg, 10);
    expect(RtcRadius.xl, 12);
  });

  testWidgets('las animaciones liberan su controller al desmontarse', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RtcLiveDot())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Reemplazar el arbol dispara dispose(); si faltara, el ticker quedaria
    // vivo y el test fallaria con "was disposed with an active Ticker".
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpAndSettle();
  });
}
