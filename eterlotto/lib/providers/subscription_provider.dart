import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../services/api_service.dart';
import '../services/data_refresh_manager.dart';

class SubscriptionProvider extends ChangeNotifier with WidgetsBindingObserver {
  // 🆔 ID del producto de suscripción en Google Play Console
  static const String monthlySubscriptionId = 'eterlotto_monthly_sub';

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;
  bool get isPremium => _isSubscribed;

  // Diferente de `_isLoading`: este valor representa exclusivamente si ya se
  // recibió el estado VIP del backend para la sesión actual.
  bool _isSubscriptionStatusResolved = false;
  bool get isSubscriptionStatusResolved => _isSubscriptionStatusResolved;

  // Sólo es verdadero cuando el backend confirma que la renovación fue
  // cancelada, pero el periodo VIP actual aún está vigente.
  bool _canRestoreCanceledSubscription = false;
  bool get canRestoreCanceledSubscription => _canRestoreCanceledSubscription;

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

  bool _isSyncingGooglePlay = false;

  String get diagnosticInfo =>
      'Disponibilidad Google Play: $_isAvailable\n'
      'Productos encontrados: ${_products.length}\n'
      'IDs no encontrados por Google: ${_notFoundIDs.isEmpty ? "Ninguno" : _notFoundIDs.join(", ")}\n'
      'Producto cargado: ${_monthlyProduct != null ? "${_monthlyProduct!.title} (${_monthlyProduct!.price})" : "Ninguno"}\n'
      'Estado: ${_errorMessage ?? (_products.isNotEmpty ? "Listo para compra" : "Esperando sincronización con Google Play")}';

  SubscriptionProvider() {
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    DataRefreshManager.instance.refreshNotifier.addListener(
      _onDataRefreshNotification,
    );
  }

