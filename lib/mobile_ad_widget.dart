import 'package:flutter/material.dart';

/// モバイル版用の広告ウィジェットのスタブ
/// 実際のAdMob実装は既存のコードを使用
class AdSenseWidget extends StatelessWidget {
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
  
  factory AdSenseWidget.responsive({
    required String adUnitId,
  }) {
    return AdSenseWidget(
      adUnitId: adUnitId,
      width: double.infinity,
      height: 250,
      format: AdFormat.responsive,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // モバイル版では既存のAdMob実装を使用
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Text('Mobile Ad'),
      ),
    );
  }
}

enum AdFormat {
  display,
  responsive,
  inFeed,
  inArticle,
}

class BannerSize {
  final double width;
  final double height;
  
  const BannerSize(this.width, this.height);
  
  static const BannerSize banner = BannerSize(468, 60);
  static const BannerSize leaderboard = BannerSize(728, 90);
  static const BannerSize mediumRectangle = BannerSize(300, 250);
  static const BannerSize largeRectangle = BannerSize(336, 280);
  static const BannerSize skyscraper = BannerSize(120, 600);
  static const BannerSize wideSkyscraper = BannerSize(160, 600);
}

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
      color: Colors.grey[200],
    );
  }
}