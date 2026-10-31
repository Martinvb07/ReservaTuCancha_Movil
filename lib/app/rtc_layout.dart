import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/session.dart';
import '../widgets/floating_actions.dart';
import '../widgets/mobile_search_sheet.dart';
import '../widgets/rtc_mobile_menu.dart';
import '../widgets/rtc_navbar.dart';
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

            return Scaffold(
              backgroundColor: Colors.white,
              appBar: RtcNavbar(
                // `docked && !mobileOpen`: con el menu abierto la web esconde la
                // pildora y vuelve a mostrar el logo completo.
                docked: state.docked && !state.menuOpen,
                menuOpen: state.menuOpen,
                onMenuTap: state.toggleMenu,
                onSearchTap: () => showMobileSearchSheet(context),
              ),
              // El menu esta en el flujo, no superpuesto: al crecer EMPUJA la
              // pagina, que es lo que hace el header de la web. Los flotantes
              // van ENCIMA de todo, como los `fixed` de FloatingActions.
              body: Stack(
                children: [
                  Column(
                    children: [
                      RtcMobileMenu(
                        open: state.menuOpen,
                        isBiz: state.isBiz,
                        signedIn: RtcSession.instance.isLoggedIn,
                        onNavigate: (href) {
                          state.closeMenu();
                          rtcNavigate(href);
                        },
                        // El switch navega pero NO cierra: es el keepOpenRef.
                        onModeChange: (href) {
                          state.requestKeepOpen();
                          rtcNavigate(href);
                        },
                        onDashboard: rtcAbrirPanel,
                        onSignOut: () {
                          state.closeMenu();
                          RtcSession.instance.logout();
                          rtcNavigate('/');
                        },
                      ),
                      Expanded(child: navigator!),
                    ],
                  ),
                  // Un Stack cuyos hijos son todos Positioned se encoge a 0x0:
                  // sin este Positioned.fill los flotantes no se ven.
                  const Positioned.fill(child: FloatingActions()),
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
