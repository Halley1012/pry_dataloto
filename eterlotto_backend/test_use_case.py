import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.api.dependencies import get_subscription_use_cases

async def test_confirm():
    print("Iniciando prueba de confirm_subscription con token expirado...")
    if not os.getenv("GOOGLE_PLAY_CREDENTIALS_B64"):
        print("ERROR: GOOGLE_PLAY_CREDENTIALS_B64 no está configurada.")
        return
        
    try:
        use_cases = get_subscription_use_cases()
        
        # Test con un usuario ficticio (debe existir en tu BD para pasar la primera validación, 
        # asumiendo que el ID 78 existe como vimos antes)
        user_id = 78
        product_id = "eterlotto_monthly_sub"
        test_token = "pcelcpoccidaplficagfilca.AO-J1OxSYGY4vu3ZnYRrBEeWErXwl50_nMwGnBTxYyxYDgB1J1mzxeR0fUAitK-kqckOydTx1Q9xMEUaNdxzltB1CM_aV5-SuxcwcyHtUQfxc8yY4nFZUnM"
        order_id = "GPA.TEST"
        
        print(f"Llamando a confirm_subscription para user_id={user_id}...")
        
        result = await use_cases.confirm_subscription(
            user_id=user_id,
            order_id=order_id,
            purchase_token=test_token,
            product_id=product_id
        )
        
        print("¡ÉXITO INESPERADO! Esto no debería pasar con un token expirado.")
        print(result)
        
    except ValueError as e:
        print("\n--- RESULTADO (EXCEPCIÓN ATRAPADA) ---")
        print(f"Rechazado correctamente por regla de negocio: {e}")
    except Exception as e:
        print(f"Error inesperado: {e}")

if __name__ == "__main__":
    asyncio.run(test_confirm())
