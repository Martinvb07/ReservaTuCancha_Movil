import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../widgets/floating_actions.dart';
import '../theme/palette.dart';
import '../widgets/rtc_bottom_nav.dart';
import '../widgets/rtc_mobile_menu.dart';
import 'dashboard_shell.dart';
import 'nav_state.dart';
import 'routes.dart';

/// Port de `Frontend/src/app/(public)/layout.tsx`.
///
/// Un solo navbar y un solo menu por encima del contenido, igual que el
/// `<Navbar />` unico del layout de la web. El Navigator vive DEBAJO, asi que
/// al cambiar de pantalla el header no se remonta y su estado sobrevive.
class RtcLayout extends StatelessWidget {
  const RtcLayout({super.key, required this.state, required this.child});

  final RtcNavState state;

  /// El Navigator de la app.
  final Widget child;

  /// El estilo de las barras del sistema, atado al tema.
  ///
  /// Arriba siempre hay algo claro — el navbar blanco, o el login que ocupa
  /// toda la pantalla — asi que en tema claro los iconos van oscuros. En tema
  /// oscuro, al reves.
  ///
  /// Van las dos plataformas: `statusBarIconBrightness` es la que lee Android
  /// y `statusBarBrightness` la que lee iOS, y significan lo contrario (una es
  /// el brillo de los ICONOS, la otra el del FONDO). Poner solo una deja la
  /// hora invisible en el otro sistema.
  static SystemUiOverlayStyle _barras(Brightness tema) {
    final claro = tema == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: claro ? Brightness.dark : Brightness.light,
      statusBarBrightness: claro ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: claro
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  /// La pestaña "Más": el menu del sitio (Para clubes, Soporte, ingresar al
  /// panel...) en una hoja que sube desde abajo.
  ///
  /// El layout vive ENCIMA del Navigator, asi que la hoja se abre con el
  /// contexto del Navigator y no con el propio.
  void _abrirMenu() {
    final nav = rtcNavigatorKey.currentContext;
    if (nav == null) return;
    FloatingActions.hojaAbierta.value = true;
    showModalBottomSheet<void>(
      context: nav,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (hoja) {
        void cerrarY(VoidCallback accion) {
          Navigator.of(hoja).pop();
          accion();
        }

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Gray.c200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                RtcMobileMenu(
                  open: true,
                  isBiz: state.isBiz,
                  signedIn: RtcSession.instance.isLoggedIn,
                  onNavigate: (href) => cerrarY(() => rtcNavigate(href)),
                  onModeChange: (href) => cerrarY(() => rtcNavigate(href)),
                  onDashboard: () => cerrarY(rtcAbrirPanel),
                  onSignOut: () => cerrarY(() {
                    RtcSession.instance.logout();
                    rtcNavigate('/');
                  }),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => FloatingActions.hojaAbierta.value = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _barras(Theme.of(context).brightness),
      child: RtcNavScope(
        notifier: state,
        // El navbar tambien depende de la sesion (`useSession()` en la web), asi
        // que se redibuja cuando alguien entra o sale.
        child: AnimatedBuilder(
          animation: Listenable.merge([state, RtcSession.instance]),
          builder: (context, navigator) {
            // El panel del propietario trae su propio armazon: sidebar en un
            // cajon y cabecera propia, como el layout aparte de /dashboard.
            if (state.esPanel) {
              return DashboardShell(route: state.route, child: navigator!);
            }

            // /auth/login se dibuja sola, sin header ni menu.
            if (state.chromeless) {
              return Scaffold(backgroundColor: Colors.white, body: navigator!);
            }

            // Sin header: cada pantalla trae su propia cabecera, como en una
            // app. La ficha de cancha pinta su foto debajo de la barra de
            // estado y tiene su propia barra de reserva abajo, asi que ahi no
            // va la barra de navegacion.
            final ficha = state.route.startsWith(kCourtDetailPrefix);
            final conBarra = !ficha && state.route != kConfirmacionPath;
            final activa = rtcTabs
                .where((t) => t.ruta == state.route)
                .map((t) => t.ruta)
                .firstOrNull;

            return Scaffold(
              backgroundColor: Fondo.app,
              // Los flotantes y la barra van ENCIMA de todo, como los `fixed`
              // de la web.
              body: Stack(
                children: [
                  SafeArea(top: !ficha, bottom: false, child: navigator!),
                  // Un Stack cuyos hijos son todos Positioned se encoge a 0x0:
                  // sin este Positioned.fill los flotantes no se ven.
                  Positioned.fill(
                    child: FloatingActions(
                      extraAbajo: conBarra ? kBottomNavEspacio - 8 : 72,
                      botonesVisibles: state.route == '/soporte',
                    ),
                  ),
                  if (conBarra)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      // Con una hoja abierta (menu, buscador) la barra se
                      // esconde: vive encima del Navigator y le taparia los
                      // botones a la hoja.
                      child: ValueListenableBuilder<bool>(
                        valueListenable: FloatingActions.hojaAbierta,
                        builder: (context, hoja, barra) => AnimatedSlide(
                          offset: hoja ? const Offset(0, 1.5) : Offset.zero,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: barra,
                        ),
                        child: RtcBottomNav(
                          activa: activa,
                          onTap: (tab) => tab.ruta == 'menu'
                              ? _abrirMenu()
                              : rtcNavigate(tab.ruta),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}
