import asyncio
import os
import sys

sys.path.append(r'd:\pry_dataloto\eterlotto_backend')
from dotenv import load_dotenv
load_dotenv(dotenv_path=r'd:\pry_dataloto\eterlotto_backend\.env')

from app.infrastructure.google_play_service import GooglePlayService
from app.infrastructure import db_connection

async def test_token():
    print('Conectando a la base de datos...')
    await db_connection.init_pool()
    pool = db_connection.get_pool()
    
    async with pool.acquire() as conn:
        print('Buscando id=10 en user_subscriptions...')
        row = await conn.fetchrow('SELECT purchase_token FROM user_subscriptions WHERE id = 10')
        if not row:
            print('No se encontro la suscripcion ID 10.')
            return
        token = row['purchase_token']
        print(f'Token encontrado: {token[:20]}... (oculto)')
        
    print('Consultando a Google Play...')
    google_service = GooglePlayService()
    result = await google_service.verify_subscription_token(
        package_name='com.lumieter.eterlotto',
        product_id='eterlotto_monthly_sub',
        purchase_token=token
    )
    
    print('\n--- RESULTADO DE GOOGLE PLAY ---')
    print(f'is_valid: {result.get(\"is_valid\")}')
    print(f'is_active: {result.get(\"is_active\")}')
    print(f'raw_state: {result.get(\"raw_state\")}')
    print(f'expiry_time: {result.get(\"expiry_time\")}')

if __name__ == '__main__':
    asyncio.run(test_token())
