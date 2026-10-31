/// Port de `Frontend/src/lib/cloudinary.ts`.
///
/// Las fotos de las canchas no pasan por el backend: se suben directo a
/// Cloudinary con un preset SIN FIRMAR, y al backend solo se le manda la URL.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Sale de las URLs que ya devuelve el backend
/// (`res.cloudinary.com/doio3695p/...`).
const _cloudName = String.fromEnvironment(
  'RTC_CLOUDINARY_CLOUD',
  defaultValue: 'doio3695p',
);

/// `NEXT_PUBLIC_CLOUDINARY_UPLOAD_PRESET` del Frontend.
///
/// Es un preset sin firmar: no es un secreto — viaja en el JavaScript que
/// descarga cualquier navegador que entre al sitio, igual que el cloud name.
/// Se puede reemplazar al compilar con
/// `--dart-define=RTC_CLOUDINARY_PRESET=otro`.
const _uploadPreset = String.fromEnvironment(
  'RTC_CLOUDINARY_PRESET',
  defaultValue: 'reservatucancha_courts',
);

/// true cuando se puede subir. Sin preset, la pantalla lo dice en vez de
/// dejar que el usuario elija fotos que despues fallan en silencio.
bool get cloudinaryConfigurado => _uploadPreset.isNotEmpty;

/// `uploadToCloudinary`: sube y devuelve la URL segura.
Future<String> subirACloudinary(
  List<int> bytes,
  String nombre, {
  String carpeta = 'courts',
}) async {
  if (!cloudinaryConfigurado) {
    throw Exception('Falta el preset de Cloudinary');
  }

  final uri = Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
  );
  final peticion = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = _uploadPreset
    ..fields['folder'] = carpeta
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: nombre));

  final respuesta = await http.Response.fromStream(await peticion.send());
  if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
    throw Exception('Error subiendo imagen a Cloudinary');
  }
  final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
  final url = datos['secure_url'] as String?;
  if (url == null || url.isEmpty) {
    throw Exception('Cloudinary no devolvio la URL');
  }
  return url;
}
