import 'package:flutter/material.dart';

import '../screens/canchas_screen.dart';
import '../auth/session.dart';
import '../screens/confirmacion_screen.dart';
import '../screens/dashboard/analytics_screen.dart';
import '../screens/dashboard/bloqueos_screen.dart';
import '../screens/dashboard/dashboard_home_screen.dart';
import '../screens/dashboard/editar_cancha_screen.dart';
import '../screens/dashboard/escanear_screen.dart';
import '../screens/dashboard/fotos_screen.dart';
import '../screens/dashboard/mi_club_screen.dart';
import '../screens/dashboard/mis_canchas_screen.dart';
import '../screens/dashboard/nueva_cancha_screen.dart';
import '../screens/dashboard/pagos_screen.dart';
import '../screens/dashboard/reservas_screen.dart';
import '../screens/dashboard/soporte_owner_screen.dart';
import '../screens/court_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mis_reservas_screen.dart';
import '../screens/para_clubes_screen.dart';
import '../screens/reprogramar_screen.dart';
import '../screens/resena_screen.dart';
import '../screens/solicitar_acceso_screen.dart';
import '../screens/soporte_screen.dart';

/// Las rutas del sitio, con los mismos paths. El observer del Navigator las lee
/// para saber si estamos en modo negocio (`isBiz`).
final rtcRoutes = <String, WidgetBuilder>{
  '/': (_) => const HomeScreen(),
  '/empresas': (_) => const CanchasScreen(),
  '/mis-reservas': (_) => const MisReservasScreen(),
  '/soporte': (_) => const SoporteScreen(),
  '/para-clubes': (_) => const ParaClubesScreen(),
  '/solicitar-acceso': (_) => const SolicitarAccesoScreen(),
  '/auth/login': (_) => const LoginScreen(),
};

/// La ficha de cancha es una de las dos rutas con parametro, asi que no entra
/// en el mapa de arriba: la arma `rtcOnGenerateRoute`.
const kCourtDetailPrefix = '/canchas/';

/// Los enlaces de los correos con token (`?token=`).
const kReprogramarPath = '/reservas/reprogramar';
const kResenaPath = '/resena';

/// Abre una pantalla de token desde un enlace del correo.
void rtcAbrirConToken(String path, String token) {
  rtcNavigatorKey.currentState?.pushNamed(
    Uri(path: path, queryParameters: {'token': token}).toString(),
  );
}

/// La confirmacion tambien lleva parametro (`?bookingId=`).
const kConfirmacionPath = '/reservas/confirmacion';

/// `MaterialApp.onGenerateRoute`. Resuelve las dos rutas con parametro:
/// `/canchas/<id>` (con los `?date=` y `?start=` del buscador) y
/// `/reservas/confirmacion?bookingId=`.
Route<dynamic>? rtcOnGenerateRoute(RouteSettings settings) {
  final name = settings.name;
  if (name == null) return null;

  final uri = Uri.parse(name);

  // Los dos enlaces de los correos que llevan token: cambiar de horario y
  // dejar resena. Sin token no hay nada que mostrar.
  final token = uri.queryParameters['token'] ?? '';
  if (uri.path == kReprogramarPath && token.isNotEmpty) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ReprogramarScreen(token: token),
    );
  }
  if (uri.path == kResenaPath && token.isNotEmpty) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ResenaScreen(token: token),
    );
  }

  if (uri.path == kConfirmacionPath) {
    final bookingId = uri.queryParameters['bookingId'];
    if (bookingId == null || bookingId.isEmpty) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ConfirmacionScreen(bookingId: bookingId),
    );
  }

  // `/empresas?sport=&city=&date=&start=` — la busqueda del buscador. Sin
  // query la resuelve el mapa de rutas; con query llega hasta aca.
  if (uri.path == kCanchasPath) {
    final q = uri.queryParameters;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => CanchasScreen(
        initialSport: q['sport'],
        initialCity: q['city'],
        initialDate: q['date'],
        initialStart: q['start'],
      ),
    );
  }

  final panel = rtcPanelRoutes[uri.path];
  if (panel != null) {
    return MaterialPageRoute<void>(settings: settings, builder: panel);
  }

  // /dashboard/propetario/canchas/<id>/editar
  final editar = RegExp(
    r'^/dashboard/propetario/canchas/([^/]+)/editar$',
  ).firstMatch(uri.path);
  if (editar != null) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => EditarCanchaScreen(courtId: editar.group(1)!),
    );
  }

  if (!name.startsWith(kCourtDetailPrefix)) return null;
  final id = uri.pathSegments.length < 2 ? '' : uri.pathSegments[1];
  if (id.isEmpty) return null;

  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => CourtDetailScreen(
      courtId: id,
      initialDate: uri.queryParameters['date'],
      initialStart: uri.queryParameters['start'],
    ),
  );
}

