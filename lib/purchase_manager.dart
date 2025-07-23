// PurchaseManager 完全版 - 実際の課金処理実装
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

enum SubscriptionState {
  unknown,
  active,
  expired,
  cancelled,
  gracePeriod,
  billingRetry,
  paused,
  restored,
}

class PurchaseManager {
  // サブスクリプション商品ID
  static const String _premiumProductId_ios = 'com.daito.gym.premium_monthly_subscription';
  static const String _premiumProductId_android = 'premium_monthly_subscription';
  
  static String get premiumProductId => Platform.isIOS 
      ? _premiumProductId_ios 
      : _premiumProductId_android;
  
  // InAppPurchaseインスタンス
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  
  // ストリーム監視
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // 状態管理
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _isInitialized = false;
  SubscriptionState _currentSubscriptionState = SubscriptionState.unknown;
  DateTime? _subscriptionExpiryDate;
  List<ProductDetails> _products = [];
  
  // コールバック
  Function()? onPurchaseSuccess;
  Function(String error)? onPurchaseError;
  Function(SubscriptionState oldState, SubscriptionState newState)? onSubscriptionStateChanged;
  Function()? onSubscriptionRenewed;
  Function()? onSubscriptionExpired;
  
  // シングルトンパターン
  static final PurchaseManager _instance = PurchaseManager._internal();
  factory PurchaseManager() => _instance;
  PurchaseManager._internal();
  
  // 初期化
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      // サービス利用可能確認
      _isAvailable = await _inAppPurchase.isAvailable();
      if (!_isAvailable) {
        print('PurchaseManager: In-app purchases not available');
        return false;
      }
      
      // 商品詳細取得
      await _loadProducts();
      
