import 'package:flutter/material.dart';
import 'platform_config.dart';

// Conditional imports for web vs mobile
import 'web_adsense_widget.dart' if (dart.library.io) 'mobile_ad_widget.dart';

/// プラットフォーム別の広告ウィジェット
/// Web版ではAdSense、モバイル版ではAdMobを表示
class UniversalAdWidget extends StatelessWidget {
  final AdType adType;
  final String? adUnitId;
  
  const UniversalAdWidget({
    Key? key,
    required this.adType,
    this.adUnitId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!PlatformConfig.isWeb && !PlatformConfig.isMobile) {
      // デスクトップ版では広告を表示しない
      return SizedBox.shrink();
    }
    
    if (PlatformConfig.isWeb) {
      // Web版：AdSenseを表示
      return _buildWebAd();
    } else {
      // モバイル版：AdMobを表示（既存の実装を使用）
      return _buildMobileAd();
    }
  }
  
  Widget _buildWebAd() {
    switch (adType) {
      case AdType.banner:
        return AdSenseWidget.banner(
          adUnitId: adUnitId ?? 'default-banner-id',
        );
      case AdType.interstitial:
        // Web版では代わりにレスポンシブ広告を表示
        return AdSenseWidget.responsive(
          adUnitId: adUnitId ?? 'default-responsive-id',
        );
      case AdType.rewarded:
        // Web版では報酬広告の代わりに大きめのディスプレイ広告を表示
        return AdSenseWidget(
          adUnitId: adUnitId ?? 'default-display-id',
          width: 336,
          height: 280,
        );
    }
  }
  
  Widget _buildMobileAd() {
    // モバイル版の広告実装（既存のAdMob実装を呼び出す）
    // この部分は既存のAdMob実装に合わせて調整が必要
    return Container(
      child: Center(
        child: Text('Mobile Ad Placeholder'),
      ),
    );
  }
}

/// 広告タイプの定義
enum AdType {
  banner,
  interstitial,
  rewarded,
}