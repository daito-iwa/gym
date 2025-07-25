import 'package:flutter/material.dart';
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
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final container = html.DivElement()
          ..id = 'ad-container-$viewId'
          ..style.width = '${widget.width}px'
          ..style.height = '${widget.height}px'
          ..style.margin = 'auto';
        
        // AdSense広告用のins要素を作成
        final adElement = html.Element.tag('ins')
          ..className = 'adsbygoogle'
          ..style.display = 'block'
          ..setAttribute('data-ad-client', WebConfig.adSensePublisherId)
          ..setAttribute('data-ad-slot', widget.adUnitId);
        
        // フォーマットに応じて属性を設定
        switch (widget.format) {
          case AdFormat.display:
            adElement.style.width = '${widget.width}px';
            adElement.style.height = '${widget.height}px';
            break;
          case AdFormat.responsive:
            adElement.setAttribute('data-ad-format', 'auto');
            adElement.setAttribute('data-full-width-responsive', 'true');
            break;
          case AdFormat.inFeed:
            adElement.setAttribute('data-ad-format', 'fluid');
            adElement.setAttribute('data-ad-layout-key', '-gw-3+1f-3d+2z');
            break;
          case AdFormat.inArticle:
            adElement.setAttribute('data-ad-layout', 'in-article');
            adElement.setAttribute('data-ad-format', 'fluid');
            break;
        }
        
        container.append(adElement);
        
        // AdSenseスクリプトを実行して広告を表示
        html.window.console.log('Pushing AdSense ad for slot: ${widget.adUnitId}');
        try {
          // JavaScriptコードを実行
          final script = html.ScriptElement()
            ..text = '(adsbygoogle = window.adsbygoogle || []).push({});';
          container.append(script);
        } catch (e) {
          html.window.console.error('Error pushing AdSense ad: $e');
        }
        
        return container;
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width == double.infinity ? null : widget.width,
      height: widget.height,
      child: HtmlElementView(viewType: _viewId),
    );
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