# Plan de Implementación: Solución de Error de Compilación Gradle

Este plan detalla los pasos para resolver el error `PackageAndroidArtifact$IncrementalSplitterRunnable` que está impidiendo la compilación de la aplicación. Este error suele estar relacionado con archivos corruptos en la caché de compilación o conflictos en el empaquetado del APK.

## User Review Required

> [!IMPORTANT]
> Se realizarán acciones de limpieza profunda en el proyecto. Esto borrará la carpeta `build` y las cachés temporales de Gradle, por lo que la siguiente compilación tardará un poco más de lo habitual.

## Cambios Propuestos

### [Limpieza y Reconstrucción]

1.  **Ejecutar `flutter clean`**: Borrar la carpeta de compilación actual.
2.  **Limpiar Caché de Gradle**: Borrar la carpeta `.gradle` dentro del directorio `android` para forzar a Gradle a reevaluar todas las dependencias.
3.  **Actualizar Dependencias**: Ejecutar `flutter pub get` para asegurar que todas las librerías estén correctamente descargadas.

### [Ajustes de Configuración (Si la limpieza no funciona)]

Si el error persiste después de la limpieza, se realizarán los siguientes ajustes en `android/app/build.gradle.kts`:

#### [MODIFY] [build.gradle.kts](file:///D:/pry_dataloto/eterlotto/android/app/build.gradle.kts)
*   Añadir `packagingOptions` para excluir archivos duplicados de `META-INF` que suelen causar este error específico.

```kotlin
android {
    // ...
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "META-INF/DEPENDENCIES"
        }
    }
}
```

## Plan de Verificación

### Verificación Automatizada
*   Ejecutar `flutter run` para comprobar si la aplicación compila y se inicia correctamente en el dispositivo.

### Verificación Manual
*   Confirmar que el proceso `assembleDebug` finaliza con éxito.
