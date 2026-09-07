from typing import List, Dict, Any, Optional
from app.domain.combination_generator import CombinationGenerator, LotteryRules, GeneratedCombination
from app.domain.ports import PublicidadRepositoryPort

class CombinationUseCases:
    def __init__(self, publicidad_repo: PublicidadRepositoryPort):
        self.publicidad_repo = publicidad_repo

    def _map_to_rules(self, lot: Dict[str, Any], country_map: Dict[int, str]) -> LotteryRules:
        return LotteryRules(
            lottery_id=lot["route"] if lot.get("route") else lot["nombre"].lower().replace(" ", "_"),
            country=country_map.get(lot["pais_id"], "Unknown"),
            main_numbers_count=lot.get("max_seleccion", 5),
            main_numbers_min=1,
            main_numbers_max=lot.get("max_balotas_blancas", 45),
            special_numbers_count=1 if (lot.get("max_balotas_rojas") or 0) > 0 else None,
            special_numbers_min=1 if (lot.get("max_balotas_rojas") or 0) > 0 else None,
            special_numbers_max=lot.get("max_balotas_rojas") if (lot.get("max_balotas_rojas") or 0) > 0 else None,
            proximo_sorteo=lot.get("proximo_sorteo")
        )

    def get_supported_lotteries(self) -> List[Dict[str, Any]]:
        loterias = self.publicidad_repo.list_loterias()
        paises = self.publicidad_repo.list_paises()
        country_map = {p["id"]: p["nombre"] for p in paises}
        
        rules_list = []
        for lot in loterias:
            try:
                rules_list.append(self._map_to_rules(lot, country_map).model_dump())
            except Exception:
                continue
        return rules_list

    def get_lottery_rules(self, lottery_id: str) -> LotteryRules:
        loterias = self.publicidad_repo.list_loterias()
        lot = next((l for l in loterias if (l.get("route") or l["nombre"].lower().replace(" ", "_")) == lottery_id.lower()), None)
        
        if not lot:
            raise ValueError(f"Lottery '{lottery_id}' no está soportada.")
            
        paises = self.publicidad_repo.list_paises()
        country_map = {p["id"]: p["nombre"] for p in paises}
        return self._map_to_rules(lot, country_map)

    def generate_combinations(
        self, 
        lottery_id: str, 
        input_str: str, 
        quantity: int, 
        strategy: str = "balanced"
    ) -> Dict[str, Any]:
        rules = self.get_lottery_rules(lottery_id)
        generator = CombinationGenerator(rules)
        combinations = generator.generate(input_str, quantity, strategy)
        
        return {
            "lottery": lottery_id.lower(),
            "source": input_str,
            "quantity": quantity,
            "combinations": [c.model_dump() for c in combinations]
        }
