import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../services/api_service.dart';
import '../utils/secure_storage_helper.dart';
import '../services/data_refresh_manager.dart';

class SubscriptionProvider extends ChangeNotifier {
  // 🆔 ID del producto de suscripción en Google Play Console
  static const String monthlySubscriptionId = 'eterlotto_monthly_sub';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FlutterSecureStorage _storage = AppSecureStorage.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ProductDetails? _monthlyProduct;
  ProductDetails? get monthlyProduct => _monthlyProduct;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  List<String> _notFoundIDs = [];
  List<String> get notFoundIDs => _notFoundIDs;

  String get diagnosticInfo =>
      'Disponibilidad Google Play: $_isAvailable\n'
      'Productos encontrados: ${_products.length}\n'
      'IDs no encontrados por Google: ${_notFoundIDs.isEmpty ? "Ninguno" : _notFoundIDs.join(", ")}\n'
      'Producto cargado: ${_monthlyProduct != null ? "${_monthlyProduct!.title} (${_monthlyProduct!.price})" : "Ninguno"}\n'
      'Estado: ${_errorMessage ?? (_products.isNotEmpty ? "Listo para compra" : "Esperando sincronización con Google Play")}';

  SubscriptionProvider() {
    _initialize();
    DataRefreshManager.instance.refreshNotifier.addListener(_onDataRefreshNotification);
  }

  void reset() {
    _isSubscribed = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// 🔄 Sincronizar estado VIP real desde el backend (única fuente de la verdad)
  Future<void> refreshSubscriptionStatus() async {
    try {
      final backendPremium = await ApiService.checkSubscriptionStatus();
      if (_isSubscribed != backendPremium) {
        _isSubscribed = backendPremium;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error actualizando suscripción: $e');
    }
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.perfil || module == 'all') {
      refreshSubscriptionStatus();
    }
  }

  Future<void> _initialize() async {
    // 1. Estado inicial neutro (nunca hereda cache previo de otro usuario)
    _isSubscribed = false;
    notifyListeners();

    // 2. Consultar directamente al backend el estado del usuario autenticado actual
    unawaited(refreshSubscriptionStatus());

    // 3. Escuchar flujo de compras de Google Play
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('❌ Error en el stream de compras: $error');
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    // 4. Verificar disponibilidad del servicio de Google Play Billing y cargar catálogo
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        await loadProducts();
      } else {
        debugPrint('⚠️ Google Play Billing no disponible en este dispositivo');
        _errorMessage = 'Google Play Billing no está disponible en este dispositivo.';
      }
    } catch (e) {
      debugPrint('❌ Error al inicializar InAppPurchase: $e');
      _errorMessage = 'Error inicializando compras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Consultar los detalles de los productos/suscripciones en Google Play
  Future<void> loadProducts() async {
    try {
      const Set<String> ids = {
        monthlySubscriptionId,
      };
      debugPrint('🔍 Consultando Google Play para ID de producto: $monthlySubscriptionId');
      final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

      debugPrint('📦 Productos encontrados: ${response.productDetails.length}');
      debugPrint('⚠️ IDs no encontrados: ${response.notFoundIDs}');

      if (response.error != null) {
        debugPrint('❌ Error Google Play: ${response.error}');
        _products = [];
        _monthlyProduct = null;
        _notFoundIDs = response.notFoundIDs;
        _errorMessage = 'Error de Google Play (${response.error!.code}): ${response.error!.message}';
        notifyListeners();
        return;
      }

      _products = response.productDetails;
      _notFoundIDs = response.notFoundIDs;

      // Buscar ÚNICAMENTE el Product ID real con verificación segura de tipos
      final ProductDetails? product = _products
          .where((p) => p.id == monthlySubscriptionId)
          .cast<ProductDetails?>()
          .firstWhere(
            (p) => p != null,
            orElse: () => null,
          );

      if (product == null) {
        _monthlyProduct = null;
        _errorMessage = 'Google Play no encontró el producto $monthlySubscriptionId';
        debugPrint('❌ Producto no encontrado: $monthlySubscriptionId');
        notifyListeners();
        return;
      }

      _monthlyProduct = product;
      _errorMessage = null;

      debugPrint('✅ Producto encontrado:');
      debugPrint('   ID: ${product.id}');
      debugPrint('   Título: ${product.title}');
      debugPrint('   Precio: ${product.price}');
      debugPrint('   Tipo: ${product.runtimeType}');

      // Información específica de Android
      if (product is GooglePlayProductDetails) {
        debugPrint('   Offer token: ${product.offerToken}');
        debugPrint('   Subscription index: ${product.subscriptionIndex}');
      } else {
        debugPrint('ℹ️ El producto no es GooglePlayProductDetails directo (${product.runtimeType})');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Excepción cargando productos: $e');
      debugPrint(stackTrace.toString());
      _monthlyProduct = null;
      _errorMessage = 'Error conectando con Google Play: $e';
    }
    notifyListeners();
  }

  /// Manejar eventos de actualización de compras
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ Compra pendiente...');
        _isLoading = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ Error en la compra: ${purchaseDetails.error}');
          _errorMessage = purchaseDetails.error?.message ?? 'Error al procesar la compra';
          _isLoading = false;
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased) {
          debugPrint('💳 Compra completada en Google Play. Confirmando con Backend...');
          final res = await ApiService.confirmSubscription(
            productId: purchaseDetails.productID,
            purchaseToken: purchaseDetails.verificationData.serverVerificationData,
            orderId: purchaseDetails.purchaseID,
          );
          if (res['success'] == true) {
            debugPrint('🎉 ¡Suscripción confirmada y guardada en BD!');
          } else {
            debugPrint('⚠️ Servidor no pudo confirmar suscripción: ${res['error']}');
          }
          // Sincronizar siempre el estado VIP real desde el backend
          await refreshSubscriptionStatus();
        } else if (purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('🔄 Compra restaurada. Verificando vigencia con backend...');
          await refreshSubscriptionStatus();
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Iniciar flujo de compra de la suscripción mensual en Google Play
  Future<bool> buyMonthlySubscription() async {
    if (_monthlyProduct == null) {
      debugPrint('⚠️ Producto no disponible para compra. Intentando recargar...');
      _isLoading = true;
      notifyListeners();
      await loadProducts();
      _isLoading = false;
      if (_monthlyProduct == null) {
        _errorMessage ??= 'El plan de suscripción no está disponible desde Google Play en este dispositivo. Por favor verifica tu conexión o inténtalo en unos minutos.';
        notifyListeners();
        return false;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      PurchaseParam purchaseParam;
      if (Platform.isAndroid && _monthlyProduct is GooglePlayProductDetails) {
        final googlePlayProduct = _monthlyProduct as GooglePlayProductDetails;
        debugPrint('🧾 Iniciando compra con Offer token: ${googlePlayProduct.offerToken}');
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: _monthlyProduct!,
          changeSubscriptionParam: null,
        );
      } else {
        purchaseParam = PurchaseParam(
          productDetails: _monthlyProduct!,
        );
      }

      // En Android, las suscripciones se inician como suscripción no consumible
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('❌ Error al iniciar compra: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restaurar compras anteriores
  Future<void> restorePurchases({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      await _iap.restorePurchases();
      await refreshSubscriptionStatus();
    } catch (e) {
      debugPrint('❌ Error al restaurar compras: $e');
      if (!silent) _errorMessage = 'No se pudieron restaurar las compras';
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    DataRefreshManager.instance.refreshNotifier.removeListener(_onDataRefreshNotification);
    _subscription?.cancel();
    super.dispose();
  }
}
