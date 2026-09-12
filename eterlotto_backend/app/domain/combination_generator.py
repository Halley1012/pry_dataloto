import itertools
import random
import re
from typing import List, Optional, Set, Tuple
from pydantic import BaseModel, Field

class LotteryRules(BaseModel):
    lottery_id: str
    name: str
    country: str
    db_id: Optional[int] = None
    pais_id: Optional[int] = None
    route: Optional[str] = None
    main_numbers_count: int
    main_numbers_min: int
    main_numbers_max: int
    special_numbers_count: Optional[int] = None
    special_numbers_min: Optional[int] = None
    special_numbers_max: Optional[int] = None
    proximo_sorteo: Optional[str] = None

class GeneratedCombination(BaseModel):
    number: int
    main_numbers: List[int]
    special_numbers: List[int] = Field(default_factory=list)
    # Se conserva para clientes antiguos que solo conocen una especial.
    special_number: Optional[int] = None

class CombinationGenerator:
    def __init__(self, rules: LotteryRules):
        self.rules = rules

    def generate(
        self,
        input_str: str,
        quantity: int,
        strategy: str = "only_mine",
        selected_numbers: Optional[List[int]] = None
    ) -> List[GeneratedCombination]:
        # 1. Candidatos para números principales
        if selected_numbers is not None:
            # Respetar exactamente los números seleccionados/filtrados por el usuario
            candidates = sorted(list({
                n for n in selected_numbers
                if self.rules.main_numbers_min <= n <= self.rules.main_numbers_max
            }))
        else:
            candidates = sorted(self._extract_candidates(
                input_str,
                self.rules.main_numbers_min,
                self.rules.main_numbers_max
            ))

        # 2. Candidatos para balota especial (si aplica a la lotería)
        special_candidates: List[int] = []
        if self.rules.special_numbers_count:
            if selected_numbers is not None:
                special_candidates = sorted(list({
                    n for n in selected_numbers
                    if self.rules.special_numbers_min <= n <= self.rules.special_numbers_max
                }))
            else:
                special_candidates = sorted(self._extract_candidates(
                    input_str,
                    self.rules.special_numbers_min,
                    self.rules.special_numbers_max
                ))

        # 3. Selección de estrategia
        strat = (strategy or "only_mine").lower().strip()

        if strat == "only_mine":
            return self._generate_only_mine(candidates, special_candidates, quantity)
        elif strat == "variations":
            return self._generate_variations(candidates, special_candidates, quantity)
        elif strat == "balanced":
            return self._generate_legacy_balanced(candidates, special_candidates, quantity)
        elif strat == "random":
            return self._generate_pure_random(quantity)
        else:
            # Estrategia por defecto coherente:
            # Si tiene suficientes números para jugada estricta, usa only_mine; si no, variations
            if len(candidates) >= self.rules.main_numbers_count:
                return self._generate_only_mine(candidates, special_candidates, quantity)
            return self._generate_variations(candidates, special_candidates, quantity)

    def _generate_only_mine(
        self,
        candidates: List[int],
        special_candidates: List[int],
        quantity: int
    ) -> List[GeneratedCombination]:
        count = self.rules.main_numbers_count
        if len(candidates) < count:
            cands_str = ", ".join(map(str, candidates)) if candidates else "ninguno"
            raise ValueError(
                f"Para la estrategia 'Solo mis números' necesitas al menos {count} números válidos. "
                f"Actualmente tienes {len(candidates)} ({cands_str})."
            )

        # Generar todas las combinaciones matemáticas posibles
        all_combinations = list(itertools.combinations(candidates, count))
        random.shuffle(all_combinations)

        # Construir todas las jugadas únicas posibles (principales + especiales).
        unique_plays = []
        special_count = self.rules.special_numbers_count or 0

        if special_count:
            sb_pool = special_candidates if len(special_candidates) >= special_count else (
                list(range(self.rules.special_numbers_min, self.rules.special_numbers_max + 1))
                if (self.rules.special_numbers_min is not None and self.rules.special_numbers_max is not None)
                else []
            )
            for main in all_combinations:
                for special in itertools.combinations(sb_pool, special_count):
                    unique_plays.append((sorted(list(main)), list(special)))
        else:
            for main in all_combinations:
                unique_plays.append((sorted(list(main)), []))

        random.shuffle(unique_plays)
        selected_plays = unique_plays[:quantity]

        combinations: List[GeneratedCombination] = []
        for i, (main_nums, special_nums) in enumerate(selected_plays):
            combinations.append(
                GeneratedCombination(
                    number=i + 1,
                    main_numbers=main_nums,
                    special_numbers=special_nums,
                    special_number=special_nums[0] if len(special_nums) == 1 else None,
                )
            )

        return combinations

    def _generate_variations(
        self,
        candidates: List[int],
        special_candidates: List[int],
        quantity: int
    ) -> List[GeneratedCombination]:
        count = self.rules.main_numbers_count
        min_val = self.rules.main_numbers_min
        max_val = self.rules.main_numbers_max

        combinations: List[GeneratedCombination] = []
        seen: Set[Tuple[int, ...]] = set()

        all_pool = [n for n in range(min_val, max_val + 1) if n not in candidates]

        for i in range(quantity):
            attempts = 0
            main_nums = []

            while attempts < 200:
                attempts += 1
                result_set: Set[int] = set()

                if candidates:
                    if len(candidates) <= count:
                        # Si tiene igual o menos que 'count', incluye todos sus números personales
                        result_set.update(candidates)
                    else:
                        # Si tiene más que 'count', toma un subconjunto variado de sus números
                        k = random.randint(max(1, count - 2), min(len(candidates), count))
                        result_set.update(random.sample(candidates, k))

                # Completar con números del universo disponible
                remaining_needed = count - len(result_set)
                if remaining_needed > 0:
                    available_pool = [n for n in all_pool if n not in result_set]
                    if len(available_pool) >= remaining_needed:
                        result_set.update(random.sample(available_pool, remaining_needed))
                    else:
                        while len(result_set) < count:
                            result_set.add(random.randint(min_val, max_val))

                sorted_tuple = tuple(sorted(result_set))
                if sorted_tuple not in seen or attempts >= 150:
                    seen.add(sorted_tuple)
                    main_nums = sorted(list(result_set))
                    break

            if not main_nums:
                main_nums = sorted(list(result_set))

            special_numbers = self._generate_special_numbers(special_candidates)

            combinations.append(
                GeneratedCombination(
                    number=i + 1,
                    main_numbers=main_nums,
                    special_numbers=special_numbers,
                    special_number=special_numbers[0] if len(special_numbers) == 1 else None,
                )
            )

        return combinations

    def _generate_legacy_balanced(
        self,
        candidates: List[int],
        special_candidates: List[int],
        quantity: int
    ) -> List[GeneratedCombination]:
        combinations = []
        seen = set()

        for i in range(quantity):
            main_nums = self._generate_balanced_set(
                candidates,
                self.rules.main_numbers_min,
                self.rules.main_numbers_max,
                self.rules.main_numbers_count
            )

            attempts = 0
            while tuple(sorted(main_nums)) in seen and attempts < 100:
                main_nums = self._generate_balanced_set(
                    candidates,
                    self.rules.main_numbers_min,
                    self.rules.main_numbers_max,
                    self.rules.main_numbers_count
                )
                attempts += 1

            seen.add(tuple(sorted(main_nums)))

            special_numbers = self._generate_special_numbers(special_candidates)

            combinations.append(
                GeneratedCombination(
                    number=i + 1,
                    main_numbers=sorted(main_nums),
                    special_numbers=special_numbers,
                    special_number=special_numbers[0] if len(special_numbers) == 1 else None,
                )
            )

        return combinations

    def _generate_pure_random(self, quantity: int) -> List[GeneratedCombination]:
        combinations = []
        seen = set()
        count = self.rules.main_numbers_count
        min_val = self.rules.main_numbers_min
        max_val = self.rules.main_numbers_max

        for i in range(quantity):
            attempts = 0
            main_nums = []
            while attempts < 100:
                attempts += 1
                sample = random.sample(range(min_val, max_val + 1), count)
                if tuple(sorted(sample)) not in seen or attempts >= 90:
                    seen.add(tuple(sorted(sample)))
                    main_nums = sorted(sample)
                    break

            special_numbers = self._generate_special_numbers([])

            combinations.append(
                GeneratedCombination(
                    number=i + 1,
                    main_numbers=main_nums,
                    special_numbers=special_numbers,
                    special_number=special_numbers[0] if len(special_numbers) == 1 else None,
                )
            )

        return combinations

    def _generate_special_numbers(self, candidates: List[int]) -> List[int]:
        """Genera las especiales por posición, sin compararlas con principales."""
        count = self.rules.special_numbers_count or 0
        if not count:
            return []
        if self.rules.special_numbers_min is None or self.rules.special_numbers_max is None:
            return []

        pool = sorted(set(candidates))
        if len(pool) < count:
            pool = list(range(
                self.rules.special_numbers_min,
                self.rules.special_numbers_max + 1,
            ))
        return sorted(random.sample(pool, count))

    def _extract_candidates(self, input_str: str, min_val: int, max_val: int) -> List[int]:
        candidates = set()
        digit_sequences = re.findall(r'\d+', input_str)

        for seq in digit_sequences:
            # 1. El número completo si cabe
            val = int(seq)
            if min_val <= val <= max_val:
                candidates.add(val)

            # 2. Descomposición en 1 o 2 dígitos
            for i in range(len(seq)):
                v1 = int(seq[i])
                if min_val <= v1 <= max_val:
                    candidates.add(v1)

                if i < len(seq) - 1:
                    v2 = int(seq[i:i + 2])
                    if min_val <= v2 <= max_val:
                        candidates.add(v2)

        return list(candidates)

    def _generate_balanced_set(self, candidates: List[int], min_val: int, max_val: int, count: int) -> List[int]:
        result_set = set()

        if candidates:
            max_personal = min(len(candidates), max(1, count - 1))
            num_candidates_to_use = random.randint(1, max_personal)
            num_candidates_to_use = min(num_candidates_to_use, count)
            selected_candidates = random.sample(candidates, num_candidates_to_use)
            result_set.update(selected_candidates)

        while len(result_set) < count:
            r = random.randint(min_val, max_val)
            result_set.add(r)

        return list(result_set)
