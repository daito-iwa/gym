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
  static const String _premiumProductId_ios = 'com.daito.gymnasticsai.premium_monthly_subscription';
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
        print('Requested product ID: $premiumProductId');
      }
      
      _products = response.productDetails;
      print('Loaded ${_products.length} products');
      for (var product in _products) {
        print('Product ID: ${product.id}, Title: ${product.title}, Price: ${product.price}');
      }
      
    } catch (e) {
      print('Error loading products: $e');
    }
  }
  
  // 購入処理
  Future<bool> purchasePremium() async {
    if (!_isAvailable) {
      print('Purchase not available - service not initialized');
      onPurchaseError?.call('購入サービスが利用できません。アプリを再起動してください。');
      return false;
    }
    
    if (_purchasePending) {
      print('Purchase already pending');
      onPurchaseError?.call('購入処理が進行中です。しばらくお待ちください。');
      return false;
    }
    
    try {
      final ProductDetails? productDetails = _products
          .where((product) => product.id == premiumProductId)
          .firstOrNull;
      
      if (productDetails == null) {
        print('Product details not found for: $premiumProductId');
        print('Available products: ${_products.map((p) => p.id).join(", ")}');
        
        // 商品情報を再取得を試行
        await _loadProducts();
        final retryProductDetails = _products
            .where((product) => product.id == premiumProductId)
            .firstOrNull;
            
        if (retryProductDetails == null) {
          onPurchaseError?.call('商品情報が見つかりません。インターネット接続を確認し、しばらく後に再試行してください。');
          return false;
        }
        // 再取得した商品情報を使用
        return await _executePurchase(retryProductDetails);
      }
      
      return await _executePurchase(productDetails);
      
    } catch (e) {
      _purchasePending = false;
      print('Purchase error: $e');
      
      // より具体的なエラーメッセージ
      if (e.toString().contains('network')) {
        onPurchaseError?.call('ネットワークエラーが発生しました。インターネット接続を確認してください。');
      } else if (e.toString().contains('timeout')) {
        onPurchaseError?.call('購入処理がタイムアウトしました。しばらく後に再試行してください。');
      } else {
        onPurchaseError?.call('購入エラーが発生しました。App Storeの設定を確認し、しばらく後に再試行してください。');
      }
      return false;
    }
  }
  
  Future<bool> _executePurchase(ProductDetails productDetails) async {
    _purchasePending = true;
    
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // タイムアウト処理を追加
      bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam)
          .timeout(Duration(seconds: 30), onTimeout: () {
        _purchasePending = false;
        throw TimeoutException('Purchase timeout', Duration(seconds: 30));
      });
      
      if (!success) {
        _purchasePending = false;
        onPurchaseError?.call('購入を開始できませんでした。しばらく後に再試行してください。');
      }
      
      return success;
      
    } catch (e) {
      _purchasePending = false;
      rethrow;
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
    final error = purchaseDetails.error;
    
    // より詳細なエラーログ
    print('Purchase error details:');
    print('  Product ID: ${purchaseDetails.productID}');
    print('  Error code: ${error?.code}');
    print('  Error message: ${error?.message}');
    print('  Error details: ${error?.details}');
    
    String userMessage = _getLocalizedErrorMessage(error);
    onPurchaseError?.call(userMessage);
  }
  
  String _getLocalizedErrorMessage(IAPError? error) {
    if (error == null) return '購入に失敗しました。しばらく後に再試行してください。';
    
    switch (error.code) {
      case 'network_error':
        return 'ネットワークエラーが発生しました。インターネット接続を確認してください。';
      case 'item_unavailable':
        return 'この商品は現在利用できません。App Storeの設定を確認してください。';
      case 'item_already_owned':
        return 'この商品は既に購入済みです。「購入の復元」をお試しください。';
      case 'user_cancelled':
        return '購入がキャンセルされました。';
      case 'payment_invalid':
        return '支払い情報が無効です。App Storeの設定を確認してください。';
      case 'payment_not_allowed':
        return '購入が許可されていません。デバイスの設定を確認してください。';
      case 'store_kit_error':
        return 'App Storeでエラーが発生しました。しばらく後に再試行してください。';
      case 'purchase_error':
        return '購入処理でエラーが発生しました。App Storeの設定を確認してください。';
      default:
        if (error.message != null && error.message!.isNotEmpty) {
          return '購入エラー: ${error.message}';
        }
        return '購入に失敗しました。しばらく後に再試行してください。';
    }
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