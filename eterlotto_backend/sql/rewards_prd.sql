-- Supabase PRD: proyecto ybgbttlosafenytdavci. Revisar antes de ejecutar.
-- Ejecución manual: este archivo no forma parte del despliegue automático.
-- Si ya existen tablas de recompensas, comparar primero columnas y restricciones.
BEGIN;

CREATE TABLE IF NOT EXISTS public.recompensa_retos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    estado text NOT NULL DEFAULT 'en_progreso'
        CHECK (estado IN ('en_progreso', 'completado', 'vencido')),
    videos_verificados integer NOT NULL DEFAULT 0
        CHECK (videos_verificados BETWEEN 0 AND 7),
    iniciado_en timestamptz NOT NULL DEFAULT now(),
    vence_en timestamptz NOT NULL,
    completado_en timestamptz,
    actualizado_en timestamptz NOT NULL DEFAULT now(),
    CHECK (vence_en > iniciado_en),
    CHECK (estado <> 'completado' OR
           (videos_verificados = 7 AND completado_en IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS recompensa_reto_en_progreso_usuario
    ON public.recompensa_retos(user_id) WHERE estado = 'en_progreso';

CREATE TABLE IF NOT EXISTS public.recompensa_sesiones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    origen text NOT NULL CHECK (origen IN ('regalo', 'funcion')),
    funcion_clave varchar(128),
    estado text NOT NULL DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'verificada', 'cancelada', 'vencida')),
    creada_en timestamptz NOT NULL DEFAULT now(),
    expira_en timestamptz NOT NULL,
    verificada_en timestamptz,
    admob_transaction_id varchar(256) UNIQUE,
    admob_ad_unit varchar(128),
    reto_id uuid REFERENCES public.recompensa_retos(id),
    CHECK (expira_en > creada_en),
    CHECK ((origen = 'regalo' AND funcion_clave IS NULL) OR
           (origen = 'funcion' AND length(trim(funcion_clave)) > 0
            AND funcion_clave IS NOT NULL)),
    CHECK (estado <> 'verificada' OR
           (admob_transaction_id IS NOT NULL AND verificada_en IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS recompensa_sesiones_usuario_pendientes
    ON public.recompensa_sesiones(user_id, creada_en) WHERE estado = 'pendiente';
CREATE INDEX IF NOT EXISTS recompensa_sesiones_reto
    ON public.recompensa_sesiones(reto_id);

CREATE TABLE IF NOT EXISTS public.recompensa_pases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    reto_id uuid NOT NULL UNIQUE REFERENCES public.recompensa_retos(id),
    estado text NOT NULL DEFAULT 'disponible'
        CHECK (estado IN ('disponible', 'activo', 'consumido', 'vencido')),
    obtenido_en timestamptz NOT NULL DEFAULT now(),
    activar_antes_de timestamptz NOT NULL,
    activado_en timestamptz,
    vence_en timestamptz,
    CHECK (activar_antes_de > obtenido_en),
    CHECK (estado NOT IN ('activo', 'consumido') OR
           (activado_en IS NOT NULL AND vence_en IS NOT NULL AND vence_en > activado_en))
);
CREATE INDEX IF NOT EXISTS recompensa_pases_disponibles_usuario
    ON public.recompensa_pases(user_id, obtenido_en) WHERE estado = 'disponible';
CREATE UNIQUE INDEX IF NOT EXISTS recompensa_pase_activo_usuario
    ON public.recompensa_pases(user_id) WHERE estado = 'activo';

CREATE TABLE IF NOT EXISTS public.recompensa_desbloqueos (
    user_id integer NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    funcion_clave varchar(128) NOT NULL CHECK (length(trim(funcion_clave)) > 0),
    desbloqueado_hasta timestamptz NOT NULL,
    ultima_sesion_id uuid NOT NULL REFERENCES public.recompensa_sesiones(id),
    actualizado_en timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, funcion_clave)
);

-- La identidad de la app es public.users.id (integer), no auth.users.id.
-- Flutter consulta FastAPI; ninguna tabla permite escrituras directas del cliente.
ALTER TABLE public.recompensa_retos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recompensa_sesiones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recompensa_pases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recompensa_desbloqueos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recompensa_retos, public.recompensa_sesiones,
    public.recompensa_pases, public.recompensa_desbloqueos FROM anon, authenticated;

COMMIT;

-- Validación de estructura, sin otorgar créditos ni activar pases.
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name LIKE 'recompensa_%'
ORDER BY table_name, ordinal_position;
