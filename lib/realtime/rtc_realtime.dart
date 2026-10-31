/// Port de `Frontend/src/components/dashboard/RealtimeNotifications.tsx` y
/// del hook `useSocket.ts`.
///
/// Un socket al gateway de notificaciones del NestJS, abierto solo mientras se
/// esta en el panel (la web lo monta en el layout de `/dashboard`). Muestra un
/// aviso por evento y le avisa a las pantallas del panel que recarguen.
///
/// OJO: de los tres eventos, el backend hoy solo EMITE `new-booking`
/// (`bookings.service.ts`). `booking-cancelled` y `payment-confirmed` estan
/// en el gateway pero nadie los llama. Se escuchan igual, como en la web, para
/// que funcionen el dia que el backend los mande.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../auth/session.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../widgets/rtc_toast.dart';

/// `invalidateQueries({ queryKey: ['owner-bookings'] })`: sube cada vez que
/// llega un evento. Reservas, el Inicio y Pagos lo escuchan y recargan.
final rtcReservasCambiaron = ValueNotifier<int>(0);

/// `SOCKET_URL`: la URL de la API sin el `/api`. nginx manda `/socket.io/` al
/// NestJS, igual que `/api/`.
final _socketUrl = RtcApi.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

/// Lo que dura cada aviso: `duration: 8000`.
const _duracion = Duration(milliseconds: 8000);

/// `toLocaleDateString('es-CO', { day: '2-digit', month: 'short' })`. Intl
/// abrevia septiembre "sept" (date-fns dice "sep") y, pese al `2-digit`, no
/// rellena el dia: "5 de ene".
const _mesesIntl = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sept',
  'oct',
  'nov',
  'dic',
];

/// `formatDateShort`.
///
/// El backend guarda el dia como `new Date(año, mes, dia)`: la medianoche de
/// la zona del servidor. Leido en UTC da el dia correcto tanto si el servidor
/// esta en UTC como en Colombia. La web lo pasa a la hora del navegador y, con
/// el servidor en UTC, lo corre al dia anterior; eso no se copia.
String _fechaCorta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final u = d.toUtc();
  return '${u.day} de ${_mesesIntl[u.month - 1]}';
}

/// `Number(x).toLocaleString('es-CO')`.
String _precio(Object? v) => formatCop(num.tryParse('$v')?.round() ?? 0);

/// Monta el socket mientras este widget viva. Va dentro de `DashboardShell`,
/// que es el `<RealtimeNotifications />` del layout del panel.
class RealtimeNotifications extends StatefulWidget {
  const RealtimeNotifications({super.key, required this.child});

  final Widget child;

  @override
  State<RealtimeNotifications> createState() => _RealtimeNotificationsState();
}

class _RealtimeNotificationsState extends State<RealtimeNotifications> {
  io.Socket? _socket;
  String? _ultimoToken;

  /// Renovaciones de sesion pedidas por cortes del servidor. Con tope, para
  /// no quedar en un bucle si el gateway rechaza hasta un token recien sacado.
  int _renovaciones = 0;
  bool _renovando = false;

  @override
  void initState() {
    super.initState();
    RtcSession.instance.addListener(_alCambiarSesion);
    _conectar();
  }

  @override
  void dispose() {
    RtcSession.instance.removeListener(_alCambiarSesion);
    _socket?.dispose();
    super.dispose();
  }

  String? get _token => RtcApi.instance.readAccessToken?.call();

