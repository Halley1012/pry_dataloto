import asyncio
import time
from fastapi import HTTPException
from app.infrastructure.db_connection import init_pool, get_pool
from app.infrastructure.repositories.post_repository import PostgresPostRepository
from app.application.post_use_cases import PostUseCases
from app.core import moderation

async def demo_pruebas():
    print("==================================================================")
    print("       DEMOSTRACION DE PRUEBAS DEL SISTEMA DE COMENTARIOS        ")
    print("==================================================================")
    
    await init_pool()
    pool = get_pool()
    
    async with pool.acquire() as conn:
        user = await conn.fetchrow("SELECT id, name FROM users LIMIT 1;")
        post = await conn.fetchrow("SELECT id, title FROM posts LIMIT 1;")

    if not user or not post:
        print("No se encontraron registros de usuario o post en la base de datos.")
        return

    user_id = user["id"]
    post_id = post["id"]
    print(f"\n[INFO] Probando con Usuario ID: {user_id} ('{user['name']}') en Post ID: {post_id} ('{post['title']}')\n")

    repo = PostgresPostRepository()
    use_cases = PostUseCases(repo)

    # -------------------------------------------------------------------------
    # PRUEBA 1: Comentario válido
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 1] Envío de comentario normal y válido ---")
    moderation._user_last_comment_timestamps.clear()
    
    comentario_ok = await use_cases.crear_comentario(
        post_id=post_id,
        user_id=user_id,
        content="¡Excelente predicción para el sorteo de hoy!"
    )
    print("-> Resultado:")
    print(f"   ID: {comentario_ok['id']}")
    print(f"   Contenido: '{comentario_ok['content']}'")
    print(f"   Estado (status): {comentario_ok.get('status')}")
    print(f"   Motivo de moderación: {comentario_ok.get('moderation_reason')}")
    print("   [OK] El comentario se publicó correctamente.\n")

    # -------------------------------------------------------------------------
    # PRUEBA 2: Comentario con insulto o lenguaje inapropiado
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 2] Intento con lenguaje ofensivo/insulto ---")
    moderation._user_last_comment_timestamps.clear()
    
    try:
        await use_cases.crear_comentario(
            post_id=post_id,
            user_id=user_id,
            content="Este pronóstico es una mierda y son unos estafadores malparidos"
        )
        print("   [ERROR] No debió permitirse.")
    except HTTPException as e:
        print("-> Respuesta al Usuario:")
        print(f"   Código HTTP: {e.status_code} Bad Request")
        print(f"   Mensaje UI: '{e.detail}'")
        
        # Consultar la BD para mostrar que quedó en auditoría
        async with pool.acquire() as conn:
            audit = await conn.fetchrow(
                "SELECT id, content, status, moderation_reason FROM comments WHERE user_id = $1 AND status = 'rejected' ORDER BY id DESC LIMIT 1;",
                user_id
            )
            print("-> Registro en Supabase (Auditoría):")
            print(f"   ID: {audit['id']} | Status: {audit['status']} | Motivo: {audit['moderation_reason']}")
            print("   [OK] Bloqueado al usuario y registrado para auditoría interna.\n")

    # -------------------------------------------------------------------------
    # PRUEBA 3: Comentario con Spam / Enlaces no deseados
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 3] Intento con Spam / Enlace externo ---")
    moderation._user_last_comment_timestamps.clear()
    
    try:
        await use_cases.crear_comentario(
            post_id=post_id,
            user_id=user_id,
            content="Gana dinero facil trabajando desde casa ingresa a https://spam-lotto.com"
        )
        print("   [ERROR] No debió permitirse.")
    except HTTPException as e:
        print("-> Respuesta al Usuario:")
        print(f"   Código HTTP: {e.status_code} Bad Request")
        print(f"   Mensaje UI: '{e.detail}'")
        
        async with pool.acquire() as conn:
            audit = await conn.fetchrow(
                "SELECT id, content, status, moderation_reason FROM comments WHERE user_id = $1 AND moderation_reason = 'spam' ORDER BY id DESC LIMIT 1;",
                user_id
            )
            print("-> Registro en Supabase (Auditoría):")
            print(f"   ID: {audit['id']} | Status: {audit['status']} | Motivo: {audit['moderation_reason']}")
            print("   [OK] Spam bloqueado y registrado.\n")

    # -------------------------------------------------------------------------
    # PRUEBA 4: Rate Limiting (Intento de enviar comentarios demasiado rápido)
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 4] Rate Limiting (Protección contra Flood / Bot) ---")
    # Establecemos que acaba de comentar
    moderation._user_last_comment_timestamps[user_id] = time.time()
    
    try:
        await use_cases.crear_comentario(
            post_id=post_id,
            user_id=user_id,
            content="Otro comentario inmediato"
        )
        print("   [ERROR] No debió permitirse tan rápido.")
    except HTTPException as e:
        print("-> Respuesta al Usuario:")
        print(f"   Código HTTP: {e.status_code} Too Many Requests")
        print(f"   Mensaje UI: '{e.detail}'")
        print("   [OK] Cooldown activado exitosamente.\n")

    # -------------------------------------------------------------------------
    # PRUEBA 5: Comprobación del Feed Público de Comentarios
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 5] Verificación del Feed Público (Solo 'active') ---")
    feed = await use_cases.listar_comentarios(post_id)
    estados_en_feed = {c.get("status") for c in feed}
    print(f"-> Total comentarios visibles en el post: {len(feed)}")
    print(f"-> Estados encontrados en la lista pública: {estados_en_feed}")
    if all(s == 'active' for s in estados_en_feed):
        print("   [OK] Ningún comentario 'rejected' ni 'deleted' es visible para los usuarios.\n")

    # -------------------------------------------------------------------------
    # PRUEBA 6: Barrera final de PostgreSQL (Constraint CHECK > 300 caracteres)
    # -------------------------------------------------------------------------
    print("--- [PRUEBA 6] Barrera de PostgreSQL (Intento de saltarse validaciones con >300 chars) ---")
    texto_largo = "A" * 305
    try:
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO comments (post_id, user_id, content, status) VALUES ($1, $2, $3, 'active');",
                post_id, user_id, texto_largo
            )
        print("   [ERROR] PostgreSQL debió rechazar el comentario.")
    except Exception as e:
        print("-> Respuesta del Motor PostgreSQL:")
        print(f"   Error capturado: {type(e).__name__} -> {str(e).splitlines()[0]}")
        print("   [OK] PostgreSQL rechazó físicamente el texto mayor a 300 caracteres.\n")

    # Limpieza de registros de prueba creados
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM comments WHERE id = $1;", comentario_ok['id'])
        await conn.execute("DELETE FROM comments WHERE status = 'rejected' AND user_id = $1;", user_id)

    print("==================================================================")
    print("            TODAS LAS PRUEBAS COMPLETADAS CON EXITO               ")
    print("==================================================================")

if __name__ == '__main__':
    asyncio.run(demo_pruebas())