/// El header vive ENCIMA del Navigator (va en `MaterialApp.builder`), asi que
/// desde su contexto `Navigator.of` no lo encuentra. Por eso se navega por
/// esta key y no por el contexto.
final rtcNavigatorKey = GlobalKey<NavigatorState>();

/// Ancla pedida por el ultimo enlace (`#beneficios`, `#como-funciona`, `#faq`).
///
/// La pantalla destino la escucha y se desplaza a esa seccion. Hace falta el
/// intermediario porque el enlace puede tocarse desde otra pantalla, cuando la
/// seccion todavia no existe.
final rtcPendingAnchor = ValueNotifier<String?>(null);

/// Navega a un href del menu. Los anchors abren la misma pantalla y ademas la
/// desplazan a la seccion, igual que en el sitio.
void rtcNavigate(String href) {
  final parts = href.split('#');
  final route = parts.first;
  // Las rutas con parametro no estan en el mapa: van por `rtcOpenCourt` y
  // `rtcAbrirConfirmacion`.
  if (!rtcRoutes.containsKey(route)) return;

  rtcPendingAnchor.value = parts.length > 1 ? parts[1] : null;

  final nav = rtcNavigatorKey.currentState;
  if (nav == null) return;

  if (route == '/') {
    nav.popUntil((r) => r.isFirst);
    return;
  }

  // No apilar otra copia de la pantalla en la que ya estamos.
  final actual = _rutaArriba(nav);
  if (actual == route) return;

  // La misma pantalla con una busqueda puesta (`/empresas?sport=...`): el
  // enlace del menu la reemplaza por la limpia en vez de apilar una segunda.
  if (actual != null && Uri.parse(actual).path == route) {
    nav.pushReplacementNamed(route);
    return;
  }

  nav.pushNamed(route);
}

/// El nombre de la ruta de arriba de la pila. El predicado devuelve true en la
/// primera, asi que `popUntil` solo la inspecciona y no saca nada.
String? _rutaArriba(NavigatorState nav) {
  String? nombre;
  nav.popUntil((r) {
    nombre = r.settings.name;
    return true;
  });
  return nombre;
}

/// La pantalla de canchas: el `/empresas` de la web.
const kCanchasPath = '/empresas';

/// `search()` de HeroSearch: `router.push('/empresas?sport=&city=&date=&start=')`.
/// Solo viajan los campos elegidos; sin ninguno queda `/empresas` pelado.
///
/// Si ya se esta en la pantalla de canchas, se reemplaza: la web cambia la URL
/// de la misma pagina, no abre otra encima.
void rtcBuscarCanchas({
  String sport = '',
  String city = '',
  String date = '',
  String start = '',
}) {
  final query = <String, String>{
    if (sport.isNotEmpty) 'sport': sport,
    if (city.isNotEmpty) 'city': city,
    if (date.isNotEmpty) 'date': date,
    if (start.isNotEmpty) 'start': start,
  };
  final destino = Uri(
    path: kCanchasPath,
    queryParameters: query.isEmpty ? null : query,
  ).toString();

  final nav = rtcNavigatorKey.currentState;
  if (nav == null) return;

  final actual = _rutaArriba(nav);
  if (actual == destino) return;
  if (actual != null && Uri.parse(actual).path == kCanchasPath) {
    nav.pushReplacementNamed(destino);
  } else {
    nav.pushNamed(destino);
  }
}

