import 'dart:io';
import 'package:flutter/foundation.dart';

/// AdMob設定クラス
/// 本番用広告IDと開発用テストIDを管理
class AdMobConfig {
  // テスト用広告ID（開発時に使用）
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  // 本番用広告ID（実際のAdMob IDに更新）
  static const String productionBannerAdUnitIdAndroid = 'ca-app-pub-8022160047771829/1779286767'; // 本番ID
  static const String productionBannerAdUnitIdIOS = 'ca-app-pub-8022160047771829/2462098451'; // 本番ID  
  static const String productionInterstitialAdUnitIdAndroid = 'ca-app-pub-8022160047771829/9466205091'; // 本番ID
  static const String productionInterstitialAdUnitIdIOS = 'ca-app-pub-8022160047771829/3447376059'; // 本番ID
  static const String productionRewardedAdUnitIdAndroid = 'ca-app-pub-8022160047771829/3862524626'; // 本番ID
  static const String productionRewardedAdUnitIdIOS = 'ca-app-pub-8022160047771829/8320428782'; // 本番ID
  
  // 環境に応じた広告IDを取得
  static String get bannerAdUnitId {
    if (_isDebugMode) {
      return testBannerAdUnitId;
    }
    return Platform.isIOS 
      ? productionBannerAdUnitIdIOS 
      : productionBannerAdUnitIdAndroid;
  }
  
  static String get interstitialAdUnitId {
    if (_isDebugMode) {
      return testInterstitialAdUnitId;
    }
    return Platform.isIOS 
      ? productionInterstitialAdUnitIdIOS 
      : productionInterstitialAdUnitIdAndroid;
  }
  
  static String get rewardedAdUnitId {
    if (_isDebugMode) {
      return testRewardedAdUnitId;
    }
    return Platform.isIOS 
      ? productionRewardedAdUnitIdIOS 
      : productionRewardedAdUnitIdAndroid;
  }
  
  // デバッグモード判定（本番リリース用）
  static bool get _isDebugMode {
    // kDebugModeを使用してFlutterのデバッグモードを判定
    return kDebugMode;
  }
}