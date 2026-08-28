# Walkthrough - Diálogo de Confirmación para Cambio de Idioma

He implementado un diálogo de confirmación que aparece cuando el usuario selecciona un nuevo idioma en la pantalla de perfil. Esto mejora la experiencia del usuario al evitar cambios accidentales.

## Cambios realizados

### [Localización (Multi-idioma)]
He añadido las cadenas necesarias para el diálogo de confirmación en todos los idiomas soportados:
- **Español (`app_es.arb`)**: `confirmarCambioIdioma`: "¿Deseas cambiar el idioma de la aplicación?", `si`: "Sí".
- **Inglés (`app_en.arb`)**: `confirmarCambioIdioma`: "Do you want to change the app language?", `si`: "Yes".
- **Portugués (`app_pt.arb`)**: `confirmarCambioIdioma`: "Deseja alterar o idioma do aplicativo?", `si`: "Sim".

### [Pantalla de Perfil (`profile_screen.dart`)]
- Se ha creado el método `_confirmLanguageChange` que gestiona la lógica de confirmación.
- Este método utiliza un `AlertDialog` estilizado con el fondo oscuro y detalles en amarillo (`AppColors.yellow`), manteniendo la coherencia visual de la app.
- El flujo de usuario ahora es: **Seleccionar Idioma** -> **Confirmar Cambio** -> **Aplicar y Cerrar**.

## Verificación
- El diálogo se muestra correctamente después de elegir un idioma en la lista.
- Si se cancela, la aplicación permanece en el idioma actual.
- Al confirmar, el idioma se actualiza inmediatamente y se cierran ambos diálogos (el de selección y el de confirmación).
