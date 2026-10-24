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

Bloque DEV proporcionado: `ca-app-pub-9637733995937134/1080827469`.
Variable del servicio FastAPI DEV en Render:
`REWARDS_SSV_AD_UNIT_IDS=1080827469`.
Callback SSV de este bloque:
`https://pry-dataloto.onrender.com/rewards/admob/ssv`.
Guardar la variable en un `.env` local no la publica en Render; ambas
configuraciones son independientes. El bloque publicado de PRD no se sustituye.

Para el botón «Verificar URL» de AdMob, configurar temporalmente en Render DEV
`APP_ENV=dev` y `REWARDS_SSV_ACCEPT_VERIFY_TEST=true`, conservando la unidad real
en `REWARDS_SSV_AD_UNIT_IDS=1080827469`. La comprobación firmada de la consola usa
la unidad sintética `1234567890`; devuelve HTTP 200 con `verification_test=true`
sin crear sesiones, créditos, pases ni desbloqueos. No requiere `user_id` ni
`custom_data`. Después de verificar la URL, desactivar la bandera. Sin `APP_ENV`
explícito esta excepción permanece deshabilitada. PRD permite la misma prueba
firmada solo con la bandera temporal; ver `rewards_prd.md`. La unidad
sintética nunca se acepta como un video real ni debe añadirse a la lista de
unidades reales. Verificar la URL no reemplaza la prueba de un video completo.

La configuración de Flutter para este equipo está en
`eterlotto/config/rewards.dev.local.json` (ignorada por Git). El archivo de ejemplo
versionado contiene el bloque DEV y un marcador para el hash. Además, la app
incluye valores predeterminados de DEV para el bloque `1080827469` y el hash
AdMob del teléfono de pruebas actual: una ejecución normal desde el IDE o con
`flutter run` ya selecciona este bloque y registra ese teléfono como dispositivo
de prueba. Ambos valores siguen pudiendo sustituirse con `--dart-define`.
El guard de ambiente impide que estos valores seleccionen el bloque DEV en PRD.
Para utilizar explícitamente el archivo local, desde la raíz del repositorio:

```powershell
.\eterlotto\run_dev.ps1 -DeviceId R5CX15EQ88L
```

El script valida el ambiente y los dispositivos de prueba antes de iniciar
Flutter. `-CheckOnly` valida la configuración sin iniciar ni instalar la app.
Detener primero la ejecución anterior de Flutter para reemplazar sus opciones.
Mantener este teléfono como dispositivo de prueba al usar el bloque propio.

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
5. DEV usa créditos y pases por defecto, incluso con `flutter run` sin opciones.
   Para usar el bloque propio desde una compilación de prueba, registrar el
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

DEV activa el nuevo sistema por defecto; PRD permite activarlo explícitamente
con `REWARDS_BACKEND_ENABLED=true` y la configuración de `rewards_prd.md`.
Un release sin esa opción conserva el comportamiento publicado. Para volver explícitamente
al sistema antiguo en DEV puede compilarse con `REWARDS_BACKEND_ENABLED=false`.
Cambiar estas opciones requiere detener y volver a ejecutar Flutter; hot reload
no vuelve a aplicar las opciones de compilación. Los minutos locales anteriores
no se convierten en créditos SSV ni se importan a Supabase.

## Qué debe guardarse por cada video

| Tabla | Momento de escritura |
| --- | --- |
| `recompensa_sesiones` | Antes de abrir un video, sesión pendiente; al recibir SSV, pasa a verificada. |
| `recompensa_retos` | Al confirmar SSV, se crea o incrementa el reto de créditos. |
| `recompensa_pases` | Solo al completar 7 créditos verificados, pase disponible para activación manual. |
| `recompensa_desbloqueos` | Solo si el video se abrió desde una función; no desde el regalo. |

Si el diálogo dice «Tienes 10m acumulados» o «Ver video +5 min», se está usando
el flujo antiguo, que escribe en SharedPreferences y no crea sesiones FastAPI.
En DEV el diálogo correcto dice «Pase de 12 horas» y muestra créditos de 0 a 7.
Si la sesión no llega a crearse, no se muestra el video ni se concede crédito
local como sustituto. Revisar que la app use DEV y que Render apunte al mismo
proyecto Supabase que se está consultando.

## Correcciones de latencia y confirmación

- El regalo abre inmediatamente y actualiza su contenido con el estado del
  servidor, incluyendo confirmaciones recibidas mientras el diálogo está abierto.
- La carga del anuncio y la creación de sesión ocurren en paralelo. No se hacen
  consultas de saldo redundantes antes de cada video.
- Las funciones muestran su diálogo sin esperar la consulta de recompensas.
  El anuncio se precarga mientras se lee el diálogo. Si el servidor confirma un
  pase o desbloqueo ya existente, el diálogo se cierra y abre esa función sin
  pedir otro video. Un acceso vigente en memoria abre inmediatamente, incluso
  si hay una actualización pendiente. Cancelar no crea una sesión publicitaria.
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
flutter test --no-pub test/reward_verification_test.dart test/reward_backend_status_test.dart test/reward_backend_routing_test.dart test/reward_feature_gate_test.dart
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