  void reset() {
    _isSubscribed = false;
    _isSubscriptionStatusResolved = false;
    _canRestoreCanceledSubscription = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// 🔄 Sincronizar estado VIP real desde el backend (única fuente de la verdad)
  Future<void> refreshSubscriptionStatus() async {
    final userId = await ApiService.getUserId();
    if (userId == null) {
      if (_isSubscribed ||
          _canRestoreCanceledSubscription ||
          !_isSubscriptionStatusResolved) {
        _isSubscribed = false;
        _canRestoreCanceledSubscription = false;
        _isSubscriptionStatusResolved = true;
        notifyListeners();
      }
      return;
    }

    try {
      final subscriptionStatus = await ApiService.getSubscriptionStatus(
        userId: userId,
      );
      final backendPremium = subscriptionStatus['is_premium'] == true;
      final canRestore =
          backendPremium &&
          subscriptionStatus['can_restore_subscription'] == true;
      // Una respuesta iniciada para otra sesión no puede actualizar el estado
      // visual después de un logout/login rápido.
      if (await ApiService.getUserId() != userId) return;
      if (_isSubscribed != backendPremium ||
          _canRestoreCanceledSubscription != canRestore ||
          !_isSubscriptionStatusResolved) {
        _isSubscribed = backendPremium;
        _canRestoreCanceledSubscription = canRestore;
        _isSubscriptionStatusResolved = true;
        notifyListeners();
      }
    } catch (_) {
      // Evita dejar la pantalla bloqueada ante un fallo transitorio. No se
      // altera un estado VIP que ya estuviera confirmado anteriormente.
      if (!_isSubscriptionStatusResolved) {
        _isSubscriptionStatusResolved = true;
        notifyListeners();
      }
    }
  }

  /// 🔄 Reconciliar las compras actuales de Google Play con nuestro backend.
  ///
  /// En Android, queryPastPurchases() del plugin consulta las compras
  /// actualmente disponibles/propias del usuario a través de BillingClient.
  Future<bool> _syncGooglePlayPurchases() async {
    if (!Platform.isAndroid || !_isAvailable || _isSyncingGooglePlay) {
      await refreshSubscriptionStatus();
      return _isSubscribed;
    }

    _isSyncingGooglePlay = true;

    try {
      final androidAddition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();

      if (response.error != null) {
        await refreshSubscriptionStatus();
        return _isSubscribed;
      }

      final GooglePlayPurchaseDetails? currentPurchase = response.pastPurchases
          .where((purchase) => purchase.productID == monthlySubscriptionId)
          .cast<GooglePlayPurchaseDetails?>()
          .firstWhere((purchase) => purchase != null, orElse: () => null);

      if (currentPurchase == null) {
        await refreshSubscriptionStatus();
        return _isSubscribed;
      }

      final result = await _confirmPurchaseWithBackend(currentPurchase);
      await refreshSubscriptionStatus();

      return result && _isSubscribed;
    } catch (_) {
      await refreshSubscriptionStatus();
      return _isSubscribed;
    } finally {
      _isSyncingGooglePlay = false;
    }
  }

  void _onDataRefreshNotification() {
    final module = DataRefreshManager.instance.refreshNotifier.value;
    if (module == RefreshModules.perfil || module == 'all') {
      unawaited(refreshSubscriptionStatus());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncGooglePlayPurchases());
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
        _errorMessage =
            'Google Play Billing no está disponible en este dispositivo.';
      }
    } catch (e) {
      _errorMessage = 'Error inicializando compras: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Consultar los detalles de los productos/suscripciones en Google Play
  Future<void> loadProducts() async {
    try {
      const Set<String> ids = {monthlySubscriptionId};

      final ProductDetailsResponse response = await _iap.queryProductDetails(
        ids,
      );

      if (response.error != null) {
        _products = [];
        _monthlyProduct = null;
        _notFoundIDs = response.notFoundIDs;
        _errorMessage =
            'Error de Google Play (${response.error!.code}): ${response.error!.message}';
        notifyListeners();
        return;
      }

      _products = response.productDetails;
      _notFoundIDs = response.notFoundIDs;

      // Buscar ÚNICAMENTE el Product ID real.
      final ProductDetails? product = _products
          .where((p) => p.id == monthlySubscriptionId)
          .cast<ProductDetails?>()
          .firstWhere((p) => p != null, orElse: () => null);

      if (product == null) {
        _monthlyProduct = null;
        _errorMessage =
            'Google Play no encontró el producto $monthlySubscriptionId';
        notifyListeners();
        return;
      }

      _monthlyProduct = product;
      _errorMessage = null;
    } catch (e) {
      _monthlyProduct = null;
      _errorMessage = 'Error conectando con Google Play: $e';
    }
    notifyListeners();
  }

  Future<bool> _confirmPurchaseWithBackend(
    PurchaseDetails purchaseDetails,
  ) async {
    try {
      final res = await ApiService.confirmSubscription(
        productId: purchaseDetails.productID,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
        orderId: purchaseDetails.purchaseID,
      );

      if (res['success'] == true) {
        _errorMessage = null;
        return true;
      }

      _errorMessage =
          res['error']?.toString() ?? 'Error al confirmar con el servidor';
      return false;
    } catch (_) {
      _errorMessage = 'Error conectando con el servidor';
      return false;
    }
  }

  /// Manejar eventos de actualización de compras
  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        final purchaseError = purchaseDetails.error;
        final errorText =
            '${purchaseError?.code ?? ''} ${purchaseError?.message ?? ''} ${purchaseError?.details ?? ''}'
                .toLowerCase();
        final isItemAlreadyOwned =
            errorText.contains('itemalreadyowned') ||
            errorText.contains('item already owned');

        if (isItemAlreadyOwned) {
          _errorMessage = null;
          notifyListeners();

          final recovered = await _syncGooglePlayPurchases();

          if (recovered) {
            _errorMessage = null;
          } else {
            _errorMessage =
                'Google Play está sincronizando tu suscripción. Intenta nuevamente en unos segundos.';
          }
        } else {
          _errorMessage =
              purchaseDetails.error?.message ?? 'Error al procesar la compra';
        }

        _isLoading = false;
        notifyListeners();

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }

        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.purchased) {
        await _confirmPurchaseWithBackend(purchaseDetails);

        // Sincronizar siempre el estado VIP real desde el backend
        await refreshSubscriptionStatus();
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        await _confirmPurchaseWithBackend(purchaseDetails);
        await refreshSubscriptionStatus();
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Iniciar flujo de compra de la suscripción mensual en Google Play
  Future<bool> buyMonthlySubscription() async {
    // El primer cambio de estado debe ocurrir antes de cualquier llamada a
    // Google Play. Así el usuario recibe confirmación visual inmediata y no
    // puede disparar dos flujos de compra por error.
    if (_isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (_monthlyProduct == null) {
      await loadProducts();

      if (_monthlyProduct == null) {
        _isLoading = false;
        _errorMessage ??=
            'El plan de suscripción no está disponible desde Google Play en este dispositivo. Por favor verifica tu conexión o inténtalo en unos minutos.';
        notifyListeners();
        return false;
      }
    }

    // Antes de abrir el flujo de compra, comprobar el estado actual de Google
    // Play. Esto evita intentar comprar cuando todavía existe una compra activa.
    if (Platform.isAndroid && _isAvailable) {
      final existingPurchase = await _syncGooglePlayPurchases();
      if (existingPurchase) {
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    try {
      PurchaseParam purchaseParam;

      if (Platform.isAndroid && _monthlyProduct is GooglePlayProductDetails) {
        purchaseParam = GooglePlayPurchaseParam(
          productDetails: _monthlyProduct!,
          changeSubscriptionParam: null,
        );
      } else {
        purchaseParam = PurchaseParam(productDetails: _monthlyProduct!);
      }

      // Las suscripciones se compran mediante buyNonConsumable en el plugin de Flutter.
      final purchaseFlowStarted = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!purchaseFlowStarted) {
        _errorMessage = 'No se pudo abrir Google Play para iniciar la compra.';
        _isLoading = false;
        notifyListeners();
      }
      return purchaseFlowStarted;
    } catch (_) {
      _errorMessage = 'No se pudo iniciar la compra. Inténtalo nuevamente.';
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
    } catch (_) {
      if (!silent) {
        _errorMessage = 'No se pudieron restaurar las compras';
      }
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DataRefreshManager.instance.refreshNotifier.removeListener(
      _onDataRefreshNotification,
    );
    _subscription?.cancel();
    super.dispose();
  }
}
