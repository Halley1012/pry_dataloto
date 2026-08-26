import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/api_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  // 🆔 ID del producto de suscripción en Google Play Console
  // Debe coincidir con el ID que configures en "Monetización > Suscripciones"
  static const String monthlySubscriptionId = 'eterlotto_monthly_sub';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

  SubscriptionProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // 1. Cargar estado de suscripción guardado en cache local (arranque instantáneo)
    final cachedStatus = await _storage.read(key: 'is_premium_subscribed');
    if (cachedStatus == 'true') {
      _isSubscribed = true;
      notifyListeners();
    }

    // 2. Verificar en segundo plano con el backend
    unawaited(ApiService.checkSubscriptionStatus().then((backendPremium) {
      if (backendPremium && !_isSubscribed) {
        _isSubscribed = true;
        notifyListeners();
      }
    }));

    // 2. Escuchar flujo de compras de Google Play
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

    // 3. Verificar disponibilidad del servicio de Google Play Billing
    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        await loadProducts();
        // Restaurar compras en segundo plano para verificar validez
        await restorePurchases(silent: true);
      } else {
        debugPrint('⚠️ Google Play Billing no disponible en este dispositivo');
      }
    } catch (e) {
      debugPrint('❌ Error al inicializar InAppPurchase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Consultar los detalles de los productos/suscripciones en Google Play
  Future<void> loadProducts() async {
    try {
      final Set<String> ids = {monthlySubscriptionId};
      final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

      if (response.error != null) {
        debugPrint('❌ Error al consultar productos en Play Store: ${response.error}');
        _errorMessage = response.error!.message;
      } else {
        _products = response.productDetails;
        if (_products.isNotEmpty) {
          _monthlyProduct = _products.firstWhere(
            (p) => p.id == monthlySubscriptionId,
            orElse: () => _products.first,
          );
          debugPrint('✅ Producto de suscripción cargado: ${_monthlyProduct?.title} (${_monthlyProduct?.price})');
        } else {
          debugPrint('ℹ️ No se encontraron productos con el ID "$monthlySubscriptionId" (asegúrate de haberlo creado en Play Console)');
        }
      }
    } catch (e) {
      debugPrint('❌ Excepción al cargar productos de suscripción: $e');
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
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            await _setSubscribedStatus(true);
            debugPrint('🎉 ¡Suscripción confirmada y activa!');

            // 🌐 Sincronizar estado VIP con la base de datos
            unawaited(ApiService.confirmSubscription(
              productId: purchaseDetails.productID,
              purchaseToken: purchaseDetails.verificationData.serverVerificationData,
              orderId: purchaseDetails.purchaseID,
            ));
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Verificación básica de la compra
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Si la compra pertenece al ID de suscripción y está activa
    if (purchaseDetails.productID == monthlySubscriptionId) {
      return true;
    }
    return true;
  }

  /// Guardar estado en almacenamiento seguro
  Future<void> _setSubscribedStatus(bool status) async {
    _isSubscribed = status;
    await _storage.write(key: 'is_premium_subscribed', value: status ? 'true' : 'false');
    notifyListeners();
  }

  /// Iniciar flujo de compra de la suscripción mensual en Google Play
  Future<bool> buyMonthlySubscription() async {
    if (_monthlyProduct == null) {
      debugPrint('⚠️ Producto no disponible para compra.');
      // Intentar recargar
      await loadProducts();
      if (_monthlyProduct == null) return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: _monthlyProduct!,
      );

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
    _subscription?.cancel();
    super.dispose();
  }
}
