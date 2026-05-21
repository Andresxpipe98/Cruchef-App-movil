# CruChef Móvil

Aplicación Flutter para clientes de CruChef. Permite iniciar sesión, seleccionar restaurante por búsqueda o QR, agregar platos al carrito, ajustar cantidades, confirmar pedidos y hacer seguimiento.

## Requisitos

- Flutter SDK compatible con Dart `^3.11.5`
- Proyecto Firebase configurado para Android, iOS y Web
- Archivo `android/app/google-services.json` incluido para Android
- No requiere backend local: restaurantes, platos, pedidos, perfil, fotos y notificaciones se leen/escriben en Firebase.

## Ejecutar

```bash
flutter pub get
flutter run
```

## Validar antes de subir

```bash
dart format lib test
flutter analyze
flutter test
```

## Estructura principal

- `lib/main.dart`: estado de sesión, carrito, pedidos y conexión con Firebase.
- `lib/screens/cruchef_screens.dart`: pantallas de usuario.
- `lib/widgets/cruchef_widgets.dart`: componentes visuales reutilizables.
- `lib/ui/cruchef_design.dart`: tema, colores y superficies.
- `assets/images/logo_cruchef.png`: logo usado en la app.