/// Abre la ficha de una cancha, con la preseleccion del buscador si la hay.
/// Es el `<Link href={/canchas/${id}?date=...}>` de la tarjeta.
void rtcOpenCourt(String id, {String? date, String? start}) {
  final query = <String, String>{
    if (date != null && date.isNotEmpty) 'date': date,
    if (start != null && start.isNotEmpty) 'start': start,
  };
  final path = Uri(
    path: '$kCourtDetailPrefix$id',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
  rtcNavigatorKey.currentState?.pushNamed(path);
}

/// Abre la confirmacion de un pago. La llaman el formulario (justo antes de
/// mandar al navegador) y el deep link cuando el telefono vuelve.
void rtcAbrirConfirmacion(String bookingId) {
  final path = '$kConfirmacionPath?bookingId=$bookingId';
  final nav = rtcNavigatorKey.currentState;
  if (nav == null) return;

  // Si ya se esta mostrando esa confirmacion no se apila otra: el deep link
  // puede llegar cuando la pantalla ya se abrio desde el formulario.
  var yaEsta = false;
  nav.popUntil((r) {
    yaEsta = r.settings.name == path;
    return true;
  });
  if (yaEsta) return;

  nav.pushNamed(path);
}

// ── PANEL DEL PROPIETARIO ───────────────────────────────────────────────────

/// Las pantallas del panel que YA existen. La sidebar y los accesos rapidos
/// solo dibujan lo que esta aca: un enlace a una ruta inexistente se ve como
/// una app rota. A medida que se porta cada seccion, se agrega su entrada.
final rtcPanelRoutes = <String, WidgetBuilder>{
  '/dashboard': (_) => const DashboardHomeScreen(),
  '/dashboard/propetario/canchas': (_) => const MisCanchasScreen(),
  '/dashboard/propetario/canchas/nueva': (_) => const NuevaCanchaScreen(),
  '/dashboard/propetario/reservas': (_) => const ReservasScreen(),
  '/dashboard/propetario/escanear': (_) => const EscanearScreen(),
  '/dashboard/propetario/analytics': (_) => const AnalyticsScreen(),
  '/dashboard/propetario/bloqueos': (_) => const BloqueosScreen(),
  '/dashboard/propetario/fotos': (_) => const FotosScreen(),
  '/dashboard/propetario/mi-club': (_) => const MiClubScreen(),
  '/dashboard/propetario/pagos': (_) => const PagosScreen(),
  '/dashboard/propetario/soporte': (_) => const SoporteOwnerScreen(),
};

/// Las rutas del panel que llevan parametro y por eso no estan en el mapa.
/// `rtcOnGenerateRoute` las resuelve con estos mismos patrones.
final _rtcPanelDinamicas = <RegExp>[
  RegExp(r'^/dashboard/propetario/canchas/([^/]+)/editar$'),
];

bool rtcPanelDisponible(String href) =>
    rtcPanelRoutes.containsKey(href) ||
    _rtcPanelDinamicas.any((r) => r.hasMatch(Uri.parse(href).path));

/// Navega dentro del panel. Reemplaza en vez de apilar: la sidebar es un menu
/// lateral, no un camino de ida y vuelta, y apilar dejaria el boton de atras
/// recorriendo secciones sueltas.
void rtcIrAlPanel(String href) {
  if (!rtcPanelDisponible(href)) return;
  final nav = rtcNavigatorKey.currentState;
  if (nav == null) return;

  var yaEsta = false;
  nav.popUntil((r) {
    yaEsta = r.settings.name == href;
    return true;
  });
  if (yaEsta) return;

  nav.pushReplacementNamed(href);
}

/// La puerta de entrada al panel desde el menu publico. Si no hay sesion manda
/// al login, como el `router.replace('/auth/login')` del layout de la web.
void rtcAbrirPanel() {
  if (!RtcSession.instance.isLoggedIn) {
    rtcNavigate('/auth/login');
    return;
  }
  rtcNavigatorKey.currentState?.pushNamed('/dashboard');
}
