UPDATE public.loterias
SET top_probables_count =
    CEIL(max_balotas_blancas / 2.0)::int
WHERE activa = TRUE
  AND top_probables_count IS NULL
  AND max_balotas_blancas IS NOT NULL
  AND max_balotas_blancas > 0;