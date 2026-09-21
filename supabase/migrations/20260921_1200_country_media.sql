-- Country-owned visual media for the public country catalogue.
--
-- A background belongs to a country, never to an individual lottery: one
-- country image can therefore be reused by every lottery associated with its
-- pais_id. Both URLs are optional because Flutter has local fallbacks.

ALTER TABLE public.paises
    ADD COLUMN IF NOT EXISTS flag_url TEXT,
    ADD COLUMN IF NOT EXISTS background_url TEXT;

-- Treat legacy whitespace-only values as absent before enforcing the URL
-- contract. A CDN URL may include a version query parameter for cache busting.
UPDATE public.paises
SET
    flag_url = NULLIF(BTRIM(flag_url), ''),
    background_url = NULLIF(BTRIM(background_url), '');

ALTER TABLE public.paises
    DROP CONSTRAINT IF EXISTS chk_paises_flag_url_remote;

ALTER TABLE public.paises
    ADD CONSTRAINT chk_paises_flag_url_remote
    CHECK (flag_url IS NULL OR flag_url ~* '^https?://[^[:space:]]+$');

ALTER TABLE public.paises
    DROP CONSTRAINT IF EXISTS chk_paises_background_url_remote;

ALTER TABLE public.paises
    ADD CONSTRAINT chk_paises_background_url_remote
    CHECK (background_url IS NULL OR background_url ~* '^https?://[^[:space:]]+$');

COMMENT ON COLUMN public.paises.flag_url IS
    'Optional remote flag URL. Clients fall back to codigo_iso/emoji when absent.';

COMMENT ON COLUMN public.paises.background_url IS
    'Optional remote country background shared by every lottery in pais_id. Do not duplicate this field in loterias; clients use a generic fallback when absent.';
