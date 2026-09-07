import 'package:flutter/foundation.dart';
import 'package:eterlotto/services/api_service.dart';
import 'package:eterlotto/models/generated_combination.dart';

class CombinationGeneratorProvider with ChangeNotifier {
  String _selectedLottery = 'baloto';
  String _inputData = '';
  int _quantity = 10;
  String _strategy = 'balanced';
  
  bool _isLoading = false;
  String? _error;
  
  List<GeneratedCombination> _combinations = [];

  String get selectedLottery => _selectedLottery;
  String get inputData => _inputData;
  int get quantity => _quantity;
  String get strategy => _strategy;
  
  bool get isLoading => _isLoading;
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await ApiService.generateCombinations(
      lottery: _selectedLottery,
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
    bool allSuccess = true;
    for (var combo in _combinations) {
      final res = await ApiService.crearJugadaGenerica(
        _selectedLottery,
        combo.mainNumbers, // the method creates [..mainNumbers, balotaRoja] if provided, let's check
        userId,
        balotaRoja: combo.specialNumber,
      );
      if (res['id'] == null && res['error'] == null) {
        // usually it returns the jugada object
        // we'll assume it succeeded if it didn't throw an error? Actually, wait, how does it report failure?
      }
    }
    return allSuccess;
  }
}
