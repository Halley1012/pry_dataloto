# Historial de jugadas

Las jugadas guardadas se conservan sin límite de antigüedad ni de cantidad de
sorteos, para todas las loterías. Las nuevas jugadas se guardan con `expira = NULL`.

La identidad de la lotería se resuelve desde el catálogo y los parámetros de la
consulta. La conservación no depende de listas fijas de nombres, países o IDs,
ni de fechas concretas. Una lotería nueva del catálogo utiliza la misma regla.

Las consultas de jugadas, los conteos y el selector de loterías incluyen también
las filas antiguas que todavía tengan un valor pasado en `expira`. No hace falta
actualizar esas filas ni cambiar el esquema: la columna ya admite valores nulos.

Se mantienen los filtros por usuario, lotería y fecha solicitada, el borrado manual
y las protecciones contra duplicados. La inicialización del backend ya no elimina
jugadas por antigüedad. Las filas eliminadas previamente no se recuperan con este
cambio; para recuperarlas se necesitaría un respaldo.

Validar primero con el backend de DEV. El cambio entra en vigor en cada entorno
cuando se despliega esta versión del backend; no requiere generar un nuevo AAB.

Pruebas aisladas, sin conexiones a DEV ni PRD:

```powershell
python -m unittest discover -s tests -p test_jugada_history_retention.py
```
