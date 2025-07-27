import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// PropellerAds広告を表示するためのウィジェット
class PropellerAdsWidget extends StatefulWidget {
  final String zoneId;
  final PropellerAdType adType;
  final double? width;
  final double? height;
  
  const PropellerAdsWidget({
    Key? key,
    required this.zoneId,
    required this.adType,
    this.width,
    this.height,
  }) : super(key: key);
  
  @override
  State<PropellerAdsWidget> createState() => _PropellerAdsWidgetState();
}

class _PropellerAdsWidgetState extends State<PropellerAdsWidget> {
  late String _viewId;
  
  @override
  void initState() {
    super.initState();
    _viewId = 'propeller-${widget.zoneId}-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
  }
  
  void _registerViewFactory() {
    // Web専用機能のため、モバイルでは何もしない
  }
  
  @override
  Widget build(BuildContext context) {
    // Web・モバイル共通のプレースホルダー表示
    return Container(
      width: widget.width ?? 300,
      height: widget.height ?? 250,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ads_click, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'PropellerAds\n${widget.adType.name}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum PropellerAdType {
  banner,      // バナー広告
  popunder,    // ポップアンダー
  push,        // プッシュ通知
  inPage,      // インページ
  interstitial // インタースティシャル
}

/// PropellerAds設定
class PropellerAdsConfig {
  // プレースホルダーID（実際のゾーンIDに置き換えてください）
  static const String bannerZoneId = '7891234';
  static const String popunderZoneId = '7891235';
  static const String pushZoneId = '7891236';
  static const String inPageZoneId = '7891237';
  static const String interstitialZoneId = '7891238';
}