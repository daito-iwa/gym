import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    // AdSense承認後に実際のスロットIDに変更する
    // 現在はデモ用のプレースホルダー
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
    // Web版では実際の広告はHTML側で表示される
    // ここではプレースホルダーを表示
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[50],
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
}