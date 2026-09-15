import asyncio
import asyncpg
import json

DATABASE_URL = "postgresql://postgres.plrgbnzsvenpbibrqyqw:LuferHalley0011..@aws-0-sa-east-1.pooler.supabase.com:5432/postgres?sslmode=require"

async def dump_schema():
    conn = await asyncpg.connect(DATABASE_URL)
    
    tables = [
        'users', 'user_subscriptions', 'jugadas', 'publicidad', 
        'posts', 'comments', 'notificaciones', 'loterias', 'categorias',
        'resultados_colorloto', 'resultados_colorloto2', 'resultados_baloto', 'resultados_miloto'
    ]
    
    schema_info = {}
    
    # Get table info (columns, types, constraints)
    for table in tables:
        schema_info[table] = {"columns": [], "foreign_keys": [], "indexes": [], "constraints": [], "row_count": 0}
        
        # Row count
        try:
            count = await conn.fetchval(f"SELECT COUNT(*) FROM {table}")
            schema_info[table]["row_count"] = count
        except asyncpg.exceptions.UndefinedTableError:
            schema_info[table]["error"] = "Table does not exist"
            continue
            
        # Columns & constraints
        columns = await conn.fetch(f"""
            SELECT c.column_name, c.data_type, c.is_nullable, c.column_default
            FROM information_schema.columns c
            WHERE c.table_name = '{table}'
            ORDER BY c.ordinal_position;
        """)
        for c in columns:
            schema_info[table]["columns"].append(dict(c))
            
        # Foreign Keys
        fks = await conn.fetch(f"""
            SELECT
                tc.constraint_name,
                kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name,
                rc.update_rule,
                rc.delete_rule
            FROM information_schema.table_constraints AS tc
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
              AND ccu.table_schema = tc.table_schema
            JOIN information_schema.referential_constraints AS rc
              ON rc.constraint_name = tc.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='{table}';
        """)
        for fk in fks:
            schema_info[table]["foreign_keys"].append(dict(fk))
            
        # Indexes
        indexes = await conn.fetch(f"""
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE tablename = '{table}';
        """)
        for idx in indexes:
            schema_info[table]["indexes"].append(dict(idx))
            
        # Constraints (Unique, Primary Key, Check)
        constraints = await conn.fetch(f"""
            SELECT conname, pg_get_constraintdef(c.oid)
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            WHERE t.relname = '{table}';
        """)
        for con in constraints:
            schema_info[table]["constraints"].append({"name": con["conname"], "def": con["pg_get_constraintdef"]})

    with open("schema_dump.json", "w") as f:
        json.dump(schema_info, f, indent=2, default=str)
        
    await conn.close()

if __name__ == "__main__":
    asyncio.run(dump_schema())
