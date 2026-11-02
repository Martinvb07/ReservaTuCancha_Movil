import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/reviews_api.dart';
import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/star_rating.dart';
import '../widgets/motion/rtc_pressable.dart';
import '../data/calificar_app.dart';

const _etiquetas = {
  1: 'Muy mala',
  2: 'Regular',
  3: 'Buena',
  4: 'Muy buena',
  5: '¡Excelente!',
};

/// Port de `Frontend/src/app/(public)/resena/page.tsx`. Se entra con el
/// `token` del correo que llega despues del partido; vale una sola vez.
class ResenaScreen extends StatefulWidget {
  const ResenaScreen({super.key, required this.token});

  final String token;

  @override
  State<ResenaScreen> createState() => _ResenaScreenState();
}

class _ResenaScreenState extends State<ResenaScreen> {
  int _estrellas = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;
  bool _enviada = false;
  String? _error;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrellas == 0 || _enviando) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await reviewsApi.create(
        reviewToken: widget.token,
        rating: _estrellas,
        comment: _comentario.text,
      );
      if (!mounted) return;
      setState(() => _enviada = true);
      if (_estrellas >= 4) CalificarApp.momentoFeliz();
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enviada) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Green.c50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.circleCheck,
                  size: 34,
                  color: Green.c600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Gracias por tu reseña!',
                style: RtcType.xl.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Gray.c900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ayuda a otros jugadores a elegir dónde jugar.',
                textAlign: TextAlign.center,
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
              const SizedBox(height: 20),
              RtcPressable(
                onTap: () => rtcNavigate('/'),
                child: Text(
                  'Volver al inicio',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Green.c700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Tu opinión importa',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '¿Cómo te fue en la cancha?',
          style: RtcType.xl2.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Gray.c900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: RtcSpace.s6),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    RtcPressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _estrellas = i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: RtcStar(
                          size: 40,
                          fill: i <= _estrellas ? Yellow.c400 : Gray.c100,
                          stroke: i <= _estrellas ? Yellow.c400 : Gray.c300,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _estrellas == 0
                    ? 'Toca las estrellas para calificar'
                    : _etiquetas[_estrellas]!,
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.semibold,
                  color: _estrellas == 0 ? Gray.c400 : Gray.c800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _comentario,
                maxLines: 4,
                maxLength: 500,
                style: RtcType.sm.copyWith(color: Gray.c900),
                decoration: InputDecoration(
                  hintText: 'Cuéntanos cómo estuvo (opcional)',
                  hintStyle: RtcType.sm.copyWith(color: Gray.c500),
                  filled: true,
                  fillColor: Fondo.app,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RtcSpace.s3),
          Text(_error!, style: RtcType.sm.copyWith(color: Red.c500)),
        ],
        const SizedBox(height: RtcSpace.s5),
        Opacity(
          opacity: _estrellas == 0 ? 0.4 : 1,
          child: RtcPressable(
            onTap: _estrellas == 0 ? null : _enviar,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Green.c600,
                borderRadius: RtcRadius.brFull,
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Enviar reseña',
                      style: RtcType.base.copyWith(
                        fontWeight: RtcType.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
