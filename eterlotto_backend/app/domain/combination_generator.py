import random
import re
from typing import List, Optional
from pydantic import BaseModel

class LotteryRules(BaseModel):
    lottery_id: str
    name: str
    country: str
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
    special_number: Optional[int] = None

class CombinationGenerator:
    def __init__(self, rules: LotteryRules):
        self.rules = rules

    def generate(self, input_str: str, quantity: int, strategy: str = "balanced") -> List[GeneratedCombination]:
        candidates = self._extract_candidates(input_str, self.rules.main_numbers_min, self.rules.main_numbers_max)
        
        special_candidates = []
        if self.rules.special_numbers_count:
            special_candidates = self._extract_candidates(input_str, self.rules.special_numbers_min, self.rules.special_numbers_max)

        combinations = []
        seen = set()

        for i in range(quantity):
            # Generate main numbers
            main_nums = self._generate_balanced_set(
                candidates,
                self.rules.main_numbers_min,
                self.rules.main_numbers_max,
                self.rules.main_numbers_count
            )

            # Ensure uniqueness of the combination
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

            # Generate special numbers if needed
            special_number = None
            if self.rules.special_numbers_count and self.rules.special_numbers_count == 1:
                special_nums = self._generate_balanced_set(
                    special_candidates,
                    self.rules.special_numbers_min,
                    self.rules.special_numbers_max,
                    self.rules.special_numbers_count
                )
                special_number = special_nums[0] if special_nums else None

            combinations.append(
                GeneratedCombination(
                    number=i + 1,
                    main_numbers=sorted(main_nums),
                    special_number=special_number
                )
            )

        return combinations

    def _extract_candidates(self, input_str: str, min_val: int, max_val: int) -> List[int]:
        candidates = set()
        # Find all sequences of digits
        digit_sequences = re.findall(r'\d+', input_str)

        for seq in digit_sequences:
            # 1. Take the exact number if it fits
            val = int(seq)
            if min_val <= val <= max_val:
                candidates.add(val)

            # 2. Break down larger numbers into 1 or 2 digits
            for i in range(len(seq)):
                # single digit
                val = int(seq[i])
                if min_val <= val <= max_val:
                    candidates.add(val)

                # double digits
                if i < len(seq) - 1:
                    val = int(seq[i:i + 2])
                    if min_val <= val <= max_val:
                        candidates.add(val)

        return list(candidates)

    def _generate_balanced_set(self, candidates: List[int], min_val: int, max_val: int, count: int) -> List[int]:
        result_set = set()

        if candidates:
            # Use a random subset of candidates (between 1 and count-1)
            # Or up to len(candidates) if less
            max_personal = min(len(candidates), max(1, count - 1))
            # Pick a random amount of personal numbers to use
            num_candidates_to_use = random.randint(1, max_personal)
            
            # Don't try to sample more than what we need
            num_candidates_to_use = min(num_candidates_to_use, count)
            
            selected_candidates = random.sample(candidates, num_candidates_to_use)
            result_set.update(selected_candidates)

        # Fill the rest with random valid numbers
        while len(result_set) < count:
            r = random.randint(min_val, max_val)
            result_set.add(r)

        return list(result_set)
