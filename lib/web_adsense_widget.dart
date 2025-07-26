import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
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
      // ビューファクトリーを登録（一度だけ）
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _createAdSenseElement(),
      );
    }
  }
  
  html.IFrameElement _createAdSenseElement() {
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    // AdSense広告コードを生成
    final adCode = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; }
    .adsbygoogle { display: block; }
  </style>
  <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${WebConfig.adSensePublisherId}"
          crossorigin="anonymous"></script>
</head>
<body>
  <ins class="adsbygoogle"
       style="display:${widget.format == AdFormat.responsive ? 'block' : 'inline-block'};width:${widget.width == double.infinity ? '100%' : '${widget.width}px'};height:${widget.height}px"
       data-ad-client="${WebConfig.adSensePublisherId}"
       data-ad-slot="${widget.adUnitId}"
       ${widget.format == AdFormat.responsive ? 'data-ad-format="auto" data-full-width-responsive="true"' : ''}>
  </ins>
  <script>
    (adsbygoogle = window.adsbygoogle || []).push({});
  </script>
</body>
</html>
    ''';

    // iframeのsrcDocに直接HTMLを設定
    iframe.srcdoc = adCode;
    
    return iframe;
  }
  
  @override
  Widget build(BuildContext context) {
    // Web版では実際のAdSense広告
    if (kIsWeb) {
      return SizedBox(
        width: widget.width == double.infinity ? null : widget.width,
        height: widget.height,
        child: HtmlElementView(viewType: _viewId),
      );
    } else {
      // 非Web版ではプレースホルダー
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