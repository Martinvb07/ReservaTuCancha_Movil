/// Precios por horario: la misma cuenta que el backend (`courts/precios.ts`)
/// y la web (`lib/precios.ts`).
///
/// Una cancha tiene un precio base por hora y, opcional, reglas que lo cambian
/// en ciertos dias y horas (la noche, el fin de semana). El servidor es quien
/// cobra; esto solo sirve para mostrar el precio antes de reservar.
library;

class ReglaPrecio {
  const ReglaPrecio({
    required this.days,
    required this.from,
    required this.to,
    required this.pricePerHour,
    this.label,
  });

  /// 0 = domingo … 6 = sabado (como `getDay()` de JavaScript).
  final List<int> days;

  /// "HH:mm".
  final String from;

  /// "HH:mm". "00:00" es la medianoche del final del dia.
  final String to;
  final int pricePerHour;
  final String? label;

  factory ReglaPrecio.fromJson(Map<String, dynamic> json) => ReglaPrecio(
    days:
        (json['days'] as List?)
            ?.whereType<num>()
            .map((n) => n.toInt())
            .toList() ??
        const [],
    from: (json['from'] as String?) ?? '00:00',
    to: (json['to'] as String?) ?? '00:00',
    pricePerHour: (json['pricePerHour'] as num?)?.toInt() ?? 0,
    label: json['label'] as String?,
  );
}

int _aMin(String hhmm) {
  final partes = hhmm.split(':');
  final h = int.tryParse(partes.first) ?? 0;
  final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
  return h * 60 + m;
}

int _finDe(ReglaPrecio r) {
  final fin = _aMin(r.to);
  return fin <= _aMin(r.from) ? 24 * 60 : fin;
}

/// El dia de la semana como lo cuenta el backend: 0 = domingo … 6 = sabado.
int diaSemanaJs(DateTime fecha) => fecha.weekday % 7;

/// Precio por hora que rige en un minuto dado de un dia de la semana.
int precioPorHoraEn(
  int precioBase,
  List<ReglaPrecio> reglas,
  int diaSemana,
  int minuto,
) {
  for (final r in reglas) {
    if (!r.days.contains(diaSemana)) continue;
    if (minuto >= _aMin(r.from) && minuto < _finDe(r)) return r.pricePerHour;
  }
  return precioBase;
}

/// Lo que vale un turno, sin la tarifa de servicio. Se cobra minuto a minuto:
/// si cruza de una franja a otra, cada parte vale lo suyo.
int precioTurno(
  int precioBase,
  List<ReglaPrecio> reglas,
  int diaSemana,
  String inicio,
  String fin,
) {
  final ini = _aMin(inicio);
  var hasta = _aMin(fin);
  if (hasta <= ini) hasta += 24 * 60;
  if (reglas.isEmpty) return (precioBase * (hasta - ini) / 60).round();
  var total = 0.0;
  for (var m = ini; m < hasta; m++) {
    total += precioPorHoraEn(precioBase, reglas, diaSemana, m % (24 * 60)) / 60;
  }
  return total.round();
}

/// El precio por hora mas bajo de la cancha, para "Desde $X".
int precioMinimo(int precioBase, List<ReglaPrecio> reglas) => reglas.fold(
  precioBase,
  (min, r) => r.pricePerHour < min ? r.pricePerHour : min,
);
