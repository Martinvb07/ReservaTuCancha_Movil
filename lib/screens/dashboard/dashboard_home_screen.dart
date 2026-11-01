import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../auth/session.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/owner_home_widgets.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/motion/rtc_pressable.dart';

/// Port de la rama de PROPIETARIO de
/// `Frontend/src/app/dashboard/page.tsx` (la de admin no se porta).
///
/// La web la arma en el servidor con el token de la sesion; aca la peticion
/// sale del telefono con el mismo token, ya firmada por `RtcApi`.
class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  OwnerStats? _stats;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final stats = await ownerApi.stats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _cargando = false;
      });
    } on RtcApiException {
      if (!mounted) return;
      // La web deja `stats` en null y muestra el aviso ambar, sin romper la
      // pagina: los KPI quedan en cero.
      setState(() {
        _stats = null;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = RtcSession.instance.user?.name.split(' ').first ?? '';
    final s = _stats;

    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _saludo(nombre),
          const SizedBox(height: RtcSpace.s8),
          if (!_cargando && s == null) ...[
            _avisoSinDatos(),
            const SizedBox(height: RtcSpace.s8),
          ],
          _kpis(s),
          const SizedBox(height: RtcSpace.s8),
          _accesos(),
          const SizedBox(height: RtcSpace.s8),
          // La mitad de abajo del Inicio de la web.
          const OwnerHomeWidgets(),
        ],
      ),
    );
  }

  Widget _saludo(String nombre) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panel propietario',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hola, $nombre',
          style: RtcType.xl3.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Resumen de tus canchas y reservas',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  /// El bloque ambar de la web, con el borde grueso a la izquierda.
  Widget _avisoSinDatos() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s6),
      decoration: const BoxDecoration(
        color: Amber.c50,
        border: Border(
          left: BorderSide(color: Amber.c500, width: 4), // amber-500
        ),
        borderRadius: BorderRadius.all(Radius.circular(RtcRadius.md)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.triangleAlert, size: 24, color: Amber.c600),
          ),
          const SizedBox(width: RtcSpace.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No se pudieron cargar los datos',
                  style: RtcType.base.copyWith(
                    fontWeight: RtcType.bold,
                    color: Amber.c900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa tu conexión y desliza hacia abajo para reintentar.',
                  style: RtcType.sm.copyWith(color: Amber.c700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `grid-cols-2` en movil.
  Widget _kpis(OwnerStats? s) {
    final kpis = <(String, String, IconData, Color, Color)>[
      (
        'Reservas totales',
        '${s?.totalBookings ?? 0}',
        LucideIcons.calendarDays,
        Blue.c600,
        Blue.c50,
      ),
      (
        'Confirmadas',
        '${s?.confirmedBookings ?? 0}',
        LucideIcons.circleCheck,
        Green.c600,
        Green.c50,
      ),
      (
        // `$${(totalRevenue/1000).toFixed(0)}K`
        'Ingresos',
        '\$${((s?.totalRevenue ?? 0) / 1000).round()}K',
        LucideIcons.dollarSign,
        Emerald.c600,
        Emerald.c50,
      ),
      (
        'Mis canchas',
        '${s?.totalCourts ?? 0}',
        LucideIcons.building2,
        Purple.c600,
        Purple.c50,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtcSpace.s4,
        mainAxisSpacing: RtcSpace.s4,
        mainAxisExtent: 108,
      ),
      itemBuilder: (context, i) {
        final (titulo, valor, icono, color, fondo) = kpis[i];
        return RtcFadeUp(
          delay: Duration(milliseconds: i * 60),
          child: Container(
            padding: const EdgeInsets.all(RtcSpace.s5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: RtcRadius.brXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: RtcType.xs.copyWith(
                          color: Gray.c500,
                          fontWeight: RtcType.semibold,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: fondo,
                        borderRadius: RtcRadius.brLg,
                      ),
                      child: Icon(icono, size: 16, color: color),
                    ),
                  ],
                ),
                const Spacer(),
                _cargando
                    ? RtcSkeletonPulse(
                        child: Container(
                          height: 24,
                          width: 64,
                          decoration: BoxDecoration(
                            color: Gray.c200,
                            borderRadius: RtcRadius.brMd,
                          ),
                        ),
                      )
                    : Text(
                        valor,
                        style: RtcType.xl2.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Gray.c900,
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Los cuatro accesos de colores, los mismos de la web y en el mismo orden.
  Widget _accesos() {
    final accesos = <(String, String, IconData, Color, Color)>[
      (
        '/dashboard/propetario/canchas/nueva',
        'Nueva cancha',
        LucideIcons.plus,
        Lime.c400,
        Gray.c900,
      ),
      (
        '/dashboard/propetario/reservas',
        'Ver reservas',
        LucideIcons.calendarDays,
        Blue.c600,
        Colors.white,
      ),
      (
        '/dashboard/propetario/analytics',
        'Analytics',
        LucideIcons.chartColumn,
        Purple.c600,
        Colors.white,
      ),
      // Mis canchas sigue en el menu lateral; aca va lo que se usa en la
      // puerta de la cancha.
      (
        '/dashboard/propetario/escanear',
        'Escanear QR',
        LucideIcons.scanLine,
        Gray.c800,
        Colors.white,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: accesos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtcSpace.s4,
        mainAxisSpacing: RtcSpace.s4,
        mainAxisExtent: 116,
      ),
      itemBuilder: (context, i) {
        final (href, label, icono, fondo, texto) = accesos[i];
        return RtcPressable(
          behavior: HitTestBehavior.opaque,
          onTap: () => rtcIrAlPanel(href),
          child: Container(
            padding: const EdgeInsets.all(RtcSpace.s5),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: RtcRadius.brXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: RtcRadius.brXl,
                  ),
                  child: Icon(icono, size: 20, color: texto),
                ),
                const Spacer(),
                Text(
                  label,
                  style: RtcType.base.copyWith(
                    fontWeight: FontWeight.w900,
                    color: texto,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
