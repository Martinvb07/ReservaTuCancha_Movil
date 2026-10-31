import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/nav_state.dart';
import 'app/routes.dart';
import 'app/rtc_layout.dart';
import 'auth/session.dart';
import 'booking/pago.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // La sesion se lee del almacenamiento seguro antes del primer frame: si no,
  // el navbar parpadea entre "sin sesion" y "con sesion" al abrir la app.
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15 dibuja de borde a borde le guste o no a la app; declararlo hace
  // que Flutter reporte bien los insets en vez de dejar las barras en negro.
  // En iOS no cambia nada: ahi siempre fue asi.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await RtcSession.instance.restore();
  // El deep link del pago: `reservatucancha://pago?bookingId=X`.
  await DeepLinksDePago.escuchar();
  runApp(RtcApp());
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
      builder: (context, navigator) =>
          RtcLayout(state: _nav, child: navigator!),
    );
  }
}
