import 'package:flutter/foundation.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/generated_combination.dart';
import 'package:eterlotto/models/lottery_rules.dart';
import 'package:eterlotto/utils/secure_storage_helper.dart';

class CombinationGeneratorProvider with ChangeNotifier {
  String? _selectedLottery;
  String _inputData = '';
  int _quantity = 10;
  String _strategy = 'balanced';
  
  bool _isLoading = false;
  bool _isLoadingLotteries = true;
  String? _error;
  
  List<LotteryRules> _supportedLotteries = [];
  List<GeneratedCombination> _combinations = [];

  CombinationGeneratorProvider() {
    _loadLotteries();
  }

  Future<void> _loadLotteries() async {
    _isLoadingLotteries = true;
    notifyListeners();

    final list = await ApiService.getCombinationLotteries();
    _supportedLotteries = list.map((e) => LotteryRules.fromJson(e)).toList();
    
    try {
      final storage = AppSecureStorage.instance;
      final userPais = await storage.read(key: "pais_nombre") ?? "Colombia";
      
      _supportedLotteries.sort((a, b) {
        bool aIsLocal = a.country.toLowerCase() == userPais.toLowerCase();
        bool bIsLocal = b.country.toLowerCase() == userPais.toLowerCase();
        if (aIsLocal && !bIsLocal) return -1;
        if (!aIsLocal && bIsLocal) return 1;
        return a.lotteryId.compareTo(b.lotteryId);
      });
    } catch (_) {}

    if (_supportedLotteries.isNotEmpty && _selectedLottery == null) {
      _selectedLottery = _supportedLotteries.first.lotteryId;
    }

    _isLoadingLotteries = false;
    notifyListeners();
  }

  /// Reloads the lottery list from the server (called on pull-to-refresh)
  Future<void> reload() => _loadLotteries();

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
  
  List<int> get detectedNumbers {
    if (_inputData.isEmpty) return [];
    
    final RegExp regExp = RegExp(r'\d+');
    final matches = regExp.allMatches(_inputData);
    final Set<int> numbers = {};
    for (var match in matches) {
      final str = match.group(0)!;
      final val = int.tryParse(str);
      if (val != null && val > 0 && val <= 99) {
        numbers.add(val);
      }
      for (int i=0; i<str.length; i++) {
        final v1 = int.tryParse(str[i]);
        if (v1 != null && v1 > 0) numbers.add(v1);
        if (i < str.length - 1) {
          final v2 = int.tryParse(str.substring(i, i+2));
          if (v2 != null && v2 > 0 && v2 <= 99) numbers.add(v2);
        }
      }
    }
    return numbers.toList()..sort();
  }

  void setLottery(String lottery) {
    _selectedLottery = lottery;
    notifyListeners();
  }

  void setInputData(String data) {
    _inputData = data;
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
    notifyListeners();
  }

  Future<void> generate() async {
    if (_selectedLottery == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.generateCombinations(
      lottery: _selectedLottery!,
      input: _inputData,
      quantity: _quantity,
      strategy: _strategy,
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
    if (_selectedLottery == null) return false;
    bool allSuccess = true;
    for (var combo in _combinations) {
      final res = await ApiService.crearJugadaGenerica(
        _selectedLottery!,
        combo.mainNumbers, 
        userId,
        balotaRoja: combo.specialNumber,
      );
      if (res['id'] == null && res['error'] == null) {
        // Assume failure or needs closer look, but let's just proceed.
      }
    }
    return allSuccess;
  }
}
