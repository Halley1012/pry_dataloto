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
  final Set<int> _selectedCombinationNumbers = <int>{};
  bool _userChangedLottery = false;
  String _languageCode = 'es';

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

    // Sólo mostramos skeleton si todavía no tenemos catálogo utilizable.
    // Si ya hay datos, una recarga nunca debe vaciar ni bloquear la pantalla.
    if (_supportedLotteries.isEmpty) {
      _isLoadingLotteries = true;
      _error = null;
      notifyListeners();
    }

    try {
      final list = await ApiService.getCombinationLotteries(
        forceRefresh: force,
      );
      if (_isDisposed) return;

      final parsed = list.map((e) => LotteryRules.fromJson(e)).toList();

      if (parsed.isEmpty) {
        if (_supportedLotteries.isEmpty) {
          _error = _tr(
            'No se pudieron cargar las loterías disponibles.',
            'Available lotteries could not be loaded.',
            'Não foi possível carregar as loterias disponíveis.',
            'Impossible de charger les loteries disponibles.',
          );
        }
        return;
      }

      // Pintar el catálogo inmediatamente. La lectura del país del usuario no
      // debe mantener la pantalla en skeleton.
      _supportedLotteries = parsed;
      _ensureSelectedLottery();
      _isLoadingLotteries = false;
      _error = null;
      notifyListeners();

      // Ordenar por país en segundo plano. Es una mejora visual, no un
      // requisito para que la pantalla sea utilizable.
      try {
        final storage = AppSecureStorage.instance;
        final storedCountry =
            await storage.read(key: 'pais_nombre') ??
            await storage.read(key: 'pais') ??
            'Colombia';
        if (_isDisposed) return;

        final userPais = storedCountry.trim();
        _supportedLotteries.sort((a, b) {
          final aIsLocal = a.country.trim().toLowerCase() == userPais.toLowerCase();
          final bIsLocal = b.country.trim().toLowerCase() == userPais.toLowerCase();

          if (aIsLocal && !bIsLocal) return -1;
          if (!aIsLocal && bIsLocal) return 1;
          return a.name.compareTo(b.name);
        });

        // La primera selección debe pertenecer al país registrado por el
        // usuario. No la cambiamos si el usuario ya eligió otra manualmente.
        if (!_userChangedLottery) {
          final localLotteries = _supportedLotteries.where(
            (l) => l.country.trim().toLowerCase() == userPais.toLowerCase(),
          );
          if (localLotteries.isNotEmpty) {
            _selectedLottery = localLotteries.first.lotteryId;
          } else {
            _ensureSelectedLottery();
          }
        } else {
          _ensureSelectedLottery();
        }
        notifyListeners();
      } catch (_) {
        // El catálogo ya está visible; fallar al ordenar no debe afectar UX.
      }
    } catch (_) {
      if (_supportedLotteries.isEmpty) {
        _error = _tr(
            'No se pudieron cargar las loterías disponibles.',
            'Available lotteries could not be loaded.',
            'Não foi possível carregar as loterias disponíveis.',
            'Impossible de charger les loteries disponibles.',
          );
      }
    } finally {
      if (_isDisposed) return;
      if (_isLoadingLotteries) {
        _isLoadingLotteries = false;
        notifyListeners();
      }
    }
  }

  void _ensureSelectedLottery() {
    if (_supportedLotteries.isEmpty) {
      _selectedLottery = null;
      return;
    }

    final exists = _supportedLotteries.any(
      (l) => l.lotteryId == _selectedLottery,
    );
    if (!exists) {
      _selectedLottery = _supportedLotteries.first.lotteryId;
    }
  }

  void setLanguageCode(String languageCode) {
    _languageCode = languageCode;
  }

  String _tr(String es, String en, String pt, String fr) {
    return switch (_languageCode) {
      'en' => en,
      'pt' => pt,
      'fr' => fr,
      _ => es,
    };
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
  Set<int> get selectedCombinationNumbers => Set.unmodifiable(_selectedCombinationNumbers);
  int get selectedCount => _selectedCombinationNumbers.length;
  bool get hasSelectedCombinations => _selectedCombinationNumbers.isNotEmpty;

  bool isCombinationSelected(GeneratedCombination combination) =>
      _selectedCombinationNumbers.contains(combination.number);

  void toggleCombinationSelection(GeneratedCombination combination) {
    if (_selectedCombinationNumbers.contains(combination.number)) {
      _selectedCombinationNumbers.remove(combination.number);
    } else {
      _selectedCombinationNumbers.add(combination.number);
    }
    notifyListeners();
  }

  void clearCombinationSelection() {
    if (_selectedCombinationNumbers.isEmpty) return;
    _selectedCombinationNumbers.clear();
    notifyListeners();
  }

  void toggleSelectAllCombinations() {
    if (_combinations.isEmpty) return;

    if (_selectedCombinationNumbers.length == _combinations.length) {
      _selectedCombinationNumbers.clear();
    } else {
      _selectedCombinationNumbers
        ..clear()
        ..addAll(_combinations.map((combo) => combo.number));
    }
    notifyListeners();
  }

  void removeSelectedCombinations() {
    if (_selectedCombinationNumbers.isEmpty) return;
    _combinations.removeWhere(
      (combo) => _selectedCombinationNumbers.contains(combo.number),
    );
    _selectedCombinationNumbers.clear();
    notifyListeners();
  }

  void clearGeneratedCombinations() {
    if (_combinations.isEmpty) return;
    _combinations = [];
    _selectedCombinationNumbers.clear();
    notifyListeners();
  }
  
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
    _userChangedLottery = true;
    _combinations = [];
    _selectedCombinationNumbers.clear();
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
      _error = _tr(
        "Para 'Solo mis números' necesitas al menos $count números válidos. Tienes ${currentActive.length}.",
        "For 'Only my numbers' you need at least $count valid numbers. You have ${currentActive.length}.",
        "Para 'Somente meus números' você precisa de pelo menos $count números válidos. Você tem ${currentActive.length}.",
        "Pour 'Mes numéros uniquement', vous avez besoin d’au moins $count numéros valides. Vous en avez ${currentActive.length}.",
      );
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
      _selectedCombinationNumbers.clear();
    } else {
      _error = result['error'] ??
          _tr(
            'Error desconocido',
            'Unknown error',
            'Erro desconhecido',
            'Erreur inconnue',
          );
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveSelected(String userId) async {
    if (_selectedLottery == null || _selectedCombinationNumbers.isEmpty) {
      return false;
    }

    final selected = _combinations
        .where((combo) => _selectedCombinationNumbers.contains(combo.number))
        .toList(growable: false);

    return _saveCombinations(userId, selected);
  }

  Future<bool> saveAll(String userId) async {
    if (_selectedLottery == null || _combinations.isEmpty) return false;
    return _saveCombinations(userId, _combinations);
  }

  Future<bool> _saveCombinations(
    String userId,
    List<GeneratedCombination> combinationsToSave,
  ) async {
    if (_selectedLottery == null || combinationsToSave.isEmpty) return false;

    bool allSuccess = true;

    final rules = selectedLotteryRules;
    final saveRoute = rules?.route ?? _selectedLottery!;
    final rawNextDrawDate = rules?.proximoSorteo;
    final String? nextDrawDate =
        rawNextDrawDate != null && rawNextDrawDate.trim().isNotEmpty
            ? ApiService.getProximoSorteoFecha(
                saveRoute,
                fechaPrediccion: rawNextDrawDate,
              )
            : null;

    for (final combo in combinationsToSave) {
      try {
        await ApiService.crearJugadaGenerica(
          saveRoute,
          combo.mainNumbers,
          userId,
          loteriaId: rules?.catalogLotteryId,
          specialNumbers: combo.specialNumbers,
          fechaSorteo: nextDrawDate,
        );
      } catch (_) {
        allSuccess = false;
      }
    }

    if (allSuccess) {
      _selectedCombinationNumbers.clear();
      notifyListeners();
    }

    return allSuccess;
  }

}
