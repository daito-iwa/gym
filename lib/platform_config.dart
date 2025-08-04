import 'dart:io' show Platform;

/// モバイルアプリ版のみの設定を管理するクラス
class PlatformConfig {
  /// 現在のプラットフォームがiOSかどうか
  static bool get isIOS => Platform.isIOS;
  
  /// 現在のプラットフォームがAndroidかどうか
  static bool get isAndroid => Platform.isAndroid;
  
  /// 現在のプラットフォームがモバイル（iOS/Android）かどうか
  static bool get isMobile => isIOS || isAndroid;
  
  /// サブスクリプション機能が利用可能かどうか（現在停止中）
  static bool get isSubscriptionEnabled => false;
  
  /// アプリ内購入が利用可能かどうか（現在停止中）
  static bool get isInAppPurchaseEnabled => false;
  
  /// AdMob広告が利用可能かどうか（現在停止中）
  static bool get isAdMobEnabled => false;
  
  /// プラットフォーム名を取得
  static String get platformName {
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    return 'Unknown';
  }
  
  /// 最大1日のチャット回数
  static int get maxDailyChatCount {
    return 10; // モバイル版のみ
  }
  
  /// 最大1ヶ月のチャット回数
  static int get maxMonthlyChatCount {
    return 50; // モバイル版のみ
  }
  
  /// 1日のD-Score計算制限（現在制限なし）
  static int get maxDailyDScoreCalculations {
    return 999; // 実質制限なし
  }
}