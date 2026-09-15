/// Distribución estructural de las balotas de una lotería.
///
/// El orden es parte del dato: [principales] [especiales] [complementaria].
/// Por ello nunca se infiere un rol comparando valores ni se eliminan números
/// repetidos. Un 9 principal y un 9 especial son posiciones distintas.
class LotteryNumberLayout {
  final int mainCount;
  final int specialCount;
  final int complementaryCount;

  const LotteryNumberLayout({
    required this.mainCount,
    required this.specialCount,
    required this.complementaryCount,
  });

  factory LotteryNumberLayout.fromConfig({
    required int maxSeleccion,
    required int totalBalotasSorteo,
    required bool tieneComplementario,
  }) {
    final main = maxSeleccion.clamp(0, totalBalotasSorteo) as int;
    final complementary = tieneComplementario ? 1 : 0;
    final special =
        (totalBalotasSorteo - main - complementary).clamp(0, totalBalotasSorteo)
            as int;
    return LotteryNumberLayout(
      mainCount: main,
      specialCount: special,
      complementaryCount: complementary,
    );
  }

  /// Construye la distribución desde un mapa de catálogo/API sin deducirla de
  /// los números de una jugada o resultado.
  factory LotteryNumberLayout.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    int readInt(List<String> keys, int fallback) {
      for (final key in keys) {
        final value = int.tryParse(map[key]?.toString() ?? '');
        if (value != null) return value;
      }
      return fallback;
    }

    bool readBool(List<String> keys) =>
        keys.any((key) => map[key] == true || map[key]?.toString() == 'true');

    final main = readInt(const ['max_seleccion', 'maxSeleccion'], 5);
    final complementary = readBool(
      const ['tiene_complementario', 'tieneComplementario'],
    );
    final declaredSpecials = readInt(
      const ['special_numbers_count', 'specialNumbersCount'],
      readInt(const ['max_balotas_rojas', 'maxBalotasRojas'], 0) > 0 ? 1 : 0,
    );
    final total = readInt(
      const ['total_balotas_sorteo', 'totalBalotasSorteo'],
      main + declaredSpecials + (complementary ? 1 : 0),
    );
    return LotteryNumberLayout.fromConfig(
      maxSeleccion: main,
      totalBalotasSorteo: total,
      tieneComplementario: complementary,
    );
  }

  LotteryNumberGroups split(Iterable<dynamic> rawNumbers) {
    final numbers = rawNumbers
        .map((value) => int.tryParse(value.toString()))
        .whereType<int>()
        .toList(growable: false);
    final mainEnd = mainCount.clamp(0, numbers.length) as int;
    final specialEnd =
        (mainEnd + specialCount).clamp(mainEnd, numbers.length) as int;
    final complementaryEnd =
        (specialEnd + complementaryCount).clamp(specialEnd, numbers.length)
            as int;
    return LotteryNumberGroups(
      main: numbers.sublist(0, mainEnd),
      specials: numbers.sublist(mainEnd, specialEnd),
      complementary: numbers.sublist(specialEnd, complementaryEnd),
    );
  }
}

class LotteryNumberGroups {
  final List<int> main;
  final List<int> specials;
  final List<int> complementary;

  const LotteryNumberGroups({
    required this.main,
    required this.specials,
    required this.complementary,
  });

  List<int> get ordered => [...main, ...specials, ...complementary];
}
