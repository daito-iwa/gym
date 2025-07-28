// モバイルアプリ版のみの設定ファイル

class Config {
  // 後方互換性のため
  static String get baseUrl => AppConfig.baseUrl;
  static String get apiBaseUrl => AppConfig.apiBaseUrl;
  static String get apiUrl => AppConfig.apiBaseUrl;
}

enum Environment { development, staging, production }

class AppConfig {
  // 環境設定 - 本番環境に切り替え可能
  // 開発時: Environment.development
  // 本番時: Environment.production
  static const Environment _environment = Environment.production;
  
  // 環境別URL設定
  static const Map<Environment, String> _urls = {
    Environment.development: 'http://127.0.0.1:8891',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://gym-96488789666.asia-northeast1.run.app',
  };
  
  // モバイルアプリ版のみのサーバーURL

  // 現在の環境
  static Environment get environment => _environment;
  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;

  // モバイルアプリ版のベースURL
  static String get baseUrl {
    return _urls[_environment]!;
  }

  // APIベースURL（メインのエンドポイント）
  static String get apiBaseUrl => baseUrl;
  
  // 環境別の設定
  static bool get enableDebugLogs => isDevelopment || isStaging;
  static bool get enableAnalytics => isProduction || isStaging;
  static Duration get apiTimeout => isDevelopment 
    ? const Duration(seconds: 60) 
    : const Duration(seconds: 30);
  
  // AIチャット機能制御フラグ
  // モバイルアプリ版のみ: 開発中状態（準備中画面を表示）
  static bool get enableAIChat {
    return false; // モバイル版では開発中（準備中画面表示）
  }
}