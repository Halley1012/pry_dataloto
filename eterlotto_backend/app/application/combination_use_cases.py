from typing import List, Dict, Any
from app.domain.combination_generator import CombinationGenerator, LotteryRules, GeneratedCombination

# Dictionary holding the rules for supported lotteries
SUPPORTED_LOTTERIES = {
    "baloto": LotteryRules(
        lottery_id="baloto",
        main_numbers_count=5,
        main_numbers_min=1,
        main_numbers_max=43,
        special_numbers_count=1,
        special_numbers_min=1,
        special_numbers_max=16
    ),
    "miloto": LotteryRules(
        lottery_id="miloto",
        main_numbers_count=5,
        main_numbers_min=1,
        main_numbers_max=39,
        special_numbers_count=None,
        special_numbers_min=None,
        special_numbers_max=None
    ),
    "colorloto": LotteryRules(
        lottery_id="colorloto",
        main_numbers_count=6,
        main_numbers_min=1,
        main_numbers_max=45,
        special_numbers_count=None,
        special_numbers_min=None,
        special_numbers_max=None
    )
}

class CombinationUseCases:
    def get_supported_lotteries(self) -> List[str]:
        return list(SUPPORTED_LOTTERIES.keys())

    def get_lottery_rules(self, lottery_id: str) -> LotteryRules:
        rules = SUPPORTED_LOTTERIES.get(lottery_id.lower())
        if not rules:
            raise ValueError(f"Lottery '{lottery_id}' no está soportada.")
        return rules

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
        
        # Return the format requested by the frontend
        return {
            "lottery": lottery_id.lower(),
            "source": input_str,
            "quantity": quantity,
            "combinations": [c.model_dump() for c in combinations]
        }
