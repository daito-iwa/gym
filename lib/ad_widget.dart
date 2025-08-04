import 'package:flutter/material.dart';
import 'platform_config.dart';

/// プラットフォーム別の広告ウィジェット
/// Web版ではAdSense、モバイル版ではAdMobを表示
class UniversalAdWidget extends StatelessWidget {
  final AdType adType;
  final String? adUnitId;
  final Widget? adWidget; // AdManagerからの実際の広告ウィジェット
  
  const UniversalAdWidget({
    Key? key,
    required this.adType,
    this.adUnitId,
    this.adWidget,
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
    // AdManagerから提供された実際の広告ウィジェットを表示
    if (adWidget != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: adWidget,
      );
    }
    
    // 広告読み込み中のプレースホルダー
    return Container(
      height: 50.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
              ),
            ),
            SizedBox(width: 8),
            Text(
              '広告読み込み中...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
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