/// Si esta instalacion de la app esta al dia. Se pregunta una vez al abrir.
library;

import 'package:package_info_plus/package_info_plus.dart';

import '../api/rtc_api.dart';

enum EstadoVersion { alDia, sugerida, obligatoria }

class InfoVersion {
  const InfoVersion(this.estado, this.tienda);

  final EstadoVersion estado;
  final String tienda;
}

/// Compara "1.2.10" con "1.2.9" numero por numero (no como texto).
int compararVersiones(String a, String b) {
  List<int> partes(String v) =>
      v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = partes(a);
  final pb = partes(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

EstadoVersion estadoPara(String instalada, String minima, String ultima) {
  if (compararVersiones(instalada, minima) < 0) {
    return EstadoVersion.obligatoria;
  }
  if (compararVersiones(instalada, ultima) < 0) {
    return EstadoVersion.sugerida;
  }
  return EstadoVersion.alDia;
}

/// Nunca lanza: sin red o con el endpoint caido, la app sigue como al dia.
Future<InfoVersion> consultarVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final data =
        await RtcApi.instance.get('/app/version') as Map<String, dynamic>;
    final minima = (data['minima'] as String?) ?? '0.0.0';
    final ultima = (data['ultima'] as String?) ?? minima;
    return InfoVersion(
      estadoPara(info.version, minima, ultima),
      (data['tienda'] as String?) ?? '',
    );
  } catch (_) {
    return const InfoVersion(EstadoVersion.alDia, '');
  }
}
