import 'package:flutter/widgets.dart';

/// Cuántas hojas o diálogos hay abiertos. La barra de abajo vive encima del
/// Navigator, así que mientras haya uno se esconde para no taparlo.
final rtcModalesAbiertos = ValueNotifier<int>(0);

/// Estado del header, UNO para toda la app.
///
/// En la web hay un solo `<Navbar />` en `(public)/layout.tsx`, encima del
/// `<main>`: su estado sobrevive a la navegacion y `isBiz` sale del pathname.
/// Aca pasa lo mismo — si cada pantalla tuviera su propio menu, el estado se
/// resetearia o se quedaria pegado al cambiar de ruta.
class RtcNavState extends ChangeNotifier {
  String _route = '/';

  /// El nombre completo de la ruta, con la query incluida.
  String _nombre = '/';
  bool _menuOpen = false;
  bool _docked = false;

  /// `keepOpenRef`: el menu se cierra al navegar, SALVO cuando el cambio vino
  /// del switch Reservar / Para clubes.
  bool _keepOpen = false;

  String get route => _route;
  bool get menuOpen => _menuOpen;
  bool get docked => _docked;

  /// `pathname.startsWith('/para-clubes') || startsWith('/solicitar-acceso')`.
  bool get isBiz =>
      _route.startsWith('/para-clubes') ||
      _route.startsWith('/solicitar-acceso');

  /// La pagina de login es `fixed inset-0 z-50` en la web: tapa el navbar por
  /// completo. Aca el header no se puede tapar (vive encima del Navigator),
  /// asi que directamente no se dibuja.
  bool get chromeless => _route.startsWith('/auth/');

  /// El panel del propietario tiene su propio armazon (sidebar y cabecera),
  /// como el layout aparte de `/dashboard` en la web.
  bool get esPanel => _route.startsWith('/dashboard');

  /// La llama el observer del Navigator en cada cambio de ruta. Es el
  /// `useEffect(..., [pathname])` de la web.
  void setRoute(String value) {
    if (value == _nombre) return;
    _nombre = value;
    // `route` guarda solo el pathname, sin el `?sport=...` del buscador: el
    // menu activo, el panel y las pantallas sin chrome se deciden por ruta,
    // como el `usePathname()` de la web. El nombre completo se compara igual,
    // para que una busqueda nueva sobre la misma pantalla cuente como cambio
    // y desacople el buscador del navbar.
    _route = Uri.parse(value).path;
    if (_keepOpen) {
      _keepOpen = false;
    } else {
      _menuOpen = false;
    }
    // El buscador acoplado se resetea al navegar, como `navSearch.reset()`.
    _docked = false;
    notifyListeners();
  }

  /// La pide el switch antes de navegar, para que el menu no se cierre.
  void requestKeepOpen() => _keepOpen = true;

  void toggleMenu() {
    _menuOpen = !_menuOpen;
    notifyListeners();
  }

  void closeMenu() {
    if (!_menuOpen) return;
    _menuOpen = false;
    notifyListeners();
  }

  set docked(bool value) {
    if (value == _docked) return;
    _docked = value;
    notifyListeners();
  }
}

/// Da acceso al estado del header desde cualquier pantalla.
class RtcNavScope extends InheritedNotifier<RtcNavState> {
  const RtcNavScope({
    super.key,
    required RtcNavState super.notifier,
    required super.child,
  });

  static RtcNavState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RtcNavScope>();
    assert(scope != null, 'RtcNavScope no encontrado: falta el RtcLayout');
    return scope!.notifier!;
  }

  /// Para leer sin suscribirse (por ejemplo al reportar el dock).
  static RtcNavState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<RtcNavScope>();
    assert(scope != null, 'RtcNavScope no encontrado: falta el RtcLayout');
    return scope!.notifier!;
  }
}

/// Mantiene `route` sincronizada con lo que hay arriba de la pila.
class RtcRouteObserver extends NavigatorObserver {
  RtcRouteObserver(this.state);

  final RtcNavState state;

  void _sync(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null) state.setRoute(name);
  }

  void _modal(Route<dynamic> route, int delta) {
    if (route is! PopupRoute) return;
    final n = rtcModalesAbiertos.value + delta;
    rtcModalesAbiertos.value = n < 0 ? 0 : n;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _modal(route, 1);
    _sync(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _modal(route, -1);
    _sync(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _modal(route, -1);
    _sync(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync(newRoute);
}
