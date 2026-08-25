from urllib.parse import urlencode
from typing import Dict, Any, Optional
from app.domain.ports import TransactionRepositoryPort
from app.core import config

class TransactionUseCases:
    def __init__(self, trans_repo: TransactionRepositoryPort):
        self.trans_repo = trans_repo

    def crear_transaccion(self, amount: float, currency: str, email: str, name: str, reference: str, description: str) -> Dict[str, Any]:
        transaccion_id = self.trans_repo.create_transaction(
            referencia=reference,
            nombre_cliente=name,
            email_cliente=email,
            monto=amount,
            moneda=currency,
            descripcion=description
        )

        payload = {
            "public_key": config.EPAYCO_PUBLIC_KEY,
            "amount": amount,
            "currency": currency,
            "name": name,
            "email": email,
            "description": description,
            "invoice": reference,
            "test": "1",
            "url_response": f"{config.APP_BASE_URL}/response",
            "url_confirmation": f"{config.APP_BASE_URL}/confirmation"
        }

        checkout_url = f"{config.EPAYCO_URL}?{urlencode(payload)}"
        return {"transaction_id": transaccion_id, "checkout_url": checkout_url}

    async def confirmar_transaccion(self, form_data: Dict[str, Any]) -> Dict[str, Any]:
        row = await self.trans_repo.update_transaction_confirmation(form_data)
        if row:
            return {"message": "Transacción actualizada con éxito", "transaccion": row}
        else:
            return {"message": "No se encontró la transacción con esa referencia"}
