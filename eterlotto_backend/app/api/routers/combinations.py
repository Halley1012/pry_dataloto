from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List

from app.application.combination_use_cases import CombinationUseCases
from app.api import dependencies
from app.application.publicidad_use_cases import PublicidadUseCases

router = APIRouter(prefix="/combinations", tags=["combinations"])

def get_combination_use_cases(
    publicidad_use_cases: PublicidadUseCases = Depends(dependencies.get_publicidad_use_cases)
):
    return CombinationUseCases(publicidad_use_cases.publicidad_repo)

class GenerateRequest(BaseModel):
    lottery: str
    input: str
    quantity: int
    strategy: str = "only_mine"
    selected_numbers: Optional[List[int]] = None

@router.get("/lotteries")
def get_lotteries(use_cases: CombinationUseCases = Depends(get_combination_use_cases)):
    return use_cases.get_supported_lotteries()

@router.post("/generate")
def generate_combinations(req: GenerateRequest, use_cases: CombinationUseCases = Depends(get_combination_use_cases)):
    try:
        if req.quantity < 1 or req.quantity > 50: # Allow up to 50 just in case, frontend restricts to 10
            raise HTTPException(status_code=400, detail="La cantidad debe estar entre 1 y 50.")
            
        result = use_cases.generate_combinations(
            lottery_id=req.lottery,
            input_str=req.input,
            quantity=req.quantity,
            strategy=req.strategy,
            selected_numbers=req.selected_numbers
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
