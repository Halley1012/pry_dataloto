import asyncio
import os
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
import sys

# Ajustar PYTHONPATH para poder importar módulos de la app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.infrastructure.repositories.user_repository import PostgresUserRepository
from app.infrastructure import db_connection

async def run_test():
    load_dotenv()
    await db_connection.init_pool()
    repo = PostgresUserRepository()
    
    user_id = 91
    
    # Limpiamos suscripciones anteriores de test para el usuario 91
    pool = db_connection.get_pool()
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM user_subscriptions WHERE user_id = $1 AND purchase_token LIKE 'token_%_test'", user_id)
        
    print("--- INICIANDO TEST CONCEPTUAL DE ENTITLEMENT ---")
    
    now = datetime.now(timezone.utc)
    
    # PASO 1: Suscripción A activa (Expira en 30 días)
    expiry_a = now + timedelta(days=30)
    token_a = "token_A_test"
    await repo.set_premium(
        user_id=user_id,
        is_premium=True,
        expires_at=expiry_a,
        order_id="order_A",
        purchase_token=token_a,
        product_id="eterlotto_monthly_sub",
        status="active"
    )
    user = await repo.find_by_id(user_id)
    print(f"Paso 1 (A activa): is_premium={user['is_premium']}, expires_at={user['premium_expires_at']}")
    
    # PASO 2: Suscripción B activa (Expira en 60 días)
    expiry_b = now + timedelta(days=60)
    token_b = "token_B_test"
    await repo.set_premium(
        user_id=user_id,
        is_premium=True,
        expires_at=expiry_b,
        order_id="order_B",
        purchase_token=token_b,
        product_id="eterlotto_monthly_sub",
        status="active"
    )
    user = await repo.find_by_id(user_id)
    print(f"Paso 2 (B activa): is_premium={user['is_premium']}, expires_at={user['premium_expires_at']}")
    
    # PASO 3: Suscripción A es revocada (Simulamos un Webhook RTDN con REVOKED/EXPIRED)
    await repo.update_subscription_state(
        user_id=user_id,
        is_premium=False,
        expires_at=expiry_a,
        purchase_token=token_a,
        status="revoked"
    )
    user = await repo.find_by_id(user_id)
    print(f"Paso 3 (A revocada): is_premium={user['is_premium']}, expires_at={user['premium_expires_at']}")
    
    async with pool.acquire() as conn:
        subs = await conn.fetch("SELECT purchase_token, status FROM user_subscriptions WHERE user_id = $1 AND purchase_token LIKE 'token_%_test' ORDER BY purchase_token", user_id)
        print(" -> Estado actual en BD (user_subscriptions):")
        for sub in subs:
            print(f"    - {sub['purchase_token']}: {sub['status']}")

    # PASO 4: Suscripción B es expirada
    await repo.update_subscription_state(
        user_id=user_id,
        is_premium=False,
        expires_at=expiry_b,
        purchase_token=token_b,
        status="expired"
    )
    user = await repo.find_by_id(user_id)
    print(f"Paso 4 (B expirada): is_premium={user['is_premium']}, expires_at={user['premium_expires_at']}")

    # Limpieza final
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM user_subscriptions WHERE user_id = $1 AND purchase_token IN ($2, $3)", user_id, token_a, token_b)

if __name__ == "__main__":
    asyncio.run(run_test())
