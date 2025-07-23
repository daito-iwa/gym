// PurchaseManager スタブ版 - ビルドエラー回避用の最小実装

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

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
  static const String _premiumProductId = 'premium_monthly_subscription';
  static const String _premiumProductId_ios = 'com.daito.gym.premium_monthly_subscription';
  static const String _premiumProductId_android = 'premium_monthly_subscription';
  
  // 基本状態
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _isMonitoringActive = false;
  SubscriptionState _currentSubscriptionState = SubscriptionState.unknown;
  DateTime? _subscriptionExpiryDate;
  bool _isGracePeriod = false;
  bool _isInBillingRetry = false;
  DateTime? _lastSubscriptionCheck;
  
  // コールバック関数
  Function()? onPurchaseSuccess;
  Future<void> Function()? onPurchaseVerified;
  Function(SubscriptionState oldState, SubscriptionState newState)? onSubscriptionStateChanged;
  Function()? onSubscriptionRenewed;
  Function()? onSubscriptionExpired;
  Function()? onSubscriptionInGracePeriod;
  
  // 初期化
  Future<bool> initialize() async {
    try {
      _isAvailable = await InAppPurchase.instance.isAvailable();
      print('PurchaseManager: Initialization complete (stub version)');
      return true;
    } catch (e) {
      print('PurchaseManager: Initialization error: $e');
      return false;
    }
  }
  
  // 基本的なゲッター
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  bool get isMonitoringActive => _isMonitoringActive;
  SubscriptionState get currentSubscriptionState => _currentSubscriptionState;
  DateTime? get subscriptionExpiryDate => _subscriptionExpiryDate;
  bool get isGracePeriod => _isGracePeriod;
  bool get isInBillingRetry => _isInBillingRetry;
  DateTime? get lastSubscriptionCheck => _lastSubscriptionCheck;
  
  // 購入処理（スタブ）
  Future<bool> purchasePremium() async {
    print('PurchaseManager: Purchase request (stub - not implemented)');
    return false;
  }
  
  // 復元処理（スタブ）
  Future<void> restorePurchases() async {
    print('PurchaseManager: Restore purchases (stub - not implemented)');
  }
  
  // サブスクリプション状態チェック
  Future<void> checkSubscriptionStatus() async {
    print('PurchaseManager: Checking subscription status (stub)');
    _lastSubscriptionCheck = DateTime.now();
  }
  
  // 状態更新メソッド
  void _updateSubscriptionState(SubscriptionState oldState, SubscriptionState newState) {
    if (_currentSubscriptionState != newState) {
      final previousState = _currentSubscriptionState;
      _currentSubscriptionState = newState;
      onSubscriptionStateChanged?.call(previousState, newState);
    }
  }
  
  // クリーンアップ
  void dispose() {
    print('PurchaseManager: Disposing (stub version)');
  }
  
  // プレミアム商品チェック
  bool _isPremiumProduct(String productId) {
    return productId == _premiumProductId ||
           productId == _premiumProductId_ios ||
           productId == _premiumProductId_android;
  }
}