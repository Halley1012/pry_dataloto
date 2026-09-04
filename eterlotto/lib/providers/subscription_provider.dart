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
      final androidAddition =
          _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();

      if (response.error != null) {
        debugPrint('❌ Error consultando compras de Google Play: ${response.error}');
        await refreshSubscriptionStatus();
        return _isSubscribed;
      }

      final GooglePlayPurchaseDetails? currentPurchase = response.pastPurchases
          .where((purchase) => purchase.productID == monthlySubscriptionId)
          .cast<GooglePlayPurchaseDetails?>()
          .firstWhere(
            (purchase) => purchase != null,
            orElse: () => null,
          );

      if (currentPurchase == null) {
        debugPrint('ℹ️ Google Play no reportó una compra activa para $monthlySubscriptionId');
        await refreshSubscriptionStatus();
        return _isSubscribed;
      }

      debugPrint('🔄 Compra encontrada en Google Play. Confirmando con backend...');

      final result = await _confirmPurchaseWithBackend(currentPurchase);
      await refreshSubscriptionStatus();

      return result && _isSubscribed;
    } catch (e, stackTrace) {
      debugPrint('❌ Excepción sincronizando Google Play: $e');
      debugPrint(stackTrace.toString());
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
      debugPrint('🔄 App volvió a primer plano. Sincronizando suscripción...');
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

      debugPrint(
        '🔍 Consultando Google Play para ID de producto: $monthlySubscriptionId',
      );

      final ProductDetailsResponse response =
          await _iap.queryProductDetails(ids);

      debugPrint('📦 Productos encontrados: ${response.productDetails.length}');
      debugPrint('⚠️ IDs no encontrados: ${response.notFoundIDs}');

      if (response.error != null) {
        debugPrint('❌ Error Google Play: ${response.error}');
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
          .firstWhere(
            (p) => p != null,
            orElse: () => null,
          );

      if (product == null) {
        _monthlyProduct = null;
        _errorMessage =
            'Google Play no encontró el producto $monthlySubscriptionId';
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
        debugPrint(
          'ℹ️ El producto no es GooglePlayProductDetails directo (${product.runtimeType})',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Excepción cargando productos: $e');
      debugPrint(stackTrace.toString());
      _monthlyProduct = null;
      _errorMessage = 'Error conectando con Google Play: $e';
    }
    notifyListeners();
  }

  Future<bool> _confirmPurchaseWithBackend(PurchaseDetails purchaseDetails) async {
    try {
      final res = await ApiService.confirmSubscription(
        productId: purchaseDetails.productID,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
        orderId: purchaseDetails.purchaseID,
      );

      if (res['success'] == true) {
        debugPrint('🎉 ¡Suscripción confirmada y guardada en BD!');
        _errorMessage = null;
        return true;
      }

      debugPrint('⚠️ Servidor no pudo confirmar suscripción: ${res['error']}');
      _errorMessage = res['error']?.toString() ?? 'Error al confirmar con el servidor';
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ Error confirmando suscripción con backend: $e');
      debugPrint(stackTrace.toString());
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
        debugPrint('⏳ Compra pendiente...');
        _isLoading = true;
        notifyListeners();
        continue;
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        final purchaseError = purchaseDetails.error;
        final errorText = '${purchaseError?.code ?? ''} ${purchaseError?.message ?? ''} ${purchaseError?.details ?? ''}'.toLowerCase();
        final isItemAlreadyOwned =
            errorText.contains('itemalreadyowned') ||
            errorText.contains('item already owned');

        debugPrint('❌ Error en la compra: ${purchaseDetails.error}');
        debugPrint('🔎 Código/detalle Google Play: $errorText');

        if (isItemAlreadyOwned) {
          debugPrint(
            '🔄 Google Play indica ITEM_ALREADY_OWNED. Reconciliando compra actual...',
          );

          _errorMessage = null;
          notifyListeners();

          final recovered = await _syncGooglePlayPurchases();

          if (recovered) {
            debugPrint('✅ Suscripción recuperada correctamente desde Google Play.');
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
        debugPrint(
          '💳 Compra completada en Google Play. Confirmando con Backend...',
        );

        await _confirmPurchaseWithBackend(purchaseDetails);

        // Sincronizar siempre el estado VIP real desde el backend
        await refreshSubscriptionStatus();
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        debugPrint(
          '🔄 Compra restaurada. Verificando vigencia con backend...',
        );

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
    if (_monthlyProduct == null) {
      debugPrint(
        '⚠️ Producto no disponible para compra. Intentando recargar...',
      );
      _isLoading = true;
      notifyListeners();
      await loadProducts();
      _isLoading = false;

      if (_monthlyProduct == null) {
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
        debugPrint('✅ Ya existe una suscripción activa según Google Play.');
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      PurchaseParam purchaseParam;

      if (Platform.isAndroid && _monthlyProduct is GooglePlayProductDetails) {
        final googlePlayProduct =
            _monthlyProduct as GooglePlayProductDetails;

        debugPrint(
          '🧾 Iniciando compra con Offer token: ${googlePlayProduct.offerToken}',
        );

        purchaseParam = GooglePlayPurchaseParam(
          productDetails: _monthlyProduct!,
          changeSubscriptionParam: null,
        );
      } else {
        purchaseParam = PurchaseParam(
          productDetails: _monthlyProduct!,
        );
      }

      // Las suscripciones se compran mediante buyNonConsumable en el plugin de Flutter.
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

