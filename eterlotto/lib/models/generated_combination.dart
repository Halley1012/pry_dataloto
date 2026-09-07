class GeneratedCombination {
  final int number;
  final List<int> mainNumbers;
  final int? specialNumber;

  GeneratedCombination({
    required this.number,
    required this.mainNumbers,
    this.specialNumber,
  });

  factory GeneratedCombination.fromJson(Map<String, dynamic> json) {
    return GeneratedCombination(
      number: json['number'] as int,
      mainNumbers: List<int>.from(json['main_numbers'] ?? []),
      specialNumber: json['special_number'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'main_numbers': mainNumbers,
      'special_number': specialNumber,
    };
  }
}

class GenerationResult {
  final String lottery;
  final String source;
  final int quantity;
  final List<GeneratedCombination> combinations;

  GenerationResult({
    required this.lottery,
    required this.source,
    required this.quantity,
    required this.combinations,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    return GenerationResult(
      lottery: json['lottery'] as String,
      source: json['source'] as String,
      quantity: json['quantity'] as int,
      combinations: (json['combinations'] as List)
          .map((c) => GeneratedCombination.fromJson(c))
          .toList(),
    );
  }
}
