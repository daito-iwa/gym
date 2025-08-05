import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Flutter Web専用の広告管理クラス
class WebAdsManager {
  static bool _initialized = false;
  static bool _adSenseLoaded = false;
  static bool _adBlockDetected = false;
  
  // 実際のAdSense Publisher ID（承認後に使用）
  static const String publisherId = 'ca-pub-8022160047771829';
  
  /// 広告システムの初期化
  static Future<void> initialize() async {
    if (!kIsWeb || _initialized) return;
    
    try {
      // Google AdSense スクリプトの動的読み込み
      await _loadAdSenseScript();
      
      // AdBlockの検出
      _detectAdBlock();
      
      _initialized = true;
      print('WebAdsManager initialized successfully');
    } catch (e) {
      print('Failed to initialize WebAdsManager: $e');
    }
  }
  
  /// Google AdSense スクリプトの読み込み
  static Future<void> _loadAdSenseScript() async {
    if (_adSenseLoaded) return;
    
    // AdSense用のscriptタグを作成
    final script = html.ScriptElement()
      ..src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$publisherId'
      ..async = true
      ..crossOrigin = 'anonymous';
    
    html.document.head?.append(script);
    
    // スクリプトの読み込み完了を待機
    await script.onLoad.first;
    _adSenseLoaded = true;
  }
  
  /// AdBlockの検出
  static void _detectAdBlock() {
    try {
      // テスト用の広告要素を作成してAdBlockを検出
      final testAd = html.DivElement()
        ..className = 'adsbox'
        ..style.display = 'none';
      
      html.document.body?.append(testAd);
      
      // AdBlockがある場合、要素が削除される
      html.window.setTimeout(() {
        if (testAd.offsetHeight == 0) {
          _adBlockDetected = true;
          print('AdBlock detected');
        }
        testAd.remove();
      }, 100);
    } catch (e) {
      print('AdBlock detection failed: $e');
    }
  }
  
  /// 広告要素を作成してページに挿入
  static void createAdUnit({
    required String containerId,
    required String adSlot,
    required String adFormat,
    required String adSize,
    bool isResponsive = true,
  }) {
    if (!kIsWeb || !_initialized) return;
    
    try {
      // HTMLに直接広告コンテナを挿入
      final container = html.DivElement()
        ..id = containerId
        ..style.width = '100%'
        ..style.height = 'auto'
        ..style.textAlign = 'center'
        ..style.margin = '10px 0';
      
      // 広告要素を作成
      final adElement = html.Element.tag('ins')
        ..className = 'adsbygoogle'
        ..style.display = 'block'
        ..attributes['data-ad-client'] = publisherId
        ..attributes['data-ad-slot'] = adSlot
        ..attributes['data-ad-format'] = adFormat;
      
      if (isResponsive) {
        adElement.attributes['data-full-width-responsive'] = 'true';
      } else {
        final sizeParts = adSize.split('x');
        if (sizeParts.length == 2) {
          adElement.style.width = '${sizeParts[0]}px';
          adElement.style.height = '${sizeParts[1]}px';
        }
      }
      
      container.append(adElement);
      html.document.body?.append(container);
      
      // AdSense広告を初期化
      js.context.callMethod('eval', ['(adsbygoogle = window.adsbygoogle || []).push({});']);
      
    } catch (e) {
      print('Failed to create ad unit: $e');
    }
  }
  
  /// レスポンシブ広告の作成
  static void createResponsiveAd({
    required String containerId,
    required String adSlot,
  }) {
    createAdUnit(
      containerId: containerId,
      adSlot: adSlot,
      adFormat: 'auto',
      adSize: 'responsive',
      isResponsive: true,
    );
  }
  
  /// バナー広告の作成
  static void createBannerAd({
    required String containerId,
    required String adSlot,
    required String size, // '728x90', '300x250', etc.
  }) {
    createAdUnit(
      containerId: containerId,
      adSlot: adSlot,
      adFormat: 'rectangle',
      adSize: size,
      isResponsive: false,
    );
  }
  
  /// AdBlock状態の確認
  static bool get isAdBlockDetected => _adBlockDetected;
  
  /// 初期化状態の確認
  static bool get isInitialized => _initialized;
  
  /// 広告収益の追跡
  static void trackRevenue({
    required String adNetwork,
    required String adUnit,
    required String action, // 'impression', 'click'
  }) {
    if (!kIsWeb) return;
    
    try {
      // Google Analytics イベント送信（もしGAが設定されている場合）
      js.context.callMethod('gtag', ['event', action, js.JsObject.jsify({
        'event_category': 'ads',
        'event_label': '$adNetwork-$adUnit',
        'custom_parameter_1': adNetwork,
        'custom_parameter_2': adUnit,
      })]);
    } catch (e) {
      print('Failed to track revenue: $e');
    }
  }
}

/// 広告の種類
enum WebAdType {
  banner,
  leaderboard,
  rectangle,
  skyscraper,
  mobile,
  responsive,
}

/// 広告の配置位置
enum AdPlacement {
  header,
  sidebar,
  content,
  footer,
  inline,
}