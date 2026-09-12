import 'package:flutter/foundation.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/generated_combination.dart';
import 'package:eterlotto/models/lottery_rules.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';

class CombinationGeneratorProvider with ChangeNotifier {
  String? _selectedLottery;
  String _inputData = '';
  int _quantity = 10;
  String _strategy = 'only_mine';
  final Set<int> _excludedNumbers = {};
  
  bool _isLoading = false;
  bool _isLoadingLotteries = true;
  bool _isDisposed = false;
  String? _error;
  
  List<LotteryRules> _supportedLotteries = [];
  List<GeneratedCombination> _combinations = [];

  CombinationGeneratorProvider() {
    // La apertura normal aprovecha la caché; el refresh manual usa force=true.
    ApiService.combinationLotteryRulesNotifier.addListener(
      _refreshFromBackgroundRules,
    );
    _loadLotteries();
  }

  @override
  void dispose() {
    _isDisposed = true;
    ApiService.combinationLotteryRulesNotifier.removeListener(
      _refreshFromBackgroundRules,
    );
    super.dispose();
  }

  void _refreshFromBackgroundRules() {
    // El provider recibió una actualización SWR válida. Recarga desde la
    // caché fresca sin mostrar Skeleton si ya estaba mostrando el catálogo.
    if (!_isLoadingLotteries) {
      _loadLotteries();
    }
  }

  Future<void> _loadLotteries({bool force = false}) async {
    if (_isDisposed) return;
    _isLoadingLotteries = true;
    _error = null;
    notifyListeners();

    try {
      final list = await ApiService.getCombinationLotteries(forceRefresh: force);
      if (_isDisposed) return;
      _supportedLotteries = list.map((e) => LotteryRules.fromJson(e)).toList();

      try {
        final storage = AppSecureStorage.instance;
        final userPais = await storage.read(key: "pais_nombre") ?? "Colombia";

        _supportedLotteries.sort((a, b) {
          final aIsLocal = a.country.toLowerCase() == userPais.toLowerCase();
          final bIsLocal = b.country.toLowerCase() == userPais.toLowerCase();

          if (aIsLocal && !bIsLocal) return -1;
          if (!aIsLocal && bIsLocal) return 1;
          return a.name.compareTo(b.name);
        });
      } catch (_) {}

      if (_supportedLotteries.isNotEmpty) {
        final exists = _supportedLotteries.any(
          (l) => l.lotteryId == _selectedLottery,
        );

        if (!exists) {
          _selectedLottery = _supportedLotteries.first.lotteryId;
        }
      } else {
        _error = 'No se pudieron cargar las loterías disponibles.';
      }
    } catch (_) {
      _error = 'No se pudieron cargar las loterías disponibles.';
    } finally {
      if (_isDisposed) return;
      _isLoadingLotteries = false;
      notifyListeners();
    }
  }

  /// Reloads the lottery list from the server (called on pull-to-refresh)
  Future<void> reload() => _loadLotteries(force: true);

  String? get selectedLottery => _selectedLottery;
  LotteryRules? get selectedLotteryRules {
    if (_selectedLottery == null) return null;
    try {
      return _supportedLotteries.firstWhere((r) => r.lotteryId == _selectedLottery);
    } catch (_) {
      return null;
    }
  }
  
  List<LotteryRules> get supportedLotteries => _supportedLotteries;
  
  String get inputData => _inputData;
  int get quantity => _quantity;
  String get strategy => _strategy;
  
  bool get isLoading => _isLoading;
  bool get isLoadingLotteries => _isLoadingLotteries;
  String? get error => _error;
  List<GeneratedCombination> get combinations => _combinations;
  
  Set<int> _extractDetectedNumbers(String data) {
    if (data.isEmpty) return {};

    final rules = selectedLotteryRules;
    final int minVal = rules?.mainNumbersMin ?? 1;
    final int maxVal = rules?.mainNumbersMax ?? 99;
    final int specialMax = rules?.specialNumbersMax ?? 0;
    // Permite candidatos válidos según el rango dinámico de la lotería activa
    final int effectiveMax = maxVal > specialMax ? maxVal : specialMax;
    
    final RegExp regExp = RegExp(r'\d+');
    final matches = regExp.allMatches(data);
    final Set<int> numbers = {};
    for (var match in matches) {
      final str = match.group(0)!;
      final val = int.tryParse(str);
      if (val != null && val >= minVal && val <= effectiveMax) {
        numbers.add(val);
      }
      for (int i = 0; i < str.length; i++) {
        final v1 = int.tryParse(str[i]);
        if (v1 != null && v1 >= minVal && v1 <= effectiveMax) {
          numbers.add(v1);
        }
        if (i < str.length - 1) {
          final v2 = int.tryParse(str.substring(i, i + 2));
          if (v2 != null && v2 >= minVal && v2 <= effectiveMax) {
            numbers.add(v2);
          }
        }
      }
    }
    return numbers;
  }

  List<int> get detectedNumbers {
    return _extractDetectedNumbers(_inputData).toList()..sort();
  }

  List<int> get activeNumbers {
    return detectedNumbers.where((n) => !_excludedNumbers.contains(n)).toList();
  }

  bool isNumberExcluded(int number) => _excludedNumbers.contains(number);

  void toggleExcludeNumber(int number) {
    if (_excludedNumbers.contains(number)) {
      _excludedNumbers.remove(number);
    } else {
      _excludedNumbers.add(number);
    }
    notifyListeners();
  }

  void removeNumber(int number) {
    _excludedNumbers.add(number);
    notifyListeners();
  }

  void setLottery(String lottery) {
    if (_selectedLottery == lottery) return;
    _selectedLottery = lottery;
    _combinations = [];
    _error = null;
    _excludedNumbers.clear();
    notifyListeners();
  }

  void setInputData(String data) {
    _inputData = data;
    final currentDetected = _extractDetectedNumbers(data);
    _excludedNumbers.removeWhere((n) => !currentDetected.contains(n));
    notifyListeners();
  }

  void incrementQuantity() {
    if (_quantity < 10) {
      _quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity() {
    if (_quantity > 1) {
      _quantity--;
      notifyListeners();
    }
  }

  void setStrategy(String strategy) {
    _strategy = strategy;
    _error = null;
    notifyListeners();
  }

  Future<void> generate() async {
    if (_selectedLottery == null) return;

    final count = selectedLotteryRules?.mainNumbersCount ?? 5;
    final currentActive = activeNumbers;

    if (_strategy == 'only_mine' && currentActive.length < count) {
      _error = "Para 'Solo mis números' necesitas al menos $count números válidos. Tienes ${currentActive.length}.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.generateCombinations(
      lottery: _selectedLottery!,
      input: _inputData,
      quantity: _quantity,
      strategy: _strategy,
      selectedNumbers: currentActive,
    );

    if (result['success']) {
      final data = GenerationResult.fromJson(result['data']);
      _combinations = data.combinations;
    } else {
      _error = result['error'] ?? 'Error desconocido';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveAll(String userId) async {
    if (_selectedLottery == null || _combinations.isEmpty) return false;

    bool allSuccess = true;

    // Las combinaciones generadas pertenecen al próximo sorteo mostrado
    // en las reglas de la lotería. Guardamos esa fecha para que Mis Jugadas
    // no las marque erróneamente con la fecha de hoy.
    final rawNextDrawDate = selectedLotteryRules?.proximoSorteo;
    final String? nextDrawDate =
        rawNextDrawDate != null && rawNextDrawDate.trim().isNotEmpty
            ? ApiService.getProximoSorteoFecha(
                _selectedLottery!,
                fechaPrediccion: rawNextDrawDate,
              )
            : null;

    for (final combo in _combinations) {
      try {
        await ApiService.crearJugadaGenerica(
          _selectedLottery!,
          combo.mainNumbers,
          userId,
          specialNumbers: combo.specialNumbers,
          fechaSorteo: nextDrawDate,
        );
      } catch (_) {
        allSuccess = false;
      }
    }

    return allSuccess;
  }
}
