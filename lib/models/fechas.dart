/// Los formatos de fecha que usa `BookingForm.tsx` via date-fns con
/// `locale: es`. Van a mano para no sumar `intl` por cuatro cadenas, igual
/// que `formatCop`.
library;

/// `DAYS_ES` del formulario.
const diasCortos = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

/// `format(d, 'EEEE', { locale: es })`.
const diasLargos = [
  'domingo',
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
];

/// `format(d, 'MMM', { locale: es })`.
const mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `format(d, 'MMMM', { locale: es })`.
const mesesLargos = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Colombia es UTC-5 todo el año: no tiene horario de verano. Por eso alcanza
/// con restar 5 horas al UTC y no hace falta la base de datos de zonas.
///
/// La web hace lo mismo con
/// `new Date(new Date().toLocaleString('en-US', { timeZone: 'America/Bogota' }))`
/// para decidir que franjas ya pasaron: si se usara la hora del telefono,
/// alguien viajando veria horarios de hoy que en la cancha ya pasaron.
DateTime ahoraEnBogota() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 5));

/// `format(d, 'yyyy-MM-dd')` — el formato que espera el backend.
String fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// `format(d, 'd MMM', { locale: es })` — "22 ago".
String diaMesCorto(DateTime d) => '${d.day} ${mesesCortos[d.month - 1]}';

/// `format(d, 'EEE', { locale: es })`. date-fns los da en minuscula; los de
/// `diasCortos` vienen del `DAYS_ES` del formulario, que va capitalizado.
const diasCortosMinuscula = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];

/// `format(d, 'EEE dd MMM yyyy', { locale: es })` — "sáb 06 sep 2025".
String diaFechaCorta(DateTime d) =>
    '${diasCortosMinuscula[d.weekday % 7]} '
    '${d.day.toString().padLeft(2, '0')} '
    '${mesesCortos[d.month - 1]} ${d.year}';

/// `format(d, "EEEE d 'de' MMMM", { locale: es })` — "sábado 6 de septiembre".
/// Sin la clase `capitalize` que si lleva [fechaLargaCapitalizada].
String fechaLarga(DateTime d) =>
    '${diasLargos[d.weekday % 7]} ${d.day} de ${mesesLargos[d.month - 1]}';

/// `formatInTimeZone(d, 'America/Bogota', "EEEE d 'de' MMMM", { locale: es })`.
///
/// La web le aplica la clase `capitalize`, que en CSS pone en mayuscula la
/// primera letra de CADA palabra: sale "Sábado 22 De Agosto". Se replica tal
/// cual para no separarse del sitio.
String fechaLargaCapitalizada(DateTime d) {
  final texto =
      '${diasLargos[d.weekday % 7]} ${d.day} de '
      '${mesesLargos[d.month - 1]}';
  return texto
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// `fmt12`: "18:00" -> "6:00 PM". Si no parsea, devuelve lo que entro.
String hora12(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  final sufijo = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $sufijo';
}

/// Suma minutos a un "HH:mm" y devuelve otro "HH:mm", dando la vuelta a las
/// 24h como hace `addMinutes` sobre un Date.
String sumarMinutos(String hhmm, int minutos) {
  final parts = hhmm.split(':');
  final total =
      (int.parse(parts[0]) * 60 + int.parse(parts[1]) + minutos) % (24 * 60);
  final h = total ~/ 60;
  final m = total % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// "15:00" -> "3 PM". Version corta para los ejes de las graficas, donde
/// "3:00 PM" no entra.
///
/// El backend devuelve las horas en 24h (`hourStats` de analytics.service.ts)
/// y la web las muestra asi. En la app van en AM/PM como TODO el resto: es
/// mas raro ver dos formatos distintos en la misma app que separarse del
/// sitio en una etiqueta.
String horaCorta12(String hhmm) {
  final h = int.tryParse(hhmm.split(':').first);
  if (h == null) return hhmm;
  final sufijo = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12 $sufijo';
}
