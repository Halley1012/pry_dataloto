from typing import List, Dict, Any, Optional
from app.domain.combination_generator import CombinationGenerator, LotteryRules, GeneratedCombination
from app.domain.ports import PublicidadRepositoryPort

class CombinationUseCases:
    def __init__(self, publicidad_repo: PublicidadRepositoryPort):
        self.publicidad_repo = publicidad_repo

    def _map_to_rules(self, lot: Dict[str, Any], country_map: Dict[int, str]) -> LotteryRules:
        main_numbers_count = lot.get("max_seleccion", 5)
        total_numbers = lot.get("total_balotas_sorteo", main_numbers_count)
        special_numbers_count = max(0, total_numbers - main_numbers_count)
        special_numbers_max = lot.get("max_balotas_rojas") or None
        db_id = lot.get("id")
        pais_id = lot.get("pais_id")
        route = lot.get("route") or lot["nombre"].lower().replace(" ", "_")
        lot_id_str = str(db_id) if db_id is not None else route

        return LotteryRules(
            lottery_id=lot_id_str,
            name=lot["nombre"],
            country=country_map.get(lot["pais_id"], "Unknown"),
            db_id=db_id,
            pais_id=pais_id,
            route=route,
            main_numbers_count=main_numbers_count,
            main_numbers_min=1,
            main_numbers_max=lot.get("max_balotas_blancas", 45),
            special_numbers_count=(
                special_numbers_count if special_numbers_count and special_numbers_max else None
            ),
            special_numbers_min=1 if special_numbers_count and special_numbers_max else None,
            special_numbers_max=special_numbers_max if special_numbers_count else None,
            proximo_sorteo=lot.get("proximo_sorteo")
        )

    def get_supported_lotteries(self) -> List[Dict[str, Any]]:
        try:
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
        except Exception:
            return []

    def get_lottery_rules(self, lottery_id: str) -> LotteryRules:
        loterias = self.publicidad_repo.list_loterias()
        
        # Mapeo de compatibilidad para IDs antiguos
        aliases = {
            "baloto": "bloto",
            "miloto": "mloto",
            "colorloto": "cloto",
            "cloto": "colorloto"
        }
        
        target_ids = {lottery_id.lower()}
        if lottery_id.lower() in aliases:
            target_ids.add(aliases[lottery_id.lower()])

        target_str = str(lottery_id).strip().lower()
        lot = None
        for l in loterias:
            if l.get("id") is not None and str(l["id"]) == target_str:
                lot = l
                break
            curr_id = l.get("route") if l.get("route") else l["nombre"].lower().replace(" ", "_")
            if curr_id in target_ids:
                lot = l
                break
        
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
        strategy: str = "only_mine",
        selected_numbers: Optional[List[int]] = None
    ) -> Dict[str, Any]:
        rules = self.get_lottery_rules(lottery_id)
        generator = CombinationGenerator(rules)
        combinations = generator.generate(
            input_str=input_str,
            quantity=quantity,
            strategy=strategy,
            selected_numbers=selected_numbers
        )
        
        return {
            "lottery": lottery_id.lower(),
            "source": input_str,
            "quantity": quantity,
            "combinations": [c.model_dump() for c in combinations]
        }
