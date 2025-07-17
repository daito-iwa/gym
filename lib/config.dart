import 'package:flutter/foundation.dart';

class Config {
  // 後方互換性のため
  static String get baseUrl => AppConfig.baseUrl;
  static String get apiBaseUrl => AppConfig.apiBaseUrl;
}

enum Environment { development, staging, production }

class AppConfig {
  // 環境設定 - ビルド時に変更可能
  static const Environment _environment = Environment.development;
  
  // 環境別URL設定
  static const Map<Environment, String> _urls = {
    Environment.development: 'http://127.0.0.1:8000',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://api.your-domain.com',
  };
  
  // Web環境用の開発サーバーURL
  static const Map<Environment, String> _webUrls = {
    Environment.development: 'http://localhost:8000',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://api.your-domain.com',
  };
  
  // ネイティブ環境用の開発サーバーURL
  static const Map<Environment, String> _nativeUrls = {
    Environment.development: 'http://192.168.40.218:8000',
    Environment.staging: 'https://staging-api.your-domain.com',
    Environment.production: 'https://api.your-domain.com',
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