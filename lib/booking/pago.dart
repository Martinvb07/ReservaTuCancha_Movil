/// El pago con Wompi, que en la app no puede ser lo mismo que en la web.
///
/// La web hace `window.location.href = checkoutUrl` y vuelve sola porque todo
/// pasa en la misma pestaña. Aca el checkout se abre en el navegador del
/// sistema y hay dos maneras de enterarse del resultado:
///
///  1. El deep link `reservatucancha://pago?bookingId=X`, que trae de vuelta a
///     la app apenas termina el pago. Necesita la pagina trampolin en el VPS
///     (ver `docs_pago` mas abajo); mientras no exista, no se dispara.
///  2. Preguntarle al backend por la reserva. Esto anda SIEMPRE y es la red de
///     seguridad: cubre que el rebote falle, que cierren el navegador o que
///     vuelvan media hora despues.
library;

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes.dart';

/// A donde manda Wompi al terminar. Por defecto la pagina de confirmacion que
/// ya existe en el sitio: se ve el "¡Todo listo!" en el navegador y la app se
/// entera por su cuenta.
///
/// Cuando este publicada la pagina trampolin, se cambia por ella y ahi si el
/// telefono salta solo de vuelta a la app:
///   --dart-define=RTC_PAGO_RETORNO=https://reservatucancha.site/app/volver
const _retorno = String.fromEnvironment(
  'RTC_PAGO_RETORNO',
  defaultValue: 'https://reservatucancha.site/reservas/confirmacion',
);

/// El esquema propio de la app. Un esquema si saca de Chrome aunque la
/// navegacion sea automatica, que es lo que un App Link no logra.
const kEsquemaApp = 'reservatucancha';

String redirectUrlDePago(String bookingId) => '$_retorno?bookingId=$bookingId';

/// Abre el checkout de Wompi en el navegador del sistema.
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
    if (uri.scheme != kEsquemaApp) return;
    if (uri.host != 'pago' && !uri.path.startsWith('/pago')) return;
    final bookingId = uri.queryParameters['bookingId'];
    if (bookingId == null || bookingId.isEmpty) return;
    rtcAbrirConfirmacion(bookingId);
  }
}

/// Lo que hay que dejar servido en el VPS para que el salto de vuelta a la app
/// funcione. Son dos archivos estaticos; no toca ni el Frontend ni el Backend.
///
/// En `/etc/nginx/sites-available/reservatucancha`, dentro del server 443:
///
///     location = /app/volver {
///       default_type text/html;
///       alias /var/www/rtc-app/volver.html;
///     }
///     location = /.well-known/assetlinks.json {
///       default_type application/json;
///       alias /var/www/rtc-app/assetlinks.json;
///     }
///
/// `volver.html` rebota al esquema de la app y deja un boton por si el rebote
/// se bloquea:
///
///     <!doctype html><meta charset="utf-8">
///     <meta name="viewport" content="width=device-width,initial-scale=1">
///     <title>Volviendo a la app…</title>
///     <script>
///       var id = new URLSearchParams(location.search).get('bookingId') || '';
///       var destino = 'reservatucancha://pago?bookingId=' + id;
///       location.replace(destino);
///     </script>
///     <a href="#" id="b">Volver a la app</a>
///     <script>
///       document.getElementById('b').href = destino;
///     </script>
///
/// `assetlinks.json` sirve para que los links de los correos abran la app; hay
/// que poner ahi el SHA-256 del certificado con el que se firme el APK.
const docsPago = 'ver el comentario de arriba';
