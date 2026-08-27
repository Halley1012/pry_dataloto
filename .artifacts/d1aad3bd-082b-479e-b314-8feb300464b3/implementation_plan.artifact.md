# Plan de Implementación: Agregar Subtítulo de Bienvenida en Home

Este plan detalla la adición del subtítulo "Tu suerte comienza aquí." debajo del saludo del usuario en la pantalla de inicio, asegurando el soporte multi-idioma.

## Cambios Propuestos

### [Localización]

Se agregarán nuevas claves de traducción para el saludo y el subtítulo en los archivos `.arb`.

#### [MODIFY] [app_es.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_es.arb)
Agregar:
- `"saludoUsuario": "¡Hola, {nombre}! 👋"`
- `"subtituloSuerte": "Tu suerte comienza aquí."`

#### [MODIFY] [app_en.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_en.arb)
Agregar:
- `"saludoUsuario": "Hello, {nombre}! 👋"`
- `"subtituloSuerte": "Your luck starts here."`

#### [MODIFY] [app_pt.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_pt.arb)
Agregar:
- `"saludoUsuario": "Olá, {nombre}! 👋"`
- `"subtituloSuerte": "Sua sorte começa aqui."`

### [Pantallas]

#### [MODIFY] [home.dart](file:///D:/pry_dataloto/eterlotto/lib/screens/home.dart)
Actualizar el widget `_buildWelcomeGreeting` para:
1. Usar las nuevas cadenas localizadas.
2. Agregar un `Column` para mostrar el subtítulo debajo del nombre.
3. Ajustar los estilos (tamaño de fuente, colores) para que coincidan con el diseño solicitado.

## Plan de Verificación

### Verificación Manual
- Abrir la aplicación y verificar que en el Home aparezca el nombre con el subtítulo debajo.
- Cambiar el idioma del dispositivo (o de la app si hay opción) a inglés y portugués para verificar las traducciones.
- Asegurar que el espaciado y los tamaños de fuente sean adecuados.
