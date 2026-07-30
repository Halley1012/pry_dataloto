from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from app.api import schemas, dependencies
from app.application.transaction_use_cases import TransactionUseCases

router = APIRouter()

@router.post("/create_transaction")
def create_transaction(req: schemas.TransactionRequest, use_cases: TransactionUseCases = Depends(dependencies.get_transaction_use_cases)):
    return use_cases.crear_transaccion(
        amount=req.amount,
        currency=req.currency,
        email=req.email,
        name=req.name,
        reference=req.reference,
        description=req.description
    )

@router.post("/confirmation")
async def confirmation(request: Request, use_cases: TransactionUseCases = Depends(dependencies.get_transaction_use_cases)):
    form_data = await request.form()
    data = dict(form_data)
    
    referencia = data.get("x_ref_payco")
    if not referencia:
        raise HTTPException(status_code=400, detail="Referencia no encontrada en payload")

    try:
        res = await use_cases.confirmar_transaccion(data)
        return res
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al actualizar: {e}")

@router.get("/response")
async def response(status: str = None, ref_payco: str = None):
    # La página de respuesta se mantiene tal cual en la presentación (HTMLResponse)
    html_content = f"""
    <html>
        <head><title>Resultado del pago</title></head>
        <body>
            <h1>Estado del pago: {status or "Desconocido"}</h1>
            <p>Referencia: {ref_payco or "N/A"}</p>
            <p>Gracias por usar nuestro servicio 🚀</p>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)
