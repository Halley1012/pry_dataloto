import asyncio
import os
import sys

# Add project root to sys.path to resolve imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.infrastructure.google_play_service import GooglePlayService

async def test_verification():
    print("Iniciando prueba de GooglePlayService...")
    if not os.getenv("GOOGLE_PLAY_CREDENTIALS_B64"):
        print("ERROR: La variable GOOGLE_PLAY_CREDENTIALS_B64 no está configurada.")
        print("Por favor, configúrala antes de ejecutar este script.")
        return
        
    try:
        service = GooglePlayService()
        
        package_name = "com.lumieter.eterlotto"
        product_id = "eterlotto_monthly_sub"
        
        # Pega aquí un token de prueba válido
        test_token = "pcelcpoccidaplficagfilca.AO-J1OxSYGY4vu3ZnYRrBEeWErXwl50_nMwGnBTxYyxYDgB1J1mzxeR0fUAitK-kqckOydTx1Q9xMEUaNdxzltB1CM_aV5-SuxcwcyHtUQfxc8yY4nFZUnM"
        
        print(f"Consultando estado en Google Play API...")
        print(f"Paquete: {package_name}")
        print(f"Producto: {product_id}")
        
        result = await service.verify_subscription_token(
            package_name=package_name,
            product_id=product_id,
            purchase_token=test_token
        )
        
        print("\n--- RESULTADO DE LA VALIDACIÓN ---")
        print(f"¿Producto Válido?: {result['is_valid']}")
        print(f"¿Suscripción Activa?: {result['is_active']}")
        print(f"Estado Crudo (raw_state): {result['raw_state']}")
        print(f"Fecha de Expiración: {result['expiry_time']}")
        
    except Exception as e:
        print(f"Error durante la inicialización: {e}")
        from googleapiclient.errors import HttpError
        if isinstance(e, HttpError):
            print(f"HTTP status: {e.resp.status}")
            print(f"Error details: {e.content.decode('utf-8')}")

if __name__ == "__main__":
    asyncio.run(test_verification())
