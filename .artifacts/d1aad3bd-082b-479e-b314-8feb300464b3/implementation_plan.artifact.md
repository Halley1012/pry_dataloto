# Plan de Implementación: Confirmación de Cambio de Idioma

Añadir un diálogo de confirmación cuando el usuario intenta cambiar el idioma de la aplicación, evitando cambios accidentales y mejorando la experiencia del usuario.

## User Review Required

> [!IMPORTANT]
> El diálogo de confirmación se mostrará en el idioma *actual* de la aplicación antes de aplicar el cambio.

## Cambios Propuestos

### [Localización]

Añadir cadenas de texto para la confirmación en los archivos `.arb`.

#### [MODIFY] [app_es.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_es.arb)
*   Añadir `"confirmarCambioIdioma": "¿Deseas cambiar el idioma de la aplicación?"`
*   Añadir `"si": "Sí"`

#### [MODIFY] [app_en.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_en.arb)
*   Añadir `"confirmarCambioIdioma": "Do you want to change the app language?"`
*   Añadir `"si": "Yes"`

#### [MODIFY] [app_pt.arb](file:///D:/pry_dataloto/eterlotto/lib/l10n/app_pt.arb)
*   Añadir `"confirmarCambioIdioma": "Deseja alterar o idioma do aplicativo?"`
*   Añadir `"si": "Sim"`

### [Pantallas]

#### [MODIFY] [profile_screen.dart](file:///D:/pry_dataloto/eterlotto/lib/screens/profile_screen.dart)
*   Actualizar `_showLanguageDialog` para que cada opción de idioma llame a una nueva función de confirmación.
*   Implementar `_confirmLanguageChange` que muestra un `AlertDialog` con el estilo de la aplicación.

## Verificación Plan

### Manual Verification
1.  Ir al perfil del usuario.
2.  Tocar en el selector de idioma.
3.  Seleccionar un idioma (ej. English).
4.  Verificar que aparezca el diálogo: "¿Deseas cambiar el idioma de la aplicación?".
5.  Si se presiona "Cancelar", el idioma no debe cambiar.
6.  Si se presiona "Sí", el idioma debe cambiar y la UI actualizarse.
