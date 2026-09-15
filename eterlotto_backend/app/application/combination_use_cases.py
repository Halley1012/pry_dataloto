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

        route = lot.get("route") or lot["nombre"].lower().replace(" ", "_")
        return LotteryRules(
            lottery_id=str(lot["id"]),
            catalog_lottery_id=int(lot["id"]),
            route=route,
            name=lot["nombre"],
            country=country_map.get(lot["pais_id"], "Unknown"),
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
        raw_id = (lottery_id or "").strip()

        # El catálogo nuevo envía el id numérico para distinguir loterías que
        # comparten route. Conservamos compatibilidad con clientes antiguos.
        lot = None
        if raw_id.isdigit():
            target_catalog_id = int(raw_id)
            lot = next((l for l in loterias if int(l.get("id", -1)) == target_catalog_id), None)
        else:
            aliases = {
                "baloto": "bloto",
                "miloto": "mloto",
                "colorloto": "cloto",
                "cloto": "colorloto"
            }
            target_ids = {raw_id.lower()}
            if raw_id.lower() in aliases:
                target_ids.add(aliases[raw_id.lower()])

            matches = []
            for l in loterias:
                curr_id = l.get("route") if l.get("route") else l["nombre"].lower().replace(" ", "_")
                if str(curr_id).lower() in target_ids:
                    matches.append(l)
            if len(matches) > 1:
                raise ValueError(
                    f"Lottery '{lottery_id}' corresponde a varios países. "
                    "Actualiza el cliente para enviar el id de catálogo de la lotería."
                )
            lot = matches[0] if matches else None

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
