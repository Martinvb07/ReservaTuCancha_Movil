/// El pago con ePayco, que en la app no puede ser lo mismo que en la web.
///
/// La web abre el checkout de ePayco con su script y vuelve sola porque todo
/// pasa en la misma pestaña. La app no puede cargar ese script: abre en el
/// navegador del sistema la pagina `/pagar` de la web, que abre el checkout
/// con la sesion que ya creo el backend. Hay dos maneras de enterarse del
/// resultado:
///
///  1. El deep link `reservatucancha://pago?bookingId=X`, que trae de vuelta a
///     la app apenas termina el pago, por medio de `/app/volver` de la web.
///  2. Preguntarle al backend por la reserva. Esto anda SIEMPRE y es la red de
///     seguridad: cubre que el rebote falle, que cierren el navegador o que
///     vuelvan media hora despues.
library;

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes.dart';

/// A donde manda ePayco al terminar: `/app/volver` de la web, que salta de
/// vuelta a la app con `reservatucancha://pago?bookingId=X`. Si alguien no
/// tiene la app (o el salto se bloquea), esa pagina deja un boton y la
/// confirmacion web. Se puede cambiar al compilar:
///   --dart-define=RTC_PAGO_RETORNO=https://reservatucancha.site/reservas/confirmacion
const _retorno = String.fromEnvironment(
  'RTC_PAGO_RETORNO',
  defaultValue: 'https://reservatucancha.site/app/volver',
);

/// El esquema propio de la app. Un esquema si saca de Chrome aunque la
/// navegacion sea automatica, que es lo que un App Link no logra.
const kEsquemaApp = 'reservatucancha';

String redirectUrlDePago(String bookingId) => '$_retorno?bookingId=$bookingId';

/// Abre `/pagar` (y con ella el checkout de ePayco) en el navegador del
/// sistema.
Future<bool> abrirCheckout(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Escucha `reservatucancha://pago?bookingId=X` y abre la confirmacion.
///
/// Se engancha una sola vez desde `main()`. Cubre tambien el caso de que el
/// link levante la app desde cero (`initialLink`).
class DeepLinksDePago {
  DeepLinksDePago._();

  static final _links = AppLinks();

  static Future<void> escuchar() async {
    _links.uriLinkStream.listen(_manejar);
    final inicial = await _links.getInitialLink();
    if (inicial != null) _manejar(inicial);
  }

  static void _manejar(Uri uri) {
    if (uri.scheme == 'https') {
      _abrirEnlaceDelSitio(uri);
      return;
    }
    if (uri.scheme != kEsquemaApp) return;
    if (uri.host != 'pago' && !uri.path.startsWith('/pago')) return;
    final bookingId = uri.queryParameters['bookingId'];
    if (bookingId == null || bookingId.isEmpty) return;
    rtcAbrirConfirmacion(bookingId);
  }

  /// Un enlace del sitio que Android le paso a la app (App Links): la ficha
  /// de una cancha, el listado, Mis reservas o el panel del dueño. Lo que no
  /// se reconoce abre el inicio.
  static void _abrirEnlaceDelSitio(Uri uri) {
    final ruta = uri.path;
    final token = uri.queryParameters['token'] ?? '';
    if ((ruta == kReprogramarPath ||
            ruta == kResenaPath ||
            ruta == kRestablecerPath) &&
        token.isNotEmpty) {
      rtcAbrirConToken(ruta, token);
      return;
    }
    if (ruta.startsWith(kCourtDetailPrefix)) {
      final id = ruta.substring(kCourtDetailPrefix.length).split('/').first;
      if (id.isNotEmpty) {
        rtcOpenCourt(
          id,
          date: uri.queryParameters['date'],
          start: uri.queryParameters['start'],
        );
        return;
      }
    }
    if (ruta.startsWith('/dashboard')) {
      rtcAbrirPanel();
      return;
    }
    rtcNavigate(ruta.isEmpty ? '/' : ruta);
  }
}

/// `/app/volver` vive en el Frontend (`src/app/app/volver/page.tsx`): no hay
/// que tocar nginx. Para que los links de los correos abran la app falta
/// `/.well-known/assetlinks.json` con el SHA-256 del certificado con el que se
/// firme el APK; se agrega cuando exista la firma de produccion.
const docsPago = 'ver el comentario de arriba';
