/// Port de `Frontend/src/types/supportBot.types.ts`.
///
/// El arbol de la conversacion NO se reescribe: es el mismo
/// `src/data/supportBot.json` de la web, copiado tal cual a
/// `assets/data/support_bot.json`. Si se edita alla, se vuelve a copiar.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SupportBotOpcion {
  const SupportBotOpcion({
    required this.texto,
    this.destino,
    this.url,
    this.accion,
  });

  final String texto;

  /// Id del siguiente nodo dentro de `nodos`.
  final String? destino;

  /// Enlace interno (/canchas), externo o mailto:.
  final String? url;

  /// Por ahora solo 'whatsapp'.
  final String? accion;

  factory SupportBotOpcion.fromJson(Map<String, dynamic> json) =>
      SupportBotOpcion(
        texto: json['texto'] as String,
        destino: json['destino'] as String?,
        url: json['url'] as String?,
        accion: json['accion'] as String?,
      );

  SupportBotOpcion copiarCon({String? destino}) => SupportBotOpcion(
    texto: texto,
    destino: destino ?? this.destino,
    url: url,
    accion: accion,
  );

  /// Los enlaces que salen de la app llevan el icono de link externo.
  bool get esExterno => url != null && !url!.startsWith('/');
}

class SupportBotNodo {
  const SupportBotNodo({
    required this.mensaje,
    required this.opciones,
    this.esRespuesta = false,
  });

  final String mensaje;
  final List<SupportBotOpcion> opciones;

  /// Nodo hoja: el widget le agrega solo las `opcionesFinales`.
  final bool esRespuesta;

  factory SupportBotNodo.fromJson(Map<String, dynamic> json) => SupportBotNodo(
    mensaje: json['mensaje'] as String,
    opciones:
        (json['opciones'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SupportBotOpcion.fromJson)
            .toList() ??
        const [],
    esRespuesta: (json['esRespuesta'] as bool?) ?? false,
  );
}

class SupportBotMeta {
  const SupportBotMeta({
    required this.titulo,
    required this.subtitulo,
    required this.saludo,
    required this.nodoInicial,
    required this.opcionesFinales,
  });

  final String titulo;
  final String subtitulo;
  final String saludo;
  final String nodoInicial;
  final List<SupportBotOpcion> opcionesFinales;

  factory SupportBotMeta.fromJson(Map<String, dynamic> json) => SupportBotMeta(
    titulo: json['titulo'] as String,
    subtitulo: json['subtitulo'] as String,
    saludo: json['saludo'] as String,
    nodoInicial: json['nodoInicial'] as String,
    opcionesFinales:
        (json['opcionesFinales'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SupportBotOpcion.fromJson)
            .toList() ??
        const [],
  );
}

class SupportBotTree {
  const SupportBotTree({required this.meta, required this.nodos});

  final SupportBotMeta meta;
  final Map<String, SupportBotNodo> nodos;

  factory SupportBotTree.fromJson(Map<String, dynamic> json) => SupportBotTree(
    meta: SupportBotMeta.fromJson(json['meta'] as Map<String, dynamic>),
    nodos: (json['nodos'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SupportBotNodo.fromJson(v as Map<String, dynamic>)),
    ),
  );

  /// Se lee una sola vez y queda en memoria: son 16 KB.
  static SupportBotTree? _cache;

  static Future<SupportBotTree> cargar() async {
    final cache = _cache;
    if (cache != null) return cache;
    final raw = await rootBundle.loadString('assets/data/support_bot.json');
    final tree = SupportBotTree.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache = tree;
    return tree;
  }
}

/// Una burbuja de la conversacion.
class SupportBotMensaje {
  const SupportBotMensaje({
    required this.id,
    required this.autor,
    required this.texto,
  });

  final int id;

  /// 'bot' | 'usuario'
  final String autor;

  final String texto;

  bool get esBot => autor == 'bot';
}