  void _conectar() {
    // `if (!token) return;`
    final token = _token;
    if (token == null) return;
    _ultimoToken = token;

    final s = io.io(
      _socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          // Cada intento lee el token vigente: tras una renovacion, la
          // reconexion ya sale con el nuevo.
          .setAuthFn((cb) => cb({'token': _token ?? ''}))
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    s.on('new-booking', (d) => _nuevaReserva(d));
    s.on('booking-cancelled', (d) => _reservaCancelada(d));
    s.on('payment-confirmed', (d) => _pagoConfirmado(d));
    s.onDisconnect(_alDesconectar);

    _socket = s;
    s.connect();
  }

  /// El gateway corta en el acto al que llega con el token vencido (dura 15
  /// minutos), y socket.io no reintenta los cortes que decide el servidor. Se
  /// renueva la sesion y la reconexion la hace [_alCambiarSesion] cuando llega
  /// el token nuevo.
  Future<void> _alDesconectar(dynamic motivo) async {
    if (motivo != 'io server disconnect') return;
    if (_renovando || _renovaciones >= 3) return;
    _renovando = true;
    _renovaciones++;
    try {
      await RtcApi.instance.renewSession?.call();
    } finally {
      _renovando = false;
    }
  }

  /// `useEffect(..., [token])`: sin sesion se cierra; con un token nuevo y el
  /// socket caido, se vuelve a conectar.
  void _alCambiarSesion() {
    final token = _token;
    if (token == null) {
      _socket?.dispose();
      _socket = null;
      _ultimoToken = null;
      return;
    }
    if (token == _ultimoToken) return;
    _ultimoToken = token;
    final s = _socket;
    if (s == null) {
      _conectar();
    } else if (!s.connected) {
      s.connect();
    }
  }

  // ── EVENTOS ──────────────────────────────────────────────────────────

  Map<String, dynamic> _reserva(dynamic data) {
    final b = data is Map ? data['booking'] : null;
    return b is Map ? Map<String, dynamic>.from(b) : const {};
  }

  String _s(Map<String, dynamic> b, String k) => '${b[k] ?? ''}';

  void _nuevaReserva(dynamic data) {
    final b = _reserva(data);
    final fecha = _s(b, 'date');
    final inicio = _s(b, 'startTime');
    final fin = _s(b, 'endTime');
    _avisar(
      'Nueva reserva recibida',
      // La plantilla de la web, espacios incluidos.
      '${_s(b, 'guestName')} — ${_s(b, 'courtName')} · '
          '${fecha.isNotEmpty ? '${_fechaCorta(fecha)} · ' : ''}'
          '${inicio.isNotEmpty ? hora12(inicio) : ''} '
          '${fin.isNotEmpty ? '- ${hora12(fin)}' : ''} · '
          '\$${_precio(b['totalPrice'])}',
      tipo: RtcToastTipo.exito,
      icono: LucideIcons.calendarDays,
      color: const Color(0xFF22C55E), // green-500
    );
  }

  void _reservaCancelada(dynamic data) {
    final b = _reserva(data);
    final inicio = _s(b, 'startTime');
    _avisar(
      'Reserva cancelada',
      '${_s(b, 'guestName')} — ${_s(b, 'courtName')} · '
          '${inicio.isNotEmpty ? hora12(inicio) : ''} · '
          'Código: ${_s(b, 'bookingCode')}',
      tipo: RtcToastTipo.error,
      icono: LucideIcons.circleX,
      color: const Color(0xFFEF4444), // red-500
    );
  }

  void _pagoConfirmado(dynamic data) {
    final b = _reserva(data);
    _avisar(
      'Pago confirmado',
      '${_s(b, 'guestName')} — ${_s(b, 'courtName')} · '
          '\$${_precio(b['totalPrice'])} · ${_s(b, 'bookingCode')}',
      tipo: RtcToastTipo.exito,
      icono: LucideIcons.creditCard,
      color: const Color(0xFF3B82F6), // blue-500
    );
  }

  void _avisar(
    String titulo,
    String descripcion, {
    required RtcToastTipo tipo,
    required IconData icono,
    required Color color,
  }) {
    // Este widget vive ENCIMA del Navigator (envuelve el armazon del panel),
    // asi que no tiene un Overlay de ancestro: se usa el del Navigator.
    final overlay = rtcNavigatorKey.currentState?.overlay;
    if (overlay != null) {
      rtcToastEn(
        overlay,
        titulo,
        tipo: tipo,
        descripcion: descripcion,
        icono: icono,
        colorIcono: color,
        duracion: _duracion,
      );
    }
    rtcReservasCambiaron.value++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
