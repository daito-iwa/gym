import 'package:flutter/material.dart';
import 'dart:async';

/// モバイル版用の広告ウィジェット
/// 実際のAdMob実装を使用し、main.dartのAdManagerと連携
class AdSenseWidget extends StatefulWidget {
  final String adUnitId;
  final double width;
  final double height;
  final AdFormat format;
  final Widget? adWidget; // AdManagerからの実際の広告ウィジェット
  
  const AdSenseWidget({
    Key? key,
    required this.adUnitId,
    required this.width,
    required this.height,
    this.format = AdFormat.display,
    this.adWidget,
  }) : super(key: key);
  
  @override
  _AdSenseWidgetState createState() => _AdSenseWidgetState();
  
  factory AdSenseWidget.banner({
    required String adUnitId,
    BannerSize size = BannerSize.leaderboard,
    Widget? adWidget,
  }) {
    return AdSenseWidget(
      adUnitId: adUnitId,
      width: size.width,
      height: size.height,
      format: AdFormat.display,
      adWidget: adWidget,
    );
  }
  
  factory AdSenseWidget.responsive({
    required String adUnitId,
    Widget? adWidget,
  }) {
    return AdSenseWidget(
      adUnitId: adUnitId,
      width: double.infinity,
      height: 250,
      format: AdFormat.responsive,
      adWidget: adWidget,
    );
  }
}

class _AdSenseWidgetState extends State<AdSenseWidget> {
  bool _isTimedOut = false;
  Timer? _timeoutTimer;
  
  @override
  void initState() {
    super.initState();
    // 10秒後にタイムアウト
    _timeoutTimer = Timer(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isTimedOut = true;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    final height = widget.height;
    final adWidget = widget.adWidget;
    
    // タイムアウトした場合は空のコンテナを返す
    if (_isTimedOut) {
      return SizedBox.shrink();
    }
    
    // AdManagerから提供された実際の広告ウィジェットを表示
    if (adWidget != null) {
      return Container(
        width: width == double.infinity ? MediaQuery.of(context).size.width : width,
        height: height,
        child: adWidget,
      );
    }
    
    // 広告読み込み中またはエラー時のプレースホルダー
    return Container(
      width: width == double.infinity ? MediaQuery.of(context).size.width : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[500]!),
              ),
            ),
            SizedBox(height: 8),
            Text(
              '広告読み込み中...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AdFormat {
  display,
  responsive,
  inFeed,
  multiplex,
  inArticle,
  matchedContent,
}

class BannerSize {
  final double width;
  final double height;
  
  const BannerSize({required this.width, required this.height});
  
  static const BannerSize banner = BannerSize(width: 320, height: 50);
  static const BannerSize largeBanner = BannerSize(width: 320, height: 100);
  static const BannerSize mediumRectangle = BannerSize(width: 300, height: 250);
  static const BannerSize fullBanner = BannerSize(width: 468, height: 60);
  static const BannerSize leaderboard = BannerSize(width: 728, height: 90);
}

/// MobileAdWidget - for backward compatibility
class MobileAdWidget extends AdSenseWidget {
  final dynamic adManager; // AdManagerインスタンス
  final BannerSize size;
  
  const MobileAdWidget({
    Key? key,
    required this.adManager,
    required String adUnitId,
    required this.size,
    Widget? adWidget,
  }) : super(
          key: key,
          adUnitId: adUnitId,
          width: size.width,
          height: size.height,
          adWidget: adWidget,
        );
}