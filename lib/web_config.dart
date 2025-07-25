/// Web版専用の設定ファイル
/// Google AdSenseやWeb特有の設定を管理
class WebConfig {
  /// Google AdSense Publisher ID
  /// 実際のIDに置き換えてください
  static const String adSensePublisherId = 'ca-pub-XXXXXXXXXXXXXXXX';
  
  /// AdSense広告ユニットID
  static const AdSenseUnits adUnits = AdSenseUnits(
    /// ヘッダーバナー広告（728x90）
    headerBanner: 'YOUR_HEADER_BANNER_ID',
    
    /// フッターバナー広告（728x90）
    footerBanner: 'YOUR_FOOTER_BANNER_ID',
    
    /// サイドバー広告（300x250）
    sidebarRectangle: 'YOUR_SIDEBAR_RECTANGLE_ID',
    
    /// インフィード広告
    inFeed: 'YOUR_IN_FEED_ID',
    
    /// 記事内広告
    inArticle: 'YOUR_IN_ARTICLE_ID',
    
    /// レスポンシブ広告
    responsive: 'YOUR_RESPONSIVE_ID',
  );
  
  /// Web版の特別な機能フラグ
  static const bool enableWebAnalytics = true;
  static const bool enablePWA = true;
  static const bool enableOfflineMode = true;
  
  /// Web版のローカルストレージキー
  static const String webUserIdKey = 'gym_ai_web_user_id';
  static const String webSessionKey = 'gym_ai_web_session';
  static const String webPreferencesKey = 'gym_ai_web_preferences';
  
  /// Web版のセッションタイムアウト（分）
  static const int sessionTimeoutMinutes = 30;
  
  /// 広告表示間隔の設定
  static const AdDisplayIntervals adIntervals = AdDisplayIntervals(
    /// D-Score計算後の広告表示確率（%）
    afterDScoreCalculation: 50,
    
    /// チャットメッセージ数ごとの広告表示
    chatMessageInterval: 10,
    
    /// ページビューごとの広告表示
    pageViewInterval: 3,
  );
}

/// AdSense広告ユニットIDを管理するクラス
class AdSenseUnits {
  final String headerBanner;
  final String footerBanner;
  final String sidebarRectangle;
  final String inFeed;
  final String inArticle;
  final String responsive;
  
  const AdSenseUnits({
    required this.headerBanner,
    required this.footerBanner,
    required this.sidebarRectangle,
    required this.inFeed,
    required this.inArticle,
    required this.responsive,
  });
}

/// 広告表示間隔を管理するクラス
class AdDisplayIntervals {
  final int afterDScoreCalculation;
  final int chatMessageInterval;
  final int pageViewInterval;
  
  const AdDisplayIntervals({
    required this.afterDScoreCalculation,
    required this.chatMessageInterval,
    required this.pageViewInterval,
  });
}