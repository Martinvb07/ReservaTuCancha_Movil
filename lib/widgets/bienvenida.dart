import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/preferencias.dart';
import '../data/ubicacion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Las tres pantallas de la primera vez. La ubicacion se pide aca, en la
/// ultima, despues de explicar para que sirve: un permiso pedido sin
/// contexto se niega casi siempre.
class Bienvenida extends StatefulWidget {
  const Bienvenida({super.key, required this.onTerminar});

  final VoidCallback onTerminar;

  @override
  State<Bienvenida> createState() => _BienvenidaState();
}

const _paginas = <(IconData, String, String)>[
  (
    LucideIcons.search,
    'Encuentra tu cancha',
    'Fútbol, pádel y vóley playa en clubes de tu ciudad, con fotos, precios '
        'y los horarios libres de hoy.',
  ),
  (
    LucideIcons.calendarCheck,
    'Reserva en segundos',
    'Sin crear cuenta. Pagas con Nequi, PSE, DaviPlata o tarjeta, y te llega '
        'la confirmación al correo.',
  ),
  (
    LucideIcons.mapPin,
    'Canchas cerca de ti',
    'Con tu ubicación te mostramos primero las canchas más cercanas. Solo la '
        'usamos para eso.',
  ),
];

class _BienvenidaState extends State<Bienvenida> {
  final _controller = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _terminar({bool pedirUbicacion = false}) async {
    HapticFeedback.lightImpact();
    await Preferencias.instance.marcarBienvenidaVista();
    if (pedirUbicacion) await Ubicacion.obtener();
    widget.onTerminar();
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _paginas.length - 1;
    return Material(
      color: Gray.c900,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _terminar,
                  child: Text(
                    'Saltar',
                    style: RtcType.sm.copyWith(color: Gray.c400),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _paginas.length,
                  onPageChanged: (i) => setState(() => _pagina = i),
                  itemBuilder: (_, i) {
                    final (icono, titulo, texto) = _paginas[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            color: Lime.c400,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icono, size: 52, color: Gray.c900),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: RtcType.xl2.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          texto,
                          textAlign: TextAlign.center,
                          style: RtcType.base.copyWith(
                            color: Gray.c400,
                            height: 1.45,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _paginas.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _pagina ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _pagina ? Lime.c400 : Gray.c700,
                        borderRadius: RtcRadius.brFull,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: ultima
                    ? () => _terminar(pedirUbicacion: true)
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      ),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Lime.c400,
                    borderRadius: RtcRadius.brFull,
                  ),
                  child: Text(
                    ultima ? 'Activar ubicación y empezar' : 'Siguiente',
                    style: RtcType.base.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c900,
                    ),
                  ),
                ),
              ),
              if (ultima)
                TextButton(
                  onPressed: _terminar,
                  child: Text(
                    'Ahora no',
                    style: RtcType.sm.copyWith(color: Gray.c400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
