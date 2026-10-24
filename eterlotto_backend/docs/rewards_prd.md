# Recompensas: paso de DEV a PRD (Android)

Esta preparación no crea tablas remotas ni publica la app. Las notificaciones
Colombia se comprobaron en DEV tras ejecutar el modelo: llegaron al teléfono
y aparecen en «Mi país».

## 1. Supabase PRD

Proyecto PRD: `ybgbttlosafenytdavci`. DEV: `plrgbnzsvenpbibrqyqw`.
En el SQL Editor de PRD ejecutar primero `../sql/rewards_prd_audit.sql`.
Si las cuatro tablas no existen, ejecutar `../sql/rewards_prd.sql` y repetir
la auditoría. Si ya existen, comparar columnas, índices y restricciones:
`CREATE TABLE IF NOT EXISTS` no actualiza una estructura anterior.

El script crea `recompensa_retos`, `recompensa_sesiones`, `recompensa_pases` y
`recompensa_desbloqueos`, relacionadas con `public.users.id` integer. Incluye
RLS y revoca acceso directo a los roles móviles. FastAPI escribe mediante su
conexión PostgreSQL de servidor. Los créditos y pases DEV no se copian a PRD.

El SQL de recompensas es **manual**, fuera de `supabase/migrations`.
Hacer merge en Git no lo ejecuta. Se corrigió el workflow PRD, que apuntaba a
DEV. Los secretos de GitHub del environment `production`
(`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`) deben corresponder a PRD.
Antes del merge, revisar el historial y `supabase db push --dry-run` en un
checkout vinculado a PRD: el workflow aplica **todas** las migraciones
pendientes del repositorio. Su paso de preview muestra el plan y después
continúa automáticamente. No reparar el historial a ciegas si la base ya tiene
el baseline existente.

## 2. Backend PRD en Render

Desplegar la versión preparada desde la rama de producción en el servicio
`https://eterlotto-api-prd.onrender.com`, raíz `eterlotto_backend`, con sus
`requirements.txt`. Confirmar estas variables en ese servicio:

| Variable | Valor PRD |
| --- | --- |
| `APP_ENV` | `prd` |
| `APP_BASE_URL` | `https://eterlotto-api-prd.onrender.com` |
| `DATABASE_URL` | Conexión PostgreSQL del proyecto PRD; conservar como secreto |
| `REWARDS_SSV_AD_UNIT_IDS` | `4124989907` |
| `REWARDS_SSV_ACCEPT_VERIFY_TEST` | `false`; temporalmente `true` al verificar la URL en AdMob |
| `ENABLE_NOTIFICATION_TEST_ENDPOINT` | `false` |

Conservar los secretos actuales PRD: `SECRET_KEY`, credenciales Firebase,
Google Play, pagos y `NOTIFICATION_INTERNAL_KEY`. No reemplazarlos por valores
DEV. Un `.env` local no configura Render. El pool asíncrono de recompensas
requiere `DATABASE_URL`; no basta con variables `PG*`.

ML/Airflow PRD debe usar su base PRD,
`ETERLOTTO_API_BASE_URL=https://eterlotto-api-prd.onrender.com` y el mismo
`NOTIFICATION_INTERNAL_KEY` del backend PRD.

## 3. AdMob PRD

El bloque recompensado Android PRD que figura en el código es
`ca-app-pub-9637733995937134/4124989907`. Configurar **en ese bloque** la URL SSV:

```text
https://eterlotto-api-prd.onrender.com/rewards/admob/ssv
```

Activar temporalmente en Render PRD `REWARDS_SSV_ACCEPT_VERIFY_TEST=true` con
`APP_ENV=prd`. La versión preparada acepta «Verificar URL» solamente con firma
Google válida; devuelve `verification_test=true` sin crear sesiones ni dar
créditos. Guardar la URL verificada y volver la bandera a `false`.
No añadir la unidad sintética `1234567890` a la lista de unidades reales.

Mantener el bloque DEV `1080827469` con su callback DEV. Si se decide usar otro
bloque PRD, actualizar juntos el ID Flutter, la lista Render y su callback.

## 4. Compilar Android

`eterlotto/config/rewards.prd.json` selecciona PRD, activa créditos y pases,
desactiva IDs de demostración y vacía las opciones DEV. El código también
impide seleccionar el bloque o los dispositivos DEV cuando el ambiente es PRD.

Desde `D:\pry_dataloto`:

```powershell
# Solo valida; no compila ni aumenta versión.
.\eterlotto\build_release.ps1 -CheckOnly

# Cuando tablas, backend y SSV PRD estén listos:
.\eterlotto\build_release.ps1
```

El script genera el AAB firmado con el keystore existente y aumenta el build
tras compilar correctamente. Comprobar que supere el último versionCode en Play
Console; se puede indicar `-BuildNumber 123` si es necesario. Salida:
`eterlotto/build/app/outputs/bundle/release/app-release.aab`.

Compilación manual equivalente desde `eterlotto` (ajustar el build):

```powershell
flutter build appbundle --release --dart-define-from-file=config/rewards.prd.json --build-number=52
```

Un build manual sin esta configuración conserva el flujo antiguo: PRD exige
`REWARDS_BACKEND_ENABLED=true` explícito. Actualizar el backend no cambia la app
ya instalada; hay que distribuir la nueva compilación. iOS mantiene IDs
pendientes y no está incluido en esta preparación.

## 5. Validar antes del lanzamiento general

Subir primero a una pista interna de Google Play. Registrar el teléfono QA en
la consola AdMob como dispositivo de prueba al usar el bloque propio PRD; la
configuración distribuida no incluye dispositivos de prueba por código.
No sustituirlo por un ID de demostración para comprobar SSV.

Con cuenta PRD comprobar: regalo (+1 crédito y sesión verificada), función
(+1 crédito y acceso 30 minutos), cancelación sin crédito, séptimo crédito,
activación manual del pase, persistencia al reiniciar/cambiar dispositivo y
publicidad desactivada durante el pase. Confirmar vencimientos, ES/EN/FR/PT y
notificaciones de una ejecución del modelo PRD. Las pruebas unitarias no
confirman que Render y AdMob ya estén configurados.

Referencias oficiales:
- [SSV Flutter AdMob](https://developers.google.com/admob/flutter/ssv)
- [Pruebas AdMob](https://developers.google.com/admob/flutter/test-ads)
- [Migraciones Supabase](https://supabase.com/docs/guides/deployment/database-migrations)
