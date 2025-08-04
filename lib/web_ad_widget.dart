import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:math' as math;
import 'web_ads_manager.dart';

/// Flutter Web専用の広告表示ウィジェット
class WebAdWidget extends StatefulWidget {
  final WebAdType adType;
  final AdPlacement placement;
  final String? customAdSlot;
  final bool showOnMobile;
  final EdgeInsets margin;
  final String? customId;
  
  const WebAdWidget({
    Key? key,
    required this.adType,
    required this.placement,
    this.customAdSlot,
    this.showOnMobile = true,
    this.margin = const EdgeInsets.all(8.0),
    this.customId,
  }) : super(key: key);
  
  @override
  State<WebAdWidget> createState() => _WebAdWidgetState();
}

class _WebAdWidgetState extends State<WebAdWidget> {
  late String _adId;
  bool _adLoaded = false;
  bool _showAdBlock = false;
  
  @override
  void initState() {
    super.initState();
    _adId = widget.customId ?? 'ad-${widget.placement.name}-${DateTime.now().millisecondsSinceEpoch}';
    _initializeAd();
  }
  
  void _initializeAd() async {
    if (!kIsWeb) return;
    
    // WebAdsManagerが初期化されていない場合は初期化
    if (!WebAdsManager.isInitialized) {
      await WebAdsManager.initialize();
    }
    
    // AdBlockが検出されている場合
    if (WebAdsManager.isAdBlockDetected) {
      setState(() {
        _showAdBlock = true;
      });
      return;
    }
    
    // 短い遅延の後に広告を作成
    Future.delayed(const Duration(milliseconds: 500), () {
      _createAd();
      setState(() {
        _adLoaded = true;
      });
    });
  }
  
  void _createAd() {
    if (!kIsWeb) return;
    
    final adSlot = widget.customAdSlot ?? _getDefaultAdSlot();
    
    switch (widget.adType) {
      case WebAdType.responsive:
        WebAdsManager.createResponsiveAd(
          containerId: _adId,
          adSlot: adSlot,
        );
        break;
      case WebAdType.banner:
        WebAdsManager.createBannerAd(
          containerId: _adId,
          adSlot: adSlot,
          size: '728x90',
        );
        break;
      case WebAdType.leaderboard:
        WebAdsManager.createBannerAd(
          containerId: _adId,
          adSlot: adSlot,
          size: '728x90',
        );
        break;
      case WebAdType.rectangle:
        WebAdsManager.createBannerAd(
          containerId: _adId,
          adSlot: adSlot,
          size: '300x250',
        );
        break;
      case WebAdType.skyscraper:
        WebAdsManager.createBannerAd(
          containerId: _adId,
          adSlot: adSlot,
          size: '160x600',
        );
        break;
      case WebAdType.mobile:
        WebAdsManager.createBannerAd(
          containerId: _adId,
          adSlot: adSlot,
          size: '320x100',
        );
        break;
    }
    
    // 収益追跡
    WebAdsManager.trackRevenue(
      adNetwork: 'AdSense',
      adUnit: adSlot,
      action: 'impression',
    );
  }
  
  String _getDefaultAdSlot() {
    // 配置位置に応じたデフォルトの広告スロット
    switch (widget.placement) {
      case AdPlacement.header:
        return '1234567890'; // ヘッダー用スロット
      case AdPlacement.sidebar:
        return '1234567891'; // サイドバー用スロット
      case AdPlacement.content:
        return '1234567892'; // コンテンツ内用スロット
      case AdPlacement.footer:
        return '1234567893'; // フッター用スロット
      case AdPlacement.inline:
        return '1234567894'; // インライン用スロット
      default:
        return '1234567890';
    }
  }
  
  Widget _getAdSizeContainer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    // モバイルで表示しない設定の場合
    if (isMobile && !widget.showOnMobile) {
      return const SizedBox.shrink();
    }
    
