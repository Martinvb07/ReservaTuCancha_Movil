# ReservaTuCancha — app móvil

App de ReservaTuCancha en Flutter (Android e iOS): buscar y reservar canchas,
pagar con ePayco y, para los clubes, el panel del propietario.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

La CI (`.github/workflows/ci.yml`) corre `analyze` y `test` en cada push y pull request.

## Probar en un Android

Cada push a `main` compila un APK en GitHub Actions: pestaña **Actions** → la
última corrida de **CI** → abajo, en **Artifacts**, `ReservaTuCancha-apk`. Se
descarga un .zip con `ReservaTuCancha.apk` adentro; se pasa al teléfono y se
instala (Android pide permitir "instalar apps desconocidas" la primera vez).

Con el teléfono conectado por USB (depuración USB activada) también sirve:

```bash
flutter run --release
```

## Build para la tienda

Las claves van con `--dart-define`; sin ellas cada función queda apagada y la app funciona igual.

| Variable | Para qué |
| --- | --- |
| `SENTRY_DSN` | Reporte de errores. |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID` | Notificaciones push (confirmación, recordatorio, turno liberado y reservas nuevas del club). Salen de la configuración de la app en la consola de Firebase; no hace falta `google-services.json`. |

```bash
flutter build appbundle --release \
  --dart-define=SENTRY_DSN=https://... \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

El backend necesita la cuenta de servicio del mismo proyecto en `FIREBASE_SERVICE_ACCOUNT` (ver el README del repo web).
En iOS, además, hay que subir la llave APNs del Apple Developer a Firebase (Configuración del proyecto → Cloud Messaging) y activar la capacidad *Push Notifications* en Xcode.
