# Plan de implementación: Mejoras en el Generador de Combinaciones

Este plan detalla los cambios necesarios para que el generador de combinaciones muestre todas las loterías disponibles (priorizando las locales) y muestre la fecha del próximo sorteo junto al selector.

## Cambios propuestos

### Backend (Python/FastAPI)

#### [MODIFY] [combination_use_cases.py](file:///D:/pry_dataloto/eterlotto_backend/app/application/combination_use_cases.py)
- Inyectar `PublicidadRepositoryPort` en el constructor.
- Modificar `get_supported_lotteries` para que obtenga la lista completa de loterías desde la base de datos (usando `self.publicidad_repo.list_loterias()`).
- Mapear los campos de la base de datos (`max_seleccion`, `max_balotas_blancas`, etc.) a la estructura de `LotteryRules`.
- Incluir el campo `proximo_sorteo` en la respuesta de cada lotería.
- Actualizar `generate_combinations` para que obtenga las reglas dinámicamente desde la base de datos en lugar de usar un diccionario estático.

#### [MODIFY] [combinations.py](file:///D:/pry_dataloto/eterlotto_backend/app/api/routers/combinations.py)
- Actualizar la función de dependencia `get_combination_use_cases` para inyectar el repositorio de publicidad.

#### [MODIFY] [combination_generator.py](file:///D:/pry_dataloto/eterlotto_backend/app/domain/combination_generator.py)
- Agregar el campo opcional `proximo_sorteo` (String) a la clase `LotteryRules`.

---

### Frontend (Flutter/Dart)

#### [MODIFY] [lottery_rules.dart](file:///D:/pry_dataloto/eterlotto/lib/models/lottery_rules.dart)
- Agregar el campo `nextDrawDate` (String?) a la clase `LotteryRules` y actualizar el factory `fromJson`.

#### [MODIFY] [combination_generator_screen.dart](file:///D:/pry_dataloto/eterlotto/lib/screens/combination_generator_screen.dart)
- Modificar la sección de selección de lotería para incluir la fecha del próximo sorteo al lado del dropdown.
- Usar un `Row` para organizar el `DropdownButtonFormField` y la etiqueta de fecha.
- Formatear la fecha (si está disponible) para mostrarla de forma legible.

## Plan de Verificación

### Pruebas Manuales
1. Abrir la pantalla de Generador de Combinaciones.
2. Verificar que el dropdown muestra más que solo las 3 loterías iniciales (Baloto, MiLoto, ColorLoto).
3. Confirmar que las loterías del país del usuario aparecen de primeras en la lista.
4. Seleccionar diferentes loterías y verificar que la fecha del "Próximo sorteo" se actualiza correctamente al lado del dropdown.
5. Generar combinaciones para una lotería nueva (ej. Powerball) y verificar que las reglas se aplican correctamente (cantidad de números, rangos).

### Pruebas de Integración
- Verificar que la llamada a `/combinations/lotteries` devuelve la lista completa con las fechas de sorteo.
- Verificar que `/combinations/generate` funciona para cualquier lotería de la lista.
