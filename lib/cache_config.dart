/// スキルデータキャッシュの設定管理
class CacheConfig {
  /// 現在のキャッシュ版数
  /// CSVデータやソート処理を更新した時は必ずこの値をインクリメントすること
  static const int CURRENT_CACHE_VERSION = 2;
  
  /// キャッシュ版数の履歴（デバッグ用）
  /// v1: 初期版
  /// v2: 2025-08-06 - グループ順ソート追加、skills_ja.csv更新
  
  /// データ整合性チェックの閾値
  static const double GROUP_1_RATIO_THRESHOLD = 0.8;  // グループ1が80%以上なら異常
  static const double A_DIFFICULTY_RATIO_THRESHOLD = 0.7;  // A難度が70%以上なら異常
  static const int MIN_GROUPS = 2;  // 最低限必要なグループ数
  static const int MIN_DIFFICULTIES = 3;  // 最低限必要な難度数
  
  /// キャッシュキーの生成
  static String getCacheKey(String apparatus, String language) {
    return '${apparatus}_${language}_v${CURRENT_CACHE_VERSION}';
  }
  
  /// 版数管理キーの生成
  static String getVersionKey(String apparatus, String language) {
    return '${apparatus}_${language}_version';
  }
}