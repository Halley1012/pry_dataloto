CREATE TABLE public.prueba_cicd (
    id BIGSERIAL PRIMARY KEY,
    mensaje TEXT NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);