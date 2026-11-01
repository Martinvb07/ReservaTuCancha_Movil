import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/nav_state.dart';
import 'app/routes.dart';
import 'app/rtc_layout.dart';
import 'auth/session.dart';
import 'booking/pago.dart';
import 'data/preferencias.dart';
import 'data/push.dart';
import 'theme/app_theme.dart';
import 'widgets/aviso_actualizacion.dart';
import 'widgets/aviso_sin_conexion.dart';
import 'widgets/bienvenida.dart';

Future<void> main() async {
  // La sesion se lee del almacenamiento seguro antes del primer frame: si no,
  // el navbar parpadea entre "sin sesion" y "con sesion" al abrir la app.
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15 dibuja de borde a borde le guste o no a la app; declararlo hace
  // que Flutter reporte bien los insets en vez de dejar las barras en negro.
  // En iOS no cambia nada: ahi siempre fue asi.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await RtcSession.instance.restore();
  // Datos del jugador y favoritos, para que el formulario ya salga lleno.
  await Preferencias.instance.cargar();
  // El deep link del pago: `reservatucancha://pago?bookingId=X`.
  await DeepLinksDePago.escuchar();
  // Push: confirmaciones y recordatorios al jugador, reservas nuevas al club.
  // Sin el proyecto de Firebase en la build queda apagado.
  await PushNotificaciones.instance.iniciar();
  if (RtcSession.instance.isLoggedIn) {
    // No se espera: pedir permiso no tiene por qué frenar el arranque.
    PushNotificaciones.instance.registrarEnElClub();
  }

  // Reporte de errores. Sin DSN (el caso de desarrollo) Sentry no se activa
  // y la app arranca igual; en la build de la tienda se pasa con
  // --dart-define=SENTRY_DSN=https://...
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isEmpty) {
    runApp(RtcApp());
    return;
  }
  await SentryFlutter.init((options) {
    options.dsn = dsn;
    options.tracesSampleRate = 0.2;
    // Sin datos personales: nombres, correos y telefonos de las reservas
    // no tienen por que salir del telefono en un reporte de error.
    options.sendDefaultPii = false;
  }, appRunner: () => runApp(RtcApp()));
}

class RtcApp extends StatelessWidget {
  RtcApp({super.key});

  /// Un solo estado de header para toda la app, como el `<Navbar />` unico del
  /// layout de la web.
  final _nav = RtcNavState();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReservaTuCancha',
      debugShowCheckedModeBanner: false,
      theme: RtcTheme.light,
      darkTheme: RtcTheme.dark,
      // La web usa next-themes, que por defecto sigue al sistema.
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: rtcRoutes,
      // `/canchas/<id>` no entra en el mapa: lleva parametro.
      onGenerateRoute: rtcOnGenerateRoute,
      // El header navega por esta key porque vive encima del Navigator.
      navigatorKey: rtcNavigatorKey,
      navigatorObservers: [RtcRouteObserver(_nav)],
      // El header envuelve al Navigator: al cambiar de pantalla no se remonta.
      builder: (context, navigator) => Stack(
        children: [
          RtcLayout(state: _nav, child: navigator!),
          // El aviso de sin conexion va encima de todo, panel incluido.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AvisoSinConexion(),
          ),
          const AvisoActualizacion(),
          const _BienvenidaSiHaceFalta(),
        ],
      ),
    );
  }
}

/// La bienvenida, solo la primera vez que se abre la app.
class _BienvenidaSiHaceFalta extends StatefulWidget {
  const _BienvenidaSiHaceFalta();

  @override
  State<_BienvenidaSiHaceFalta> createState() => _BienvenidaSiHaceFaltaState();
}

class _BienvenidaSiHaceFaltaState extends State<_BienvenidaSiHaceFalta> {
  late bool _mostrar = !Preferencias.instance.bienvenidaVista;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_mostrar,
      child: AnimatedOpacity(
        opacity: _mostrar ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: _mostrar
            ? Bienvenida(onTerminar: () => setState(() => _mostrar = false))
            : const SizedBox.shrink(),
      ),
    );
  }
}
