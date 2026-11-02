import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/booking.dart';
import '../../models/fechas.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/acciones_reserva.dart' show leerQr;
import '../../widgets/rtc_toast.dart';
import '../../widgets/motion/rtc_pressable.dart';

/// Check-in en la cancha: el dueño escanea el QR que el jugador muestra en
/// Mis reservas y, si la reserva es suya y esta pagada, la da por jugada.
///
/// La reserva se busca entre las del propio club (`/bookings/owner`): un QR
/// de otro club, o uno inventado, simplemente no aparece.
class EscanearScreen extends StatefulWidget {
  const EscanearScreen({super.key});

  @override
  State<EscanearScreen> createState() => _EscanearScreenState();
}

class _EscanearScreenState extends State<EscanearScreen> {
  final _camara = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Mientras se muestra una reserva no se lee otro QR.
  bool _ocupado = false;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  Future<void> _leido(BarcodeCapture captura) async {
    if (_ocupado) return;
    final qr = leerQr(captura.barcodes.firstOrNull?.rawValue);
    if (qr == null) return;
    setState(() => _ocupado = true);
    HapticFeedback.mediumImpact();

    Booking? reserva;
    String? error;
    try {
      final todas = await ownerApi.reservas();
      // Por código, o por identificador si el QR salió de una reserva que el
      // jugador encontró por correo. Solo entre las reservas de este club.
      reserva = todas
          .where(
            (b) =>
                qr.codigo != null ? b.bookingCode == qr.codigo : b.id == qr.id,
          )
          .firstOrNull;
      if (reserva == null) error = 'Esta reserva no es de tu club.';
    } on RtcApiException catch (e) {
      error = e.message;
    }
    if (!mounted) return;

    if (reserva == null) {
      rtcToast(
        context,
        error ?? 'No encontramos la reserva',
        tipo: RtcToastTipo.error,
      );
      setState(() => _ocupado = false);
      return;
    }
    await _mostrar(reserva);
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _mostrar(Booking b) {
    final puedeCompletar = b.status == 'confirmed' || b.status == 'reagendada';
    final estilo = bookingStatusStyle(b.status);
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (hoja) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.guestName,
                      style: RtcType.lg.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Gray.c900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estilo.pillBackground,
                      borderRadius: RtcRadius.brFull,
                    ),
                    child: Text(
                      estilo.label,
                      style: RtcType.xs.copyWith(
                        fontWeight: RtcType.bold,
                        color: estilo.pillForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${b.courtName} · ${diaMesCorto(b.date)} · '
                '${hora12(b.startTime)} – ${hora12(b.endTime)}',
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
              Text(
                '#${b.bookingCode}',
                style: RtcType.sm.copyWith(
                  color: Gray.c500,
                  fontWeight: RtcType.semibold,
                ),
              ),
              const SizedBox(height: RtcSpace.s5),
              if (puedeCompletar)
                _BotonGrande(
                  texto: 'Llegó: marcar como jugada',
                  onTap: () async {
                    Navigator.of(hoja).pop();
                    try {
                      await ownerApi.cambiarEstado(b.id, 'completed');
                      if (!mounted) return;
                      rtcToast(context, 'Reserva marcada como jugada');
                    } on RtcApiException catch (e) {
                      if (!mounted) return;
                      rtcToast(context, e.message, tipo: RtcToastTipo.error);
                    }
                  },
                )
              else
                Text(
                  b.status == 'completed'
                      ? 'Esta reserva ya estaba marcada como jugada.'
                      : 'Esta reserva todavía no está pagada.',
                  textAlign: TextAlign.center,
                  style: RtcType.sm.copyWith(color: Gray.c600),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            'Escanear reserva',
            style: RtcType.xl3.copyWith(
              letterSpacing: -0.4,
              fontWeight: FontWeight.w900,
              color: Gray.c900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Apunta al QR que el jugador tiene en Mis reservas.',
            style: RtcType.sm.copyWith(color: Gray.c500),
          ),
          const SizedBox(height: RtcSpace.s5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _camara,
                    onDetect: _leido,
                    errorBuilder: (context, error) => ColoredBox(
                      color: GrisFijo.c900,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No pudimos abrir la cámara. Revisa que la app '
                            'tenga permiso de cámara.',
                            textAlign: TextAlign.center,
                            style: RtcType.sm.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // El recuadro donde poner el QR.
                  Center(
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Lime.c400, width: 3),
                      ),
                    ),
                  ),
                  if (_ocupado)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Lime.c400),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.info, size: 14, color: GrisFijo.c500),
              const SizedBox(width: 6),
              Text(
                'Solo se pueden marcar reservas pagadas de tu club.',
                style: RtcType.xs.copyWith(color: GrisFijo.c500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  const _BotonGrande({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Green.c600,
          borderRadius: RtcRadius.brFull,
        ),
        child: Text(
          texto,
          style: RtcType.base.copyWith(
            fontWeight: RtcType.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
