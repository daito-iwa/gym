import 'package:flutter/foundation.dart';

class Config {
  // 後方互換性のため
  static String get baseUrl => AppConfig.baseUrl;
  static String get apiBaseUrl => AppConfig.apiBaseUrl;
}

enum Environment { development, staging, production }

class AppConfig {
  // 環境設定 - 本番環境に切り替え可能
  // 開発時: Environment.development
  // 本番時: Environment.production
  static const Environment _environment = Environment.production;
  
  // 環境別URL設定
  static const Map<Environment, String> _urls = {
    Environment.development: 'http://127.0.0.1:8888',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://gymnastics-ai-96488789666.asia-northeast1.run.app',
  };
  
  // Web環境用の開発サーバーURL
  static const Map<Environment, String> _webUrls = {
    Environment.development: 'http://127.0.0.1:8888',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://gymnastics-ai-96488789666.asia-northeast1.run.app',
  };
  
  // ネイティブ環境用の開発サーバーURL  
  static const Map<Environment, String> _nativeUrls = {
    Environment.development: 'http://127.0.0.1:8888',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://gymnastics-ai-96488789666.asia-northeast1.run.app',
  };

  // 現在の環境
  static Environment get environment => _environment;
  static bool get isDevelopment => _environment == Environment.development;
  static bool get isStaging => _environment == Environment.staging;
  static bool get isProduction => _environment == Environment.production;

  // プラットフォーム別のベースURL
  static String get baseUrl {
    if (kIsWeb) {
      return _webUrls[_environment] ?? _urls[_environment]!;
    } else {
      return _nativeUrls[_environment] ?? _urls[_environment]!;
    }
  }

  // APIベースURL（メインのエンドポイント）
  static String get apiBaseUrl => baseUrl;
  
  // 環境別の設定
  static bool get enableDebugLogs => isDevelopment || isStaging;
  static bool get enableAnalytics => isProduction || isStaging;
  static Duration get apiTimeout => isDevelopment 
    ? const Duration(seconds: 60) 
    : const Duration(seconds: 30);
}