# Plan de implementación: Corrección de desbordamiento en tabla de resultados e inclusión del número 0

Se corregirá el desbordamiento visual en la tabla de los últimos 5 resultados, especialmente para loterías con gran cantidad de balotas (como La Primitiva). Además, se ajustará la lógica de extracción de números para permitir el número 0, el cual es válido en varios sorteos.

## Cambios Propuestos

### Componente de UI: Tabla de Resultados

#### [MODIFY] [ultimos_sorteos_table.dart](file:///D:/pry_dataloto/dataloto/lib/screens/resultados/widgets/ultimos_sorteos_table.dart)
- Ajustar los valores de `flex` en el encabezado y en las filas para dar más espacio a la columna de resultados:
    - Fecha: `3` -> `2` (Se corre a la izquierda)
    - Resultados: `7` -> `11` (Se expande significativamente)
    - Cobertura: `3` -> `2`
    - Aciertos: `3` -> `2`
- Reducir ligeramente el tamaño de las balotas de `20` a `19` para asegurar que quepan hasta 8 o 9 balotas sin necesidad de scroll en la mayoría de dispositivos.

### Lógica de Negocio: Extracción de Números

#### [MODIFY] [resultados_dashboard_screen.dart](file:///D:/pry_dataloto/dataloto/lib/screens/resultados_dashboard_screen.dart)
- Modificar `_extraerNumerosDeMap` para que incluya el número `0`. Se cambiará el filtro `.where((n) => n > 0)` por uno que valide que el parseo fue exitoso pero permita el cero.
- Actualizar otras extracciones como `predictionNumeros` y `_top20List` para que también incluyan el `0`.

#### [MODIFY] [jugadas_list_widget.dart](file:///D:/pry_dataloto/dataloto/lib/widgets/jugadas_list_widget.dart)
- Actualizar la extracción de números en las listas de jugadas para incluir el `0`.

#### [MODIFY] [mis_jugadas_screen.dart](file:///D:/pry_dataloto/dataloto/lib/screens/jugadas/mis_jugadas_screen.dart)
- Asegurar que la pantalla de mis jugadas también reconozca y muestre el `0`.

#### [MODIFY] [loteria_screen.dart](file:///D:/pry_dataloto/dataloto/lib/screens/loteria_screen.dart)
- Actualizar la lógica de carga de resultados en la pantalla individual de lotería.

## Plan de Verificación

### Verificación Manual
- Abrir la pantalla de resultados de "La Primitiva" y verificar que las 8 balotas (6 principales + complementario + reintegro) quepan en el ancho de la pantalla sin mostrar la advertencia de overflow.
- Crear una jugada manual con el número `0` y verificar que si el resultado contiene un `0`, se marque correctamente como un acierto.
- Confirmar que las fechas de los sorteos siguen siendo legibles con el espacio reducido.
