import asyncio
import asyncpg

DATABASE_URL = 'postgresql://postgres.plrgbnzsvenpbibrqyqw:LuferHalley0011..@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require'

async def migrate_comments():
    print("Conectando a la base de datos...")
    conn = await asyncpg.connect(DATABASE_URL)
    
    try:
        async with conn.transaction():
            print("1. Agregando nuevas columnas si no existen...")
            await conn.execute('''
                ALTER TABLE comments 
                  ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active' NOT NULL,
                  ADD COLUMN IF NOT EXISTS moderation_reason VARCHAR(50) DEFAULT NULL,
                  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  ADD COLUMN IF NOT EXISTS parent_id INTEGER REFERENCES comments(id) ON DELETE CASCADE;
            ''')

            print("2. Normalizando status para registros existentes...")
            await conn.execute('''
                UPDATE comments 
                SET status = 'active' 
                WHERE status IS NULL;
            ''')

            print("3. Ajustando longitud y tipo a VARCHAR(300)...")
            await conn.execute('''
                UPDATE comments 
                SET content = SUBSTRING(content FROM 1 FOR 300) 
                WHERE char_length(content) > 300;

                ALTER TABLE comments 
                  ALTER COLUMN content TYPE VARCHAR(300);
            ''')

            print("4. Agregando constraint CHECK para longitud (1 a 300 chars)...")
            await conn.execute('''
                ALTER TABLE comments 
                  DROP CONSTRAINT IF EXISTS comments_content_length_check;

                ALTER TABLE comments 
                  ADD CONSTRAINT comments_content_length_check 
                  CHECK (char_length(trim(content)) BETWEEN 1 AND 300);
            ''')

            print("5. Agregando constraint CHECK para valores válidos de status...")
            await conn.execute('''
                ALTER TABLE comments 
                  DROP CONSTRAINT IF EXISTS comments_status_check;

                ALTER TABLE comments 
                  ADD CONSTRAINT comments_status_check 
                  CHECK (status IN ('active', 'pending', 'rejected', 'deleted'));
            ''')

            print("6. Creando índice optimizado para consultas de comentarios activos...")
            await conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_comments_post_created_active 
                  ON comments(post_id, created_at ASC) 
                  WHERE status = 'active';
            ''')

        print("\n=== MIGRACION COMPLETADA Y CONFIRMADA (COMMIT)! ===\n")

        # Verificación
        cols = await conn.fetch('''
            SELECT column_name, data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = 'comments'
            ORDER BY ordinal_position;
        ''')
        print("Columnas actuales en 'comments':")
        for c in cols:
            print(f" - {c['column_name']}: {c['data_type']} (Nullable: {c['is_nullable']}, Default: {c['column_default']})")

        constraints = await conn.fetch('''
            SELECT conname, pg_get_constraintdef(c.oid) as def
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            WHERE t.relname = 'comments';
        ''')
        print("\nConstraints en 'comments':")
        for c in constraints:
            print(f" - {c['conname']}: {c['def']}")

        indexes = await conn.fetch('''
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE tablename = 'comments';
        ''')
        print("\nÍndices en 'comments':")
        for idx in indexes:
            print(f" - {idx['indexname']}: {idx['indexdef']}")

    finally:
        await conn.close()

if __name__ == '__main__':
    asyncio.run(migrate_comments())
