class LotteryRules {
  final String lotteryId;
  final String name;
  final String country;
  final int mainNumbersCount;
  final int mainNumbersMin;
  final int mainNumbersMax;
  final int? specialNumbersCount;
  final int? specialNumbersMin;
  final int? specialNumbersMax;
  final String? proximoSorteo;

  LotteryRules({
    required this.lotteryId,
    required this.name,
    required this.country,
    required this.mainNumbersCount,
    required this.mainNumbersMin,
    required this.mainNumbersMax,
    this.specialNumbersCount,
    this.specialNumbersMin,
    this.specialNumbersMax,
    this.proximoSorteo,
  });

  factory LotteryRules.fromJson(Map<String, dynamic> json) {
    return LotteryRules(
      lotteryId: json['lottery_id'] as String,
      name: json['name'] as String? ?? json['lottery_id'] as String,
      country: json['country'] as String? ?? '',
      mainNumbersCount: json['main_numbers_count'] as int,
      mainNumbersMin: json['main_numbers_min'] as int,
      mainNumbersMax: json['main_numbers_max'] as int,
      specialNumbersCount: json['special_numbers_count'] as int?,
      specialNumbersMin: json['special_numbers_min'] as int?,
      specialNumbersMax: json['special_numbers_max'] as int?,
      proximoSorteo: _validNextDraw(json['proximo_sorteo']),
    );
  }

  /// Una regla incluida como respaldo puede tener una fecha ya vencida. No se
  /// usa para guardar una jugada si no corresponde a hoy o al futuro.
  static String? _validNextDraw(dynamic rawDate) {
    final value = rawDate?.toString().trim();
    if (value == null || value.isEmpty) return null;

    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return parsed.isBefore(today) ? null : value;
  }

  String get rulesDescription {
    String desc = "$mainNumbersCount números del $mainNumbersMin al $mainNumbersMax.";
    if (specialNumbersCount != null && specialNumbersCount! > 0) {
      String word = specialNumbersCount == 1 ? "número especial" : "números especiales";
      desc = "$mainNumbersCount números del $mainNumbersMin al $mainNumbersMax y $specialNumbersCount $word del $specialNumbersMin al $specialNumbersMax.";
    }
    return desc;
  }
}
