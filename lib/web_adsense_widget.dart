import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'web_config.dart';

/// Google AdSense広告を表示するためのウィジェット
class AdSenseWidget extends StatefulWidget {
  final String adUnitId;
  final double width;
  final double height;
  final AdFormat format;
  
  const AdSenseWidget({
    Key? key,
    required this.adUnitId,
    required this.width,
    required this.height,
    this.format = AdFormat.display,
  }) : super(key: key);
  
  /// バナー広告用のファクトリコンストラクタ
  factory AdSenseWidget.banner({
    required String adUnitId,
    BannerSize size = BannerSize.leaderboard,
  }) {
    return AdSenseWidget(
      adUnitId: adUnitId,
      width: size.width,
      height: size.height,
      format: AdFormat.display,
    );
  }
  
  /// レスポンシブ広告用のファクトリコンストラクタ
  factory AdSenseWidget.responsive({
    required String adUnitId,
  }) {
    return AdSenseWidget(
      adUnitId: adUnitId,
      width: double.infinity,
      height: 250, // 最小高さ
      format: AdFormat.responsive,
    );
  }
  
  @override
  State<AdSenseWidget> createState() => _AdSenseWidgetState();
}

class _AdSenseWidgetState extends State<AdSenseWidget> {
  late String _viewId;
  
  @override
  void initState() {
    super.initState();
    _viewId = 'adsense-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
  }
  
  void _registerViewFactory() {
    if (kIsWeb) {
      // Web版では実際のAdSense実装が必要
      // 現在はプレースホルダーとして実装
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Web版では実際のAdSense広告、非Web版ではプレースホルダー
    if (kIsWeb) {
      return AdSensePlaceholder(
        width: widget.width == double.infinity ? 300 : widget.width,
        height: widget.height,
      );
    } else {
      return AdSensePlaceholder(
        width: widget.width == double.infinity ? 300 : widget.width,
        height: widget.height,
      );
    }
  }
}

/// 広告フォーマットの種類
enum AdFormat {
  display,     // 通常のディスプレイ広告
  responsive,  // レスポンシブ広告
  inFeed,      // インフィード広告
  inArticle,   // 記事内広告
}

/// バナーサイズの定義
class BannerSize {
  final double width;
  final double height;
  
  const BannerSize(this.width, this.height);
  
  // 一般的なバナーサイズ
  static const BannerSize banner = BannerSize(468, 60);
  static const BannerSize leaderboard = BannerSize(728, 90);
  static const BannerSize mediumRectangle = BannerSize(300, 250);
  static const BannerSize largeRectangle = BannerSize(336, 280);
  static const BannerSize skyscraper = BannerSize(120, 600);
  static const BannerSize wideSkyscraper = BannerSize(160, 600);
}

/// AdSense広告のプレースホルダー（広告が読み込まれるまで表示）
class AdSensePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  
  const AdSensePlaceholder({
    Key? key,
    required this.width,
    required this.height,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ads_click, size: 32, color: Colors.grey[400]),
            SizedBox(height: 8),
            Text(
              '広告',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}