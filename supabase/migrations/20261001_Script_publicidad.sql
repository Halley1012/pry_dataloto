ALTER TABLE public.publicidad
    ADD COLUMN IF NOT EXISTS about_us TEXT,
    ADD COLUMN IF NOT EXISTS galeria_urls TEXT;

ALTER TABLE public.publicidad
    ALTER COLUMN titulo TYPE VARCHAR(300);

CREATE TABLE IF NOT EXISTS public.publicidad_likes (
    id SERIAL PRIMARY KEY,
    publicidad_id INTEGER NOT NULL
        REFERENCES public.publicidad(id)
        ON DELETE CASCADE,
    user_id INTEGER NOT NULL
        REFERENCES public.users(id)
        ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(publicidad_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_publicidad_likes_publicidad
    ON public.publicidad_likes(publicidad_id);

CREATE INDEX IF NOT EXISTS idx_publicidad_likes_user
    ON public.publicidad_likes(user_id);