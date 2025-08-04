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
  // サブスクリプション商品ID（複数対応）
  static const List<String> _premiumProductIds_ios = [
    'com.daito.gymnasticsai.premium_monthly_subscription', // 元の商品
    'com.daito.gymnasticsai.premium_sub', // 新しい商品
    'com.daito.gymnasticsai.premium_monthly', // さらに新しい商品（必要に応じて）
  ];
  static const String _premiumProductId_android = 'premium_subscription';
  
  // テスト用モックモード（App Store審査用）
  // 実際のStoreKit購入フローを使用（商品審査中でも試行）
  static const bool _isTestMode = false; // 実際のStoreKit購入を使用
  
  // 利用可能な商品IDを取得（最初に見つかった商品を使用）
  static Set<String> get premiumProductIds => Platform.isIOS 
      ? _premiumProductIds_ios.toSet()
      : {_premiumProductId_android};
  
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
  Function(String message)? onPurchaseRestore; // 復元時の専用コールバック
  Function(SubscriptionState oldState, SubscriptionState newState)? onSubscriptionStateChanged;
  Function()? onSubscriptionRenewed;
  Function()? onSubscriptionExpired;
  
  // シングルトンパターン
  static final PurchaseManager _instance = PurchaseManager._internal();
  factory PurchaseManager() => _instance;
  PurchaseManager._internal();
  
  // 初期化
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ PurchaseManager already initialized');
      return true;
    }
    
    print('🚀 PurchaseManager initialization starting...');
    print('   📱 Platform: ${Platform.operatingSystem}');
    print('   🔧 Debug mode: ${kDebugMode}');
    print('   🧪 Test mode: $_isTestMode');
    
    try {
      // テストモードの場合はモック初期化
      if (_isTestMode) {
        print('🔥🔥🔥 TEST MODE で初期化中 🔥🔥🔥');
        await _initializeTestMode();
        return true;
      }
      
      // サービス利用可能確認
      print('🔍 Checking StoreKit availability...');
      _isAvailable = await _inAppPurchase.isAvailable();
      print('   📱 StoreKit available: $_isAvailable');
      
      if (!_isAvailable) {
        print('❌ In-app purchases not available');
        print('   🔍 Possible reasons:');
        print('   - Device is in Airplane mode');
        print('   - Parental controls are enabled');
        print('   - StoreKit is not configured properly');
        
        // デバッグモードの場合のみテストモードにフォールバック
        if (_isTestMode) {
          print('Falling back to test mode (debug only)');
          await _initializeTestMode();
          return true;
        } else {
          // プロダクション/TestFlightではエラーとして処理
          print('❌ In-app purchases not available in production build');
          return false;
        }
      }
      
      // 商品詳細取得
      print('🔍 Loading products...');
      await _loadProducts();
      print('📦 Products loaded: ${_products.length}');
      
      // 商品が見つからない場合の処理
      if (_products.isEmpty) {
        if (_isTestMode) {
          print('PurchaseManager: No products found - falling back to test mode');
          await _initializeTestMode();
          return true;
        } else {
          print('❌ No products found in production build');
          print('🔥🔥🔥 CRITICAL: App Store Connect商品設定を確認してください 🔥🔥🔥');
          print('   1. 商品ID: $premiumProductIds が存在するか');
          print('   2. 商品ステータスが「準備完了」か');
          print('   3. 有料アプリケーション契約がアクティブか');
          print('   4. TestFlightビルドが配布済みか');
          
          // 商品審査中の場合でも初期化は成功とする
          print('🔥 商品審査中のため一時的に利用不可');
          _isInitialized = true;
          _isAvailable = false; // 購入は無効だが初期化は成功
          return true;
        }
      }
      
      // 購入ストリーム監視開始
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('Purchase stream error: $error'),
      );
      
      // 既存の購入を復元
      await _restoreExistingPurchases();
      
      _isInitialized = true;
      if (_isTestFlightBuild()) {
        print('✅ TestFlight購入システム初期化完了');
        print('   📱 StoreKit利用可能: $_isAvailable');
        print('   📦 商品読み込み完了: ${_products.length}件');
        print('   🧪 Sandbox環境準備完了');
        print('   💡 購入テスト準備完了 - Sandboxアカウントで購入可能');
      } else {
        print('PurchaseManager: Initialization successful');
      }
      return true;
      
    } catch (e, stackTrace) {
      print('❌ PurchaseManager initialization error: $e');
      print('📋 Stack trace: $stackTrace');
      print('🔍 Error type: ${e.runtimeType}');
      
      if (_isTestMode) {
        print('Falling back to test mode (debug only)');
        await _initializeTestMode();
        return true;
      } else {
        print('❌ Initialization failed in production build');
        print('💡 Suggestions:');
        print('   - Check internet connection');
        print('   - Verify App Store Connect configuration');
        print('   - Ensure Paid Applications contract is active');
        return false;
      }
    }
  }
  
  // テストモード初期化
  Future<void> _initializeTestMode() async {
    _isAvailable = true;
    _isInitialized = true;
    
    // テスト用の商品情報を作成
    _products = [
      // モック商品情報（実際のProductDetailsではなく、表示用の情報のみ）
    ];
    
    _currentSubscriptionState = SubscriptionState.unknown;
    print('PurchaseManager: Test mode initialized successfully');
    print('PurchaseManager: _isAvailable = $_isAvailable, _isInitialized = $_isInitialized');
  }
  
  // 商品詳細読み込み
  Future<void> _loadProducts() async {
    try {
      final Set<String> productIds = premiumProductIds;
      print('🔍 Loading products with IDs: $productIds');
      print('🔍 Platform: ${Platform.operatingSystem}');
      print('🔍 Bundle ID should match: com.daito.gymnasticsai');
      print('🔍 TestFlight build: ${_isTestFlightBuild()}');
      print('🔍 Debug mode: ${kDebugMode}');
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
      
      if (response.error != null) {
        print('❌ Product query error: ${response.error}');
        print('❌ Error code: ${response.error?.code}');
        print('❌ Error message: ${response.error?.message}');
        print('❌ Error details: ${response.error?.details}');
        
        // iOS固有のエラーメッセージを追加
        if (Platform.isIOS) {
          print('📱 iOS specific error info:');
          print('   - Check if app is properly signed');
          print('   - Verify provisioning profile includes IAP capability');
          print('   - Ensure StoreKit configuration is correct');
        }
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        print('❌ Products not found: ${response.notFoundIDs}');
        print('❌ Requested product IDs: $productIds');
        print('❌ Check App Store Connect:');
        print('   1. Product exists with exact IDs: $productIds');
        print('   2. Status is "Ready to Submit" or "Approved"');
        print('   3. Price is set for at least one territory');
        print('   4. At least one localization exists (title + description)');
        print('   5. Paid Applications contract is active');
        print('   6. Bank account information is complete');
        print('   7. For TestFlight: App must be distributed to testers');
        
        // TestFlight特有の問題チェック
        if (_isTestFlightBuild()) {
          print('🔍 TestFlight購入テスト詳細情報:');
          print('   📱 デバイス情報: iOS ${Platform.operatingSystemVersion}');
          print('   📦 商品ID: $premiumProductIds');
          print('   🏢 Bundle ID: com.daito.gymnasticsai');
          print('');
          print('✅ App Store Connect 必須確認項目:');
          print('   1. In-App Purchase商品が「準備完了」状態');
          print('   2. サブスクリプショングループが作成済み');
          print('   3. 価格設定が完了（最低1地域）');
          print('   4. 商品情報（名前・説明）が設定済み');
          print('   5. 有料アプリケーション契約がアクティブ');
          print('   6. 銀行・税務情報が完了');
          print('   7. TestFlightでアプリが配布済み');
          print('');
          print('🧪 Sandbox設定手順:');
          print('   1. App Store Connect > ユーザーとアクセス > Sandboxテスター');
          print('   2. テスターアカウント作成（実在しないメールアドレス使用可）');
          print('   3. デバイス設定 > App Store から現在のApple IDをサインアウト');
          print('   4. TestFlightアプリでのみサインイン状態を維持');
          print('   5. 購入時にSandboxアカウントでサインイン要求が表示される');
          print('');
          print('⚠️ よくある問題:');
          print('   • 商品ステータスが「承認待ち」→「準備完了」まで待つ');
          print('   • 本番Apple IDでサインイン→完全にサインアウトする');
          print('   • ネットワーク問題→WiFi/モバイルデータ切り替え');
        }
      }
      
      _products = response.productDetails;
      print('✅ Loaded ${_products.length} products');
      for (var product in _products) {
        print('📦 Product found:');
        print('   ID: ${product.id}');
        print('   Title: ${product.title}');
        print('   Description: ${product.description}');
        print('   Price: ${product.price}');
        print('   Currency: ${product.currencyCode}');
        print('   Raw Price: ${product.rawPrice}');
      }
      
    } catch (e, stackTrace) {
      print('❌ Error loading products: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  // TestFlightビルドかどうかを検出
  bool _isTestFlightBuild() {
    // より正確なTestFlightビルドの検出
    if (!Platform.isIOS) return false;
    
    // デバッグモードではない＋iOSプラットフォーム＋プロファイルモードでない
    return !kDebugMode && !kProfileMode;
  }
  
  // 購入処理
  Future<bool> purchasePremium() async {
    if (kDebugMode) {
      print('🔴 PurchaseManager: purchasePremium called - _isAvailable=$_isAvailable, _isTestMode=$_isTestMode, _purchasePending=$_purchasePending');
      print('📱 Device Info: iOS version=${Platform.operatingSystemVersion}');
      print('📦 Available products count: ${_products.length}');
      
      if (_isTestMode) {
        print('🟢 TEST MODE ACTIVE - This is a simulated purchase');
      }
    }
    
    if (!_isAvailable) {
      if (kDebugMode) {
        print('🔴 Purchase not available - service not initialized');
        print('📊 Initialization state: _products.length=${_products.length}');
      }
      
      // 審査用：StoreKitが利用できない場合の適切なエラーメッセージ
      String errorMessage = 'この機能は現在利用できません。\n\n' +
                           '以下をお試しください：\n' +
                           '• アプリを再起動\n' +
                           '• デバイスを再起動\n' +
                           '• インターネット接続を確認\n' +
                           '• App Storeにサインイン\n\n' +
                           'それでも解決しない場合は、しばらく時間をおいてからお試しください。';
      
      onPurchaseError?.call(errorMessage);
      return false;
    }
    
    if (_purchasePending) {
      if (kDebugMode) print('Purchase already pending');
      onPurchaseError?.call('購入処理が進行中です。しばらくお待ちください。');
      return false;
    }
    
    // テストモードの場合はモック購入を実行
    if (_isTestMode) {
      if (kDebugMode) print('PurchaseManager: Executing test purchase in test mode');
      return await _executeTestPurchase();
    }
    
    try {
      // 利用可能な商品を検索（複数商品対応）
      final ProductDetails? productDetails = _products
          .where((product) => premiumProductIds.contains(product.id))
          .firstOrNull;
      
      if (productDetails == null) {
        print('❌ Product details not found for: $premiumProductIds');
        print('📋 Available products: ${_products.map((p) => p.id).join(", ")}');
        
        // 商品情報を再取得を試行
        print('🔄 Retrying to load products...');
        await _loadProducts();
        final retryProductDetails = _products
            .where((product) => premiumProductIds.contains(product.id))
            .firstOrNull;
            
        if (retryProductDetails == null) {
          // 商品が見つからない場合
          if (_isTestMode) { // デバッグモードのみテスト購入を許可
            print('🧪 Falling back to test purchase (debug mode only)');
            return await _executeTestPurchase();
          }
          
          // TestFlightビルドの場合の詳細なエラーメッセージ
          String errorMessage;
          if (_isTestFlightBuild()) {
            errorMessage = '⚠️ TestFlightでの課金テスト\n\n' +
                          '【事前準備の確認】\n' +
                          '1. App Store Connectで商品が「準備完了」\n' +
                          '2. Sandboxテスターアカウント作成済み\n' +
                          '3. デバイスからApple IDサインアウト\n' +
                          '4. TestFlightでアプリを起動\n' +
                          '5. 購入時にSandboxアカウントでサインイン\n\n' +
                          '【トラブルシューティング】\n' +
                          '• アプリを完全終了して再起動\n' +
                          '• デバイス再起動\n' +
                          '• ネットワーク接続確認\n\n' +
                          '商品ID: $premiumProductIds';
          } else {
            errorMessage = 'サブスクリプション商品が見つかりません。\n' +
                          'アプリを再起動してお試しください。\n\n' +
                          'それでも解決しない場合は、しばらく時間をおいてからお試しください。';
          }
          
          print('🔴 Final error - no product found');
          print('📊 Debug info:');
          print('  - Product ID: $premiumProductIds');
          print('  - Available products: ${_products.map((p) => "${p.id} (${p.title})").join(", ")}');
          print('  - Is TestFlight: ${_isTestFlightBuild()}');
          print('  - Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
          
          onPurchaseError?.call(errorMessage);
          return false;
        }
        // 再取得した商品情報を使用
        print('✅ Product found after retry');
        return await _executePurchase(retryProductDetails);
      }
      
      return await _executePurchase(productDetails);
      
    } catch (e, stackTrace) {
      _purchasePending = false;
      if (kDebugMode) {
        print('❌ Purchase error: $e');
        print('📋 Stack trace: $stackTrace');
      }
      
      // エラー時の処理
      if (_isTestMode) {
        print('Falling back to test purchase due to error: $e');
        return await _executeTestPurchase();
      }
      
      // プロダクションではエラーメッセージを表示して失敗を返す
      onPurchaseError?.call('購入処理中にエラーが発生しました。しばらく後に再試行してください。');
      return false;
    }
  }
  
  // テスト状態確認
  static bool get isTestModeEnabled => _isTestMode;
  
  // テスト用購入処理
  Future<bool> _executeTestPurchase() async {
    _purchasePending = true;
    
    try {
      print('Executing test purchase...');
      
      // 購入処理をシミュレート（2秒待機）
      await Future.delayed(Duration(seconds: 2));
      
      // テスト時は常に成功させる（100%成功率）
      final success = true; // DateTime.now().millisecond % 100 < 99;
      
      if (success) {
        _updateSubscriptionState(SubscriptionState.active);
        _subscriptionExpiryDate = DateTime.now().add(Duration(days: 30)); // テスト用：30日間
        _purchasePending = false;
        
        print('Test purchase successful');
        onPurchaseSuccess?.call();
        return true;
      } else {
        _purchasePending = false;
        print('Test purchase failed (simulated)');
        onPurchaseError?.call('テスト購入が失敗しました（シミュレート）\n\nデバッグモードでは1%の確率で失敗をシミュレートしています。\n再度お試しください。');
        return false;
      }
      
    } catch (e) {
      _purchasePending = false;
      print('Test purchase error: $e');
      onPurchaseError?.call('テスト購入でエラーが発生しました: $e');
      return false;
    }
  }
  
  Future<bool> _executePurchase(ProductDetails productDetails) async {
    _purchasePending = true;
    
    try {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // タイムアウト処理を追加
      bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam)
          .timeout(Duration(seconds: 60), onTimeout: () {
        _purchasePending = false;
        throw TimeoutException('Purchase timeout', Duration(seconds: 60));
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
    
    // テストモードの場合はモック復元を実行
    if (_isTestMode) {
      await _executeTestRestore();
      return;
    }
    
    try {
      await _inAppPurchase.restorePurchases();
      print('Purchase restoration completed');
    } catch (e) {
      print('Error restoring purchases: $e');
      // デバッグモードの場合のみテスト復元にフォールバック
      if (_isTestMode) {
        await _executeTestRestore();
      } else {
        onPurchaseRestore?.call('復元処理でエラーが発生しました。しばらく後に再試行してください。');
      }
    }
  }
  
  // テスト用復元処理
  Future<void> _executeTestRestore() async {
    try {
      print('Executing test restore...');
      
      // 復元処理をシミュレート（1秒待機）
      await Future.delayed(Duration(seconds: 1));
      
      // 既存の購入履歴があるかをシミュレート（80%の確率）
      final hasPreviousPurchase = DateTime.now().millisecond % 5 < 4;
      
      if (hasPreviousPurchase) {
        _updateSubscriptionState(SubscriptionState.restored);
        _subscriptionExpiryDate = DateTime.now().add(Duration(days: 30));
        
        print('Test restore successful - subscription restored');
        onPurchaseSuccess?.call();
        
        // 復元成功メッセージを表示
        onPurchaseRestore?.call('購入を復元しました！プレミアム機能をお楽しみください。');
      } else {
        print('Test restore - no previous purchases found');
        onPurchaseRestore?.call('復元可能な購入履歴が見つかりませんでした。');
      }
      
    } catch (e) {
      print('Test restore error: $e');
      onPurchaseRestore?.call('復元処理でエラーが発生しました。しばらく後に再試行してください。');
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
          if (_isTestFlightBuild()) {
            print('🎉 TestFlight購入テスト成功！');
            print('   ✅ サブスクリプション有効化完了');
            print('   ✅ Sandbox決済完了');
            print('   💡 本番環境での購入フローが正常に動作することを確認');
          } else {
            print('Premium subscription activated');
          }
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
    return _premiumProductIds_ios.contains(productId) ||
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
    // テストモードの場合はモック価格を返す
    if (_isTestMode) {
      return '¥500'; // 正しい価格
    }
    
    final ProductDetails? product = _products
        .where((p) => premiumProductIds.contains(p.id))
        .firstOrNull;
    return product?.price ?? '¥500'; // 正しいフォールバック価格
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