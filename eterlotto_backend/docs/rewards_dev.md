# Recompensas: validación DEV antes de PRD

Reglas implementadas por `reward_repository.py`: cada SSV firmado acredita una
sesión una sola vez; 7 videos en 7 días generan un pase disponible; el usuario
tiene 7 días para activarlo; activarlo concede 12 horas continuas. Un video desde
una función además desbloquea únicamente esa función durante 30 minutos. Los
videos del regalo siguen acumulando créditos con el pase activo. El primer SSV
válido inicia el reto. Al vencer un reto, su saldo deja de contar.

## Auditoría y Supabase DEV

El backend de recompensas ya existía; faltaba un script de sus tablas en el
repositorio. Ejecutar primero `sql/rewards_dev_audit.sql`, que solo lee metadatos,
y revisar los resultados. El script de creación manual es `sql/rewards_dev.sql`.
No se ha ejecutado contra
Supabase y no se incorpora a las migraciones automáticas. Comprobar primero el
proyecto DEV y comparar el esquema si las tablas ya existen; `IF NOT EXISTS` no
modifica una tabla existente. El script referencia `public.users.id`, de tipo
integer. Las transacciones y el bloqueo de usuario se realizan en FastAPI usando
la conexión PostgreSQL; no se necesitan RPC con permisos de escritura para Flutter.

## Configurar SSV

1. Crear un bloque recompensado propio para DEV en AdMob. Los IDs compartidos de
   demostración de Google no permiten configurar nuestra URL SSV; ver un anuncio
   con ellos no prueba la acreditación en Supabase.
2. Configurar en ese bloque la URL de callback
   `https://pry-dataloto.onrender.com/rewards/admob/ssv` y validarla en la consola
   AdMob. Para una prueba asociada a cuenta se requieren el `user_id` y el UUID
   `custom_data` devueltos por una sesión real. La herramienta de AdMob puede
   firmar un callback de prueba, pero los datos deben corresponder a esa sesión.
3. Configurar en el backend DEV `REWARDS_SSV_AD_UNIT_IDS` con el sufijo numérico
   de ese bloque. No usar la URL DEV en un bloque de producción: un mismo bloque
   no debe enviar sus recompensas a bases de datos de ambientes diferentes.
4. Desplegar el backend actualizado: el cliente consulta también
   `GET /rewards/video-session/{uuid}` con autenticación. Solo el propietario
   puede consultar la sesión. Este endpoint no concede recompensas.
5. Para usar el bloque propio desde una compilación de prueba, registrar el
   dispositivo y compilar con los valores correspondientes:

   ```powershell
   flutter run --dart-define=ENV=dev --dart-define=REWARDS_BACKEND_ENABLED=true --dart-define=REWARDS_SSV_DEV_AD_UNIT_ID=ca-app-pub-TU_EDITOR/TU_BLOQUE_DEV --dart-define=ADMOB_TEST_DEVICE_IDS=HASH_ADMOB_DEL_DISPOSITIVO
   ```

   El hash AdMob se obtiene del SDK y no es el serial ADB ni el hash UMP. Puede
   indicarse una lista separada por comas. El bloque propio en modo prueba solo
   se selecciona si también se configuraron dispositivos de prueba. Nunca usar
   impresiones reales para comprobar el contador. La acreditación debe validarse
   con un callback firmado recibido en el servidor, usando la herramienta SSV
   de AdMob cuando corresponda; el callback local del SDK no sustituye SSV.

La bandera nueva de recompensas sigue limitada a DEV; un release PRD conserva
el comportamiento publicado hasta concluir QA y autorizar su sustitución.

## Correcciones de latencia y confirmación

- El regalo abre inmediatamente y actualiza su contenido con el estado del
  servidor, incluyendo confirmaciones recibidas mientras el diálogo está abierto.
- La carga del anuncio y la creación de sesión ocurren en paralelo. No se hacen
  consultas de saldo redundantes antes de cada video.
- La preparación tiene un indicador visible y evita solicitudes por doble toque.
- El callback local inicia consultas de la sesión exacta durante hasta 2 minutos,
  con aviso de pendiente al cerrar el video. Solo un SSV verificado actualiza el
  saldo y desbloquea la función. También se admite el callback local tardío.
- Al regresar a la app y abrir el regalo se consulta otra vez el estado. Un SSV
  que llegue más tarde permanece acreditado en el servidor, aunque la app haya
  cerrado. No se depende del resultado del sondeo para guardar créditos.
- Las respuestas de una cuenta anterior se descartan. Los vencimientos se
  interpretan usando la hora del servidor y se notifica el fin del pase.

## Pruebas

```powershell
# Desde eterlotto_backend; sin conexiones a Supabase:
python -m unittest discover -s tests -p test_rewards.py -v

# Desde eterlotto:
flutter test --no-pub test/reward_verification_test.dart test/reward_backend_status_test.dart
```

QA DEV pendiente: callback firmado real/de prueba de consola; cancelación;
duplicado; séptimo crédito; activación manual; vencimiento del reto, del plazo de
activación y de las 12 horas; cambio de cuenta/dispositivo; banners e
intersticiales durante la acumulación y su ausencia durante el pase. Confirmar
ES/EN/FR/PT. No considerar un aviso local como evidencia de acreditación.

Referencias oficiales:
- https://developers.google.com/admob/flutter/rewarded
- https://developers.google.com/admob/flutter/ssv
- https://developers.google.com/admob/flutter/test-ads
