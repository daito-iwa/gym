import 'package:flutter/foundation.dart';

class Config {
  // 後方互換性のため
  static String get baseUrl => AppConfig.baseUrl;
  static String get apiBaseUrl => AppConfig.apiBaseUrl;
}

class AppConfig {
  // 開発環境では適切なIPアドレスを使用
  static String get baseUrl {
    // Web環境の場合
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    
    // ネイティブ環境の場合 - ローカルネットワークIPを使用
    return 'http://192.168.40.218:8000';
  }

  // 本番環境用のURL（後で設定）
  static const String productionUrl = 'https://your-production-api.com';
  
  // 開発/本番モードの切り替え
  static bool get isProduction => false; // 本番時はtrueに変更

  static String get apiBaseUrl => isProduction ? productionUrl : baseUrl;
}