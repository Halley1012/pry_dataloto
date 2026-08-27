# Walkthrough - Eliminación de Icono de Refrescar en Estadísticas

He eliminado el botón de actualización (icono de refrescar) de la barra superior en la pantalla de estadísticas, ya que la pantalla ya cuenta con la funcionalidad de "deslizar para actualizar" (Pull-to-Refresh).

## Cambios realizados

### [Pantalla de Estadísticas (`estadisticas_dashboard_screen.dart`)]
He modificado el `AppBar` del archivo [estadisticas_dashboard_screen.dart](file:///D:/pry_dataloto/eterlotto/lib/screens/estadisticas_dashboard_screen.dart) para eliminar la propiedad `actions`.

- **Antes:** Tenía un `IconButton` con el icono `Icons.refresh` que permitía recargar los datos manualmente.
- **Después:** Se ha eliminado el botón para limpiar la interfaz, confiando en el `RefreshIndicator` ya presente en el cuerpo (`body`) de la pantalla, el cual permite actualizar los datos deslizando hacia abajo.

## Verificación
- El título y el botón de retroceso permanecen intactos.
- La funcionalidad de actualización mediante deslizamiento sigue operativa.
