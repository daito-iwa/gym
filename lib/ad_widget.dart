import 'package:flutter/material.dart';
import 'platform_config.dart';

// Mobile only
import 'mobile_ad_widget.dart';
import 'propellerads_widget.dart';

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
    if (!PlatformConfig.isMobile) {
      // 非モバイル版では広告を表示しない
      return SizedBox.shrink();
    }
    
    // モバイル版：AdMobを表示
    return _buildMobileAd();
  }
  
  Widget _buildMobileAd() {
    // モバイル版の広告実装（AdMob）
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