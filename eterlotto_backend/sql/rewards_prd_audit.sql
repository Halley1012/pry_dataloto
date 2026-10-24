-- Paso 1: solo lectura en Supabase PRD ybgbttlosafenytdavci.
-- Solo lectura. Comparar los resultados antes de ejecutar rewards_dev.sql.
SELECT current_database() AS database_name, current_user AS database_role;

SELECT expected.table_name, c.oid IS NOT NULL AS exists,
       c.relrowsecurity AS rls_enabled
FROM (VALUES ('recompensa_retos'), ('recompensa_sesiones'),
             ('recompensa_pases'), ('recompensa_desbloqueos')) AS expected(table_name)
LEFT JOIN pg_namespace n ON n.nspname = 'public'
LEFT JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = expected.table_name
ORDER BY expected.table_name;

SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name LIKE 'recompensa_%' OR (table_name = 'users' AND column_name = 'id'))
ORDER BY table_name, ordinal_position;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename LIKE 'recompensa_%'
ORDER BY tablename, indexname;

SELECT c.relname AS table_name, k.conname, pg_get_constraintdef(k.oid) AS definition
FROM pg_constraint k
JOIN pg_class c ON c.oid = k.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname LIKE 'recompensa_%'
ORDER BY c.relname, k.conname;

SELECT tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename LIKE 'recompensa_%'
ORDER BY tablename, policyname;
