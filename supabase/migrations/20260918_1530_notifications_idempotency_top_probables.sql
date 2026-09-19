-- ============================================================
-- Eterlotto
-- 1. Fuente única para cantidad de números más probables
-- 2. Limpieza de notificaciones duplicadas
-- 3. Idempotencia a nivel de BD
-- ============================================================


-- ------------------------------------------------------------
-- 1. TOP de números probables por lotería
-- ------------------------------------------------------------

ALTER TABLE public.loterias
ADD COLUMN IF NOT EXISTS top_probables_count INTEGER;

ALTER TABLE public.loterias
DROP CONSTRAINT IF EXISTS chk_loterias_top_probables_count;

ALTER TABLE public.loterias
ADD CONSTRAINT chk_loterias_top_probables_count
CHECK (
    top_probables_count IS NULL
    OR top_probables_count > 0
);


-- Valores que ya sabemos que utiliza actualmente la aplicación.

UPDATE public.loterias
SET top_probables_count = 21
WHERE LOWER(route) = 'bloto';

UPDATE public.loterias
SET top_probables_count = 20
WHERE LOWER(route) = 'mloto';


-- ------------------------------------------------------------
-- 2. Eliminar duplicados existentes
--
-- Se conserva el ID menor de cada evento.
-- La identidad de una notificación será:
--
-- global:
--   loteria_id + fecha_sorteo + tipo
--
-- personalizada:
--   usuario_id + loteria_id + fecha_sorteo + tipo
-- ------------------------------------------------------------

WITH duplicadas AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY
                usuario_id,
                loteria_id,
                fecha_sorteo,
                tipo
            ORDER BY id
        ) AS rn
    FROM public.notificaciones
    WHERE loteria_id IS NOT NULL
      AND fecha_sorteo IS NOT NULL
)
DELETE FROM public.notificaciones n
USING duplicadas d
WHERE n.id = d.id
  AND d.rn > 1;


-- ------------------------------------------------------------
-- 3. Una sola notificación global por evento
-- ------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS
uq_notificaciones_global_event
ON public.notificaciones (
    loteria_id,
    fecha_sorteo,
    tipo
)
WHERE usuario_id IS NULL
  AND loteria_id IS NOT NULL
  AND fecha_sorteo IS NOT NULL;


-- ------------------------------------------------------------
-- 4. Una sola notificación personalizada por usuario/evento
-- ------------------------------------------------------------

CREATE UNIQUE INDEX IF NOT EXISTS
uq_notificaciones_user_event
ON public.notificaciones (
    usuario_id,
    loteria_id,
    fecha_sorteo,
    tipo
)
WHERE usuario_id IS NOT NULL
  AND loteria_id IS NOT NULL
  AND fecha_sorteo IS NOT NULL;