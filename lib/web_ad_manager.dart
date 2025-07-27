import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web版の広告表示を管理するクラス
class WebAdManager {
  static final WebAdManager _instance = WebAdManager._internal();
  factory WebAdManager() => _instance;
  WebAdManager._internal();

  // 広告表示履歴
  final Map<String, DateTime> _lastAdShown = {};
  final Map<String, int> _adShowCount = {};
  
  // タブ切り替え回数
  int _tabSwitchCount = 0;
  DateTime? _lastTabSwitchAdTime;
  
  // クールダウン時間（ミリ秒）
  static const int _interstitialCooldown = 180000; // 3分
  static const int _tabSwitchInterval = 3; // 3回のタブ切り替えごと
  
  /// インタースティシャル広告を表示できるかチェック
  bool canShowInterstitial(String adType) {
    if (!kIsWeb) return false;
    
    final lastShown = _lastAdShown[adType];
    if (lastShown == null) return true;
    
    final timeSinceLastAd = DateTime.now().difference(lastShown).inMilliseconds;
    return timeSinceLastAd >= _interstitialCooldown;
  }
  
  /// 広告表示を記録
  void recordAdShown(String adType) async {
    _lastAdShown[adType] = DateTime.now();
    _adShowCount[adType] = (_adShowCount[adType] ?? 0) + 1;
    
    // SharedPreferencesに保存
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ad_last_shown_$adType', DateTime.now().toIso8601String());
      await prefs.setInt('ad_count_$adType', _adShowCount[adType] ?? 0);
    }
  }
  
  /// タブ切り替えを記録し、広告表示判定
  bool shouldShowTabSwitchAd() {
    if (!kIsWeb) return false;
    
    _tabSwitchCount++;
    
    // 前回の広告表示から3分以上経過しているかチェック
    if (_lastTabSwitchAdTime != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastTabSwitchAdTime!).inMilliseconds;
      if (timeSinceLastAd < _interstitialCooldown) {
        return false;
      }
    }
    
    // 3回のタブ切り替えごとに広告を表示
    if (_tabSwitchCount >= _tabSwitchInterval) {
      _tabSwitchCount = 0;
      _lastTabSwitchAdTime = DateTime.now();
      return true;
    }
    
    return false;
  }
  
  /// 保存完了時の広告表示判定（50%の確率）
  bool shouldShowSaveCompletedAd() {
    if (!kIsWeb) return false;
    if (!canShowInterstitial('save_completed')) return false;
    
    // 50%の確率で表示
    return DateTime.now().millisecondsSinceEpoch % 2 == 0;
  }
  
  /// 分析完了時の広告表示判定
  bool shouldShowAnalysisCompletedAd() {
    if (!kIsWeb) return false;
    return canShowInterstitial('analysis_completed');
  }
  
  /// セッション開始時に履歴を読み込み
  Future<void> loadFromStorage() async {
    if (!kIsWeb) return;
    
    // タブ切り替え回数をリセット（セッションごと）
    _tabSwitchCount = 0;
    
    // 広告表示履歴を読み込み
    _adShowCount.clear();
    _lastAdShown.clear();
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('ad_'));
    
    for (final key in keys) {
      if (key.startsWith('ad_last_shown_')) {
        final adType = key.replaceFirst('ad_last_shown_', '');
        final dateStr = prefs.getString(key);
        if (dateStr != null) {
          try {
            _lastAdShown[adType] = DateTime.parse(dateStr);
          } catch (e) {
            print('Error parsing ad date: $e');
          }
        }
      } else if (key.startsWith('ad_count_')) {
        final adType = key.replaceFirst('ad_count_', '');
        final count = prefs.getInt(key);
        if (count != null) {
          _adShowCount[adType] = count;
        }
      }
    }
  }
  
  /// 広告統計情報を取得
  Map<String, dynamic> getStatistics() {
    return {
      'totalAdsShown': _adShowCount.values.fold(0, (sum, count) => sum + count),
      'adTypes': _adShowCount,
      'lastShown': _lastAdShown.map((key, value) => MapEntry(key, value.toIso8601String())),
      'currentTabSwitchCount': _tabSwitchCount,
    };
  }
}