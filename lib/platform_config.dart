import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// プラットフォーム別の設定を管理するクラス
class PlatformConfig {
  /// 現在のプラットフォームがWebかどうか
  static bool get isWeb => kIsWeb;
  
  /// 現在のプラットフォームがiOSかどうか
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  /// 現在のプラットフォームがAndroidかどうか
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  /// 現在のプラットフォームがモバイル（iOS/Android）かどうか
  static bool get isMobile => isIOS || isAndroid;
  
  /// サブスクリプション機能が利用可能かどうか
  static bool get isSubscriptionEnabled => isMobile;
  
  /// アプリ内購入が利用可能かどうか
  static bool get isInAppPurchaseEnabled => isMobile;
  
  /// AdMob広告が利用可能かどうか（モバイルのみ）
  static bool get isAdMobEnabled => isMobile;
  
  /// Google AdSense広告が利用可能かどうか（Webのみ）
  static bool get isAdSenseEnabled => isWeb;
  
  /// Web版のベースURL（GitHub Pages用）
  static String get webBaseUrl => 'https://daito-iwa.github.io/gym/';
  
  /// プラットフォーム名を取得
  static String get platformName {
    if (isWeb) return 'Web';
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    return 'Unknown';
  }
  
  /// Web版での機能制限メッセージ
  static String get webLimitationMessage {
    return '''
Web版では以下の機能に制限があります：
• プレミアムサブスクリプションは利用できません
• すべての機能は広告付きで無料でご利用いただけます
• モバイルアプリ版では広告なしのプレミアム版が利用可能です
''';
  }
  
  /// プラットフォーム別の最大チャット回数
  static int get maxDailyChatCount {
    return 10; // モバイル版に統一
  }
  
  /// プラットフォーム別の最大月間チャット回数
  static int get maxMonthlyChatCount {
    return 50; // モバイル版に統一
  }
  
  /// プラットフォーム別のD-Score計算制限
  static int get maxDailyDScoreCalculations {
    return 3; // モバイル版に統一
  }
}