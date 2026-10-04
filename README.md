# nuestro·bote

Aplicación Flutter para que una pareja guarde deseos compartidos, seleccione
planes y transforme cada deseo cumplido en un recuerdo.

## Estado actual

- Pantalla de bienvenida adaptable.
- Creación de bote y código de vinculación.
- Ingreso de invitación con teclado nativo.
- Identidad visual e ilustraciones pixeladas con `CustomPainter`.
- Navegación, tema, validaciones y servicios centralizados.

## Arquitectura

Organización **feature-first**:

- `lib/app`: inicialización, rutas y sistema visual.
- `lib/core`: utilidades y componentes transversales.
- `lib/features`: funcionalidades independientes.
- `test`: pruebas de widgets y dominio.

Cada funcionalidad puede contener `data`, `domain` y `presentation`. La lógica
de negocio se mantiene separada de los widgets para facilitar pruebas.

## Ejecutar

```bash
flutter pub get
flutter run
```

Después, para comprobar el proyecto:

```text
dart format lib test
flutter analyze
flutter test
```
