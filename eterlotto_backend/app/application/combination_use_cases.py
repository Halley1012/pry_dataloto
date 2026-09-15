import logging
import re
from typing import List, Dict, Any, Optional
from app.domain.combination_generator import CombinationGenerator, LotteryRules
from app.domain.ports import PublicidadRepositoryPort

logger = logging.getLogger(__name__)


class CombinationUseCases:
    def __init__(self, publicidad_repo: PublicidadRepositoryPort):
        self.publicidad_repo = publicidad_repo

    @staticmethod
    def _normalize_identity(value: Optional[str]) -> str:
        return re.sub(
            r"_+",
            "_",
            re.sub(r"[^a-z0-9]+", "_", (value or "").strip().lower()),
        ).strip("_")

    @staticmethod
    def _required_positive_int(lot: Dict[str, Any], field: str) -> int:
        raw = lot.get(field)
        if raw is None:
            raise ValueError(
                f"La lotería id={lot.get('id')} no tiene configurado '{field}' en el catálogo"
            )
        value = int(raw)
        if value <= 0:
            raise ValueError(
                f"La lotería id={lot.get('id')} tiene un valor inválido para '{field}': {raw}"
            )
        return value

    def _map_to_rules(self, lot: Dict[str, Any], country_map: Dict[int, str]) -> LotteryRules:
        main_numbers_count = self._required_positive_int(lot, "max_seleccion")
        main_numbers_max = self._required_positive_int(lot, "max_balotas_blancas")
        total_numbers = self._required_positive_int(lot, "total_balotas_sorteo")

        if total_numbers < main_numbers_count:
            raise ValueError(
                f"La lotería id={lot.get('id')} tiene total_balotas_sorteo={total_numbers} "
                f"menor que max_seleccion={main_numbers_count}"
            )

        special_numbers_count = total_numbers - main_numbers_count
        special_numbers_max: Optional[int] = None
        special_numbers_min: Optional[int] = None
        if special_numbers_count > 0:
            special_numbers_max = self._required_positive_int(lot, "max_balotas_rojas")
            special_numbers_min = 0 if bool(lot.get("tiene_reintegro")) else 1

        route = self._normalize_identity(lot.get("route"))
        if not route:
            raise ValueError(
                f"La lotería id={lot.get('id')} no tiene una route válida en el catálogo"
            )

        name = str(lot.get("nombre") or "").strip()
        if not name:
            raise ValueError(f"La lotería id={lot.get('id')} no tiene nombre")

        pais_id = lot.get("pais_id")
        country = country_map.get(pais_id)
        if not country:
            raise ValueError(
                f"La lotería id={lot.get('id')} referencia pais_id={pais_id} no disponible"
            )

        return LotteryRules(
            lottery_id=str(lot["id"]),
            catalog_lottery_id=int(lot["id"]),
            route=route,
            name=name,
            country=country,
            main_numbers_count=main_numbers_count,
            main_numbers_min=1,
            main_numbers_max=main_numbers_max,
            special_numbers_count=special_numbers_count or None,
            special_numbers_min=special_numbers_min,
            special_numbers_max=special_numbers_max,
            proximo_sorteo=lot.get("proximo_sorteo"),
        )

    def get_supported_lotteries(self) -> List[Dict[str, Any]]:
        try:
            loterias = self.publicidad_repo.list_loterias()
            paises = self.publicidad_repo.list_paises()
            country_map = {int(p["id"]): p["nombre"] for p in paises}

            rules_list = []
            for lot in loterias:
                try:
                    rules_list.append(self._map_to_rules(lot, country_map).model_dump())
                except Exception as exc:
                    logger.warning(
                        "Lotería omitida del generador por configuración incompleta: id=%s error=%s",
                        lot.get("id"),
                        exc,
                    )
            return rules_list
        except Exception:
            logger.exception("No se pudo cargar el catálogo de loterías del generador")
            return []

    def get_lottery_rules(self, lottery_id: str) -> LotteryRules:
        loterias = self.publicidad_repo.list_loterias()
        raw_id = (lottery_id or "").strip()

        lot = None
        if raw_id.isdigit():
            target_catalog_id = int(raw_id)
            lot = next(
                (l for l in loterias if int(l.get("id", -1)) == target_catalog_id),
                None,
            )
        else:
            target = self._normalize_identity(raw_id)
            matches = []
            for item in loterias:
                route = self._normalize_identity(item.get("route"))
                name = self._normalize_identity(item.get("nombre"))
                if target and target in {route, name}:
                    matches.append(item)

            if len(matches) > 1:
                raise ValueError(
                    f"Lottery '{lottery_id}' corresponde a varias loterías del catálogo. "
                    "Envía el id numérico de la lotería para identificarla sin ambigüedad."
                )
            lot = matches[0] if matches else None

        if not lot:
            raise ValueError(f"Lottery '{lottery_id}' no está soportada.")

        paises = self.publicidad_repo.list_paises()
        country_map = {int(p["id"]): p["nombre"] for p in paises}
        return self._map_to_rules(lot, country_map)

    def generate_combinations(
        self,
        lottery_id: str,
        input_str: str,
        quantity: int,
        strategy: str = "only_mine",
        selected_numbers: Optional[List[int]] = None,
    ) -> Dict[str, Any]:
        rules = self.get_lottery_rules(lottery_id)
        generator = CombinationGenerator(rules)
        combinations = generator.generate(
            input_str=input_str,
            quantity=quantity,
            strategy=strategy,
            selected_numbers=selected_numbers,
        )

        return {
            "lottery": rules.route or str(rules.catalog_lottery_id),
            "lottery_id": rules.catalog_lottery_id,
            "source": input_str,
            "quantity": quantity,
            "combinations": [c.model_dump() for c in combinations],
        }