      // 購入ストリーム監視開始
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('Purchase stream error: $error'),
      );
      
      // 既存の購入を復元
      await _restoreExistingPurchases();
      
      _isInitialized = true;
      print('PurchaseManager: Initialization successful');
      return true;
      
    } catch (e) {
      print('PurchaseManager: Initialization error: $e');
      return false;
    }
  }
  
  // 商品詳細読み込み
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = {premiumProductId};
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }
      
      _products = response.productDetails;
      print('Loaded ${_products.length} products');
      
    } catch (e) {
      print('Error loading products: $e');
    }
  }
  
  // 購入処理
  Future<bool> purchasePremium() async {
    if (!_isAvailable || _purchasePending) {
      print('Purchase not available or pending');
      return false;
    }
    
    try {
      final ProductDetails? productDetails = _products
          .where((product) => product.id == premiumProductId)
          .firstOrNull;
      
      if (productDetails == null) {
        print('Product details not found for: $premiumProductId');
        return false;
      }
      
      _purchasePending = true;
      
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!success) {
        _purchasePending = false;
      }
      
      return success;
      
    } catch (e) {
      _purchasePending = false;
      onPurchaseError?.call('Purchase failed: $e');
      return false;
    }
  }
  
  // 購入復元
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    
    try {
      await _inAppPurchase.restorePurchases();
      print('Purchase restoration completed');
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }
  
  // 購入更新処理
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print('Processing purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _handlePendingPurchase(purchaseDetails);
          break;
        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.restored:
          _handleRestoredPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          _handleCanceledPurchase(purchaseDetails);
          break;
      }
      
      // 処理完了をマーク
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }
  
  // 購入成功処理
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    if (_isPremiumProduct(purchaseDetails.productID)) {
      try {
        // サーバーでの購入検証
        bool verified = await _verifyPurchaseWithServer(purchaseDetails);
        
        if (verified) {
          _updateSubscriptionState(SubscriptionState.active);
          _purchasePending = false;
          onPurchaseSuccess?.call();
          print('Premium subscription activated');
        } else {
          onPurchaseError?.call('Purchase verification failed');
        }
        
      } catch (e) {
        onPurchaseError?.call('Error verifying purchase: $e');
      }
    }
  }
  
  // サーバーでの購入検証
  Future<bool> _verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
    try {
      final String apiUrl = '${Config.apiUrl}/purchase/verify';
      
      final Map<String, dynamic> requestBody = {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'product_id': purchaseDetails.productID,
        'transaction_id': purchaseDetails.purchaseID,
      };
      
      // プラットフォーム固有のレシート情報追加
      if (Platform.isIOS) {
        // iOS: transactionReceipt をbase64エンコード
        if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
          requestBody['receipt_data'] = purchaseDetails.verificationData.serverVerificationData;
        }
      } else if (Platform.isAndroid) {
        // Android: purchaseToken
        if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
          final Map<String, dynamic> serverData = 
              json.decode(purchaseDetails.verificationData.serverVerificationData);
          requestBody['purchase_token'] = serverData['purchaseToken'];
        }
      }
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // TODO: 認証トークンがあれば追加
          // 'Authorization': 'Bearer $authToken',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return responseData['success'] == true;
      }
      
      print('Server verification failed: ${response.statusCode}');
      return false;
      
    } catch (e) {
      print('Error verifying purchase with server: $e');
      return false;
    }
  }
  
  // 既存購入の復元
  Future<void> _restoreExistingPurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring existing purchases: $e');
    }
  }
  
  // その他のハンドラー
  void _handlePendingPurchase(PurchaseDetails purchaseDetails) {
    print('Purchase pending: ${purchaseDetails.productID}');
    _purchasePending = true;
  }
  
  void _handleRestoredPurchase(PurchaseDetails purchaseDetails) {
    if (_isPremiumProduct(purchaseDetails.productID)) {
      _updateSubscriptionState(SubscriptionState.restored);
      print('Premium subscription restored');
    }
  }
  
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    _purchasePending = false;
    final String error = purchaseDetails.error?.message ?? 'Unknown error';
    onPurchaseError?.call(error);
    print('Purchase error: $error');
  }
  
  void _handleCanceledPurchase(PurchaseDetails purchaseDetails) {
    _purchasePending = false;
    print('Purchase canceled: ${purchaseDetails.productID}');
  }
  
  // サブスクリプション状態更新
  void _updateSubscriptionState(SubscriptionState newState) {
    if (_currentSubscriptionState != newState) {
      final SubscriptionState oldState = _currentSubscriptionState;
      _currentSubscriptionState = newState;
      onSubscriptionStateChanged?.call(oldState, newState);
      
      if (newState == SubscriptionState.expired) {
        onSubscriptionExpired?.call();
      }
    }
  }
  
  // プレミアム商品確認
  bool _isPremiumProduct(String productId) {
    return productId == _premiumProductId_ios ||
           productId == _premiumProductId_android;
  }
  
  // サブスクリプション状態チェック（定期実行用）
  Future<void> checkSubscriptionStatus() async {
    try {
      // サーバーから最新の状態を取得
      final String apiUrl = '${Config.apiUrl}/subscription/status';
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // TODO: 認証トークン追加
          // 'Authorization': 'Bearer $authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String status = data['status'] ?? 'unknown';
        final String? expiryDateStr = data['expiry_date'];
        
        // 状態を更新
        SubscriptionState newState;
        switch (status) {
          case 'active':
            newState = SubscriptionState.active;
            break;
          case 'expired':
            newState = SubscriptionState.expired;
            break;
          case 'cancelled':
            newState = SubscriptionState.cancelled;
            break;
          case 'grace_period':
            newState = SubscriptionState.gracePeriod;
            break;
          default:
            newState = SubscriptionState.unknown;
        }
        
        _updateSubscriptionState(newState);
        
        if (expiryDateStr != null) {
          _subscriptionExpiryDate = DateTime.parse(expiryDateStr);
        }
      }
      
    } catch (e) {
      print('Error checking subscription status: $e');
    }
  }
  
  // ゲッター
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  bool get isInitialized => _isInitialized;
  SubscriptionState get currentSubscriptionState => _currentSubscriptionState;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  List<ProductDetails> get products => _products;
  
  // プレミアムユーザー判定
  bool get isPremiumActive {
    return _currentSubscriptionState == SubscriptionState.active ||
           _currentSubscriptionState == SubscriptionState.gracePeriod;
  }
  
  // 商品価格取得
  String? get premiumPrice {
    final ProductDetails? product = _products
        .where((p) => p.id == premiumProductId)
        .firstOrNull;
    return product?.price;
  }
  
  // クリーンアップ
  void dispose() {
    _subscription.cancel();
    print('PurchaseManager disposed');
  }
}

// 拡張メソッド
extension ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}