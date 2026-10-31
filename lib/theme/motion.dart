import 'package:flutter/material.dart';

/// Curvas y duraciones portadas desde la "capa de movimiento" de globals.css.
///
/// Los cuatro numeros de un `cubic-bezier()` de CSS son exactamente los de un
/// [Cubic] de Flutter, asi que esto es una copia literal: mismo timing, mismo
/// overshoot. Si tocas una animacion en la web, tocala aca.
abstract final class RtcCurves {
  /// `cubic-bezier(.16,1,.3,1)` — la mas usada del sitio: desaceleracion
  /// tipo expo. Sheets, chat, buscador que se despliega.
  static const expoOut = Cubic(0.16, 1.0, 0.30, 1.0);

  /// `cubic-bezier(.2,.8,.3,1)` — dropdowns, items, pin del mapa.
  static const smooth = Cubic(0.20, 0.80, 0.30, 1.0);

  /// `cubic-bezier(.2,.7,.3,1)` — reveal on scroll (`.rtc-fade`).
  static const fadeUp = Cubic(0.20, 0.70, 0.30, 1.0);

  /// `cubic-bezier(.2,.8,.3,1.3)` — el check que entra con rebote.
  static const backOut = Cubic(0.20, 0.80, 0.30, 1.3);

  /// `cubic-bezier(.2,.8,.3,1.2)` — celda de fecha/hora al elegirse.
  static const pickOut = Cubic(0.20, 0.80, 0.30, 1.2);

  /// `cubic-bezier(.4,0,1,1)` — salida del panel del chat (= ease-in de CSS).
  static const chatOut = Cubic(0.40, 0.0, 1.0, 1.0);

  /// `cubic-bezier(.4,0,.7,.25)` — el buscador recogiendose hacia el navbar.
  static const searchCollapse = Cubic(0.40, 0.0, 0.70, 0.25);

  /// `[0.22, 1, 0.36, 1]` — el ease que usa framer-motion en el Navbar:
  /// menu movil, icono de hamburguesa y escalonado de los enlaces.
  static const framerExpo = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Equivalencias exactas de las palabras clave de CSS.
  static const ease = Curves.ease; // cubic-bezier(.25,.1,.25,1)
  static const easeIn = Curves.easeIn; // cubic-bezier(.42,0,1,1)
  static const easeOut = Curves.easeOut; // cubic-bezier(0,0,.58,1)
  static const easeInOut = Curves.easeInOut; // cubic-bezier(.42,0,.58,1)
}

/// Duraciones, con el nombre del keyframe de origen.
abstract final class RtcDur {
  static const fadeUp = Duration(milliseconds: 550); // .rtc-fade
  static const dropIn = Duration(milliseconds: 300); // .rtc-drop
  static const itemIn = Duration(milliseconds: 240); // .rtc-item
  static const pick = Duration(milliseconds: 220); // .rtc-pick
  static const checkIn = Duration(milliseconds: 200); // .check-in
  static const ready = Duration(milliseconds: 2200); // .rtc-ready (infinita)
  static const live = Duration(milliseconds: 2000); // .rtc-live  (infinita)

  static const chatPanelIn = Duration(milliseconds: 400);
  static const chatPanelOut = Duration(milliseconds: 220);
  static const chatBubbleIn = Duration(milliseconds: 340);
  static const chatChipIn = Duration(milliseconds: 300);
  static const chatChipOut = Duration(milliseconds: 160);
  static const chatTyping = Duration(milliseconds: 1150);

  static const sheetIn = Duration(milliseconds: 200); // .mobile-sheet-in
  static const sheetOut = Duration(milliseconds: 180); // STACK_SHEET_EXIT_MS
  static const sheetUp = Duration(milliseconds: 320); // .rtc-sheet-up
  static const mobileFieldIn = Duration(milliseconds: 420);

  static const navSearchIn = Duration(milliseconds: 280);
  static const searchExpand = Duration(milliseconds: 460);
  static const searchOut = Duration(milliseconds: 260);
  static const scrimIn = Duration(milliseconds: 340);
  static const scrimOut = Duration(milliseconds: 240);

  // ── Navbar: menu movil (framer-motion) ──────────────────────────────
  static const menuIcon = Duration(milliseconds: 200); // giro Menu <-> X
  static const menuHeight = Duration(milliseconds: 320); // despliegue del panel
  static const menuFade = Duration(milliseconds: 200);
  static const menuLinksSwap = Duration(milliseconds: 180); // cruce por modo
  static const menuLinkIn = Duration(milliseconds: 280); // entrada de c/ enlace

  /// `delay: 0.04 + i * 0.045` de los enlaces del menu.
  static const menuLinkDelay = Duration(milliseconds: 40);
  static const menuLinkStep = Duration(milliseconds: 45);

  static const pinHover = Duration(milliseconds: 160); // .rtc-pin
  static const fabOpacity = Duration(milliseconds: 220); // .fab-float
  static const fabTransform = Duration(milliseconds: 300);

  /// Retrasos de `.mobile-search-stack > *:nth-child(n)`.
  static const mobileStackDelays = <Duration>[
    Duration(milliseconds: 50),
    Duration(milliseconds: 110),
    Duration(milliseconds: 170),
    Duration(milliseconds: 230),
  ];
}

/// Equivalente de `@media (prefers-reduced-motion: reduce)`, que el sitio ya
/// respeta. Cuando devuelve true hay que saltar la animacion y pintar el
/// estado final, igual que hace el CSS con `animation: none`.
bool rtcReducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;