    switch (widget.adType) {
      case WebAdType.responsive:
        return Container(
          width: double.infinity,
          height: isMobile ? 100 : 250,
          child: _buildAdContent(),
        );
      case WebAdType.banner:
      case WebAdType.leaderboard:
        return Container(
          width: isMobile ? screenWidth - 16 : 728,
          height: 90,
          child: _buildAdContent(),
        );
      case WebAdType.rectangle:
        return Container(
          width: 300,
          height: 250,
          child: _buildAdContent(),
        );
      case WebAdType.skyscraper:
        return Container(
          width: 160,
          height: 600,
          child: _buildAdContent(),
        );
      case WebAdType.mobile:
        return Container(
          width: 320,
          height: 100,
          child: _buildAdContent(),
        );
    }
  }
  
  Widget _buildAdContent() {
    if (_showAdBlock) {
      return _buildAdBlockMessage();
    }
    
    if (!_adLoaded) {
      return _buildLoadingIndicator();
    }
    
    return _buildAdContainer();
  }
  
  Widget _buildAdContainer() {
    if (kIsWeb) {
      // HTMLエレメントのコンテナとして使用
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'Advertisement',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ),
      );
    } else {
      return _buildFallbackWidget();
    }
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
  }
  
  Widget _buildAdBlockMessage() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            color: Colors.orange[700],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            '広告ブロッカーが検出されました',
            style: TextStyle(
              color: Colors.orange[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'サイトを支援するために広告を有効にしてください',
            style: TextStyle(
              color: Colors.orange[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFallbackWidget() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          '広告',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: widget.margin,
      child: _getAdSizeContainer(),
    );
  }
  
  @override
  void dispose() {
    // クリーンアップ
    if (kIsWeb) {
      try {
        html.document.getElementById(_adId)?.remove();
      } catch (e) {
        print('Failed to cleanup ad element: $e');
      }
    }
    super.dispose();
  }
}

/// 戦略的広告配置のヘルパーウィジェット
class StrategicAdPlacement extends StatelessWidget {
  final Widget content;
  final AdPlacement placement;
  final bool showAd;
  
  const StrategicAdPlacement({
    Key? key,
    required this.content,
    required this.placement,
    this.showAd = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!showAd || !kIsWeb) {
      return content;
    }
    
    switch (placement) {
      case AdPlacement.header:
        return Column(
          children: [
            const WebAdWidget(
              adType: WebAdType.leaderboard,
              placement: AdPlacement.header,
            ),
            content,
          ],
        );
        
      case AdPlacement.sidebar:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const SizedBox(width: 16),
            const Column(
              children: [
                WebAdWidget(
                  adType: WebAdType.rectangle,
                  placement: AdPlacement.sidebar,
                ),
                SizedBox(height: 16),
                WebAdWidget(
                  adType: WebAdType.rectangle,
                  placement: AdPlacement.sidebar,
                  customId: 'sidebar-2',
                ),
              ],
            ),
          ],
        );
        
      case AdPlacement.footer:
        return Column(
          children: [
            content,
            const WebAdWidget(
              adType: WebAdType.banner,
              placement: AdPlacement.footer,
            ),
          ],
        );
        
      default:
        return content;
    }
  }
}

/// レスポンシブ広告レイアウト
class ResponsiveAdLayout extends StatelessWidget {
  final Widget child;
  final bool showAds;
  
  const ResponsiveAdLayout({
    Key? key,
    required this.child,
    this.showAds = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!showAds || !kIsWeb) {
      return child;
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;
    
    if (isDesktop) {
      return _buildDesktopLayout();
    } else if (isTablet) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }
  
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // ヘッダー広告
        const WebAdWidget(
          adType: WebAdType.leaderboard,
          placement: AdPlacement.header,
        ),
        // メインコンテンツ + サイドバー広告
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: child),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    const WebAdWidget(
                      adType: WebAdType.rectangle,
                      placement: AdPlacement.sidebar,
                    ),
                    const SizedBox(height: 16),
                    const WebAdWidget(
                      adType: WebAdType.skyscraper,
                      placement: AdPlacement.sidebar,
                      customId: 'sidebar-skyscraper',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // フッター広告
        const WebAdWidget(
          adType: WebAdType.banner,
          placement: AdPlacement.footer,
        ),
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Column(
      children: [
        const WebAdWidget(
          adType: WebAdType.banner,
          placement: AdPlacement.header,
        ),
        Expanded(child: child),
        const WebAdWidget(
          adType: WebAdType.rectangle,
          placement: AdPlacement.footer,
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        const WebAdWidget(
          adType: WebAdType.mobile,
          placement: AdPlacement.header,
        ),
        Expanded(child: child),
        const WebAdWidget(
          adType: WebAdType.mobile,
          placement: AdPlacement.footer,
        ),
      ],
    );
  }
}