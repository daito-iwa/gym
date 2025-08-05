import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web版の使用制限と広告インセンティブを管理するクラス
class WebUsageManager {
  static const String _dailyChatCountKey = 'daily_chat_count';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _adViewCountKey = 'ad_view_count';
  
  // 制限値
  static const int _baseDailyChatLimit = 10;
  static const int _adBonusChatLimit = 5;
  static const int _adViewsPerBonus = 3;
  
  static SharedPreferences? _prefs;
  
  /// 初期化
  static Future<void> initialize() async {
    if (!kIsWeb) return;
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetDaily();
  }
  
  /// 日次リセットのチェック
  static Future<void> _checkAndResetDaily() async {
    if (_prefs == null) return;
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastResetDate = _prefs!.getString(_lastResetDateKey);
    
    if (lastResetDate != today) {
      // 新しい日なのでカウンターをリセット
      await _prefs!.setInt(_dailyChatCountKey, 0);
      await _prefs!.setInt(_adViewCountKey, 0);
      await _prefs!.setString(_lastResetDateKey, today);
    }
  }
  
  /// 現在のチャット使用回数を取得
  static Future<int> getCurrentChatCount() async {
    if (_prefs == null) await initialize();
    await _checkAndResetDaily();
    return _prefs!.getInt(_dailyChatCountKey) ?? 0;
  }
  
  /// 現在の広告視聴回数を取得
  static Future<int> getCurrentAdViewCount() async {
    if (_prefs == null) await initialize();
    await _checkAndResetDaily();
    return _prefs!.getInt(_adViewCountKey) ?? 0;
  }
  
  /// 利用可能なチャット回数を取得
  static Future<int> getAvailableChatCount() async {
    final currentCount = await getCurrentChatCount();
    final adViewCount = await getCurrentAdViewCount();
    final adBonus = (adViewCount ~/ _adViewsPerBonus) * _adBonusChatLimit;
    final totalLimit = _baseDailyChatLimit + adBonus;
    
    return (totalLimit - currentCount).clamp(0, totalLimit);
  }
  
  /// チャット使用回数を増加
  static Future<void> incrementChatCount() async {
    if (_prefs == null) await initialize();
    await _checkAndResetDaily();
    
    final currentCount = await getCurrentChatCount();
    await _prefs!.setInt(_dailyChatCountKey, currentCount + 1);
  }
  
  /// 広告視聴回数を増加
  static Future<void> incrementAdViewCount() async {
    if (_prefs == null) await initialize();
    await _checkAndResetDaily();
    
    final currentCount = await getCurrentAdViewCount();
    await _prefs!.setInt(_adViewCountKey, currentCount + 1);
  }
  
  /// チャット使用可能かどうか
  static Future<bool> canUseChat() async {
    final availableCount = await getAvailableChatCount();
    return availableCount > 0;
  }
  
  /// 広告視聴で追加チャットを獲得可能かどうか
  static Future<bool> canGetAdBonus() async {
    final adViewCount = await getCurrentAdViewCount();
    final availableCount = await getAvailableChatCount();
    
    // 利用回数が残っている場合や、既に十分な広告を見ている場合は不要
    return availableCount == 0 && (adViewCount % _adViewsPerBonus) < _adViewsPerBonus;
  }
  
  /// 次の広告ボーナスまでの必要視聴回数
  static Future<int> getAdsUntilNextBonus() async {
    final adViewCount = await getCurrentAdViewCount();
    final remainder = adViewCount % _adViewsPerBonus;
    return _adViewsPerBonus - remainder;
  }
  
  /// 使用状況の詳細情報を取得
  static Future<Map<String, dynamic>> getUsageStats() async {
    final currentChatCount = await getCurrentChatCount();
    final adViewCount = await getCurrentAdViewCount();
    final availableChatCount = await getAvailableChatCount();
    final canGetBonus = await canGetAdBonus();
    final adsUntilBonus = await getAdsUntilNextBonus();
    
    return {
      'currentChatCount': currentChatCount,
      'adViewCount': adViewCount,
      'availableChatCount': availableChatCount,
      'baseDailyLimit': _baseDailyChatLimit,
      'adBonusLimit': _adBonusChatLimit,
      'adViewsPerBonus': _adViewsPerBonus,
      'canGetAdBonus': canGetBonus,
      'adsUntilNextBonus': adsUntilBonus,
      'totalEarnedBonus': (adViewCount ~/ _adViewsPerBonus) * _adBonusChatLimit,
    };
  }
}

/// 使用制限ダイアログを表示するためのヘルパークラス
class UsageLimitDialog {
  static Future<void> showLimitReached(
    BuildContext context, {
    required VoidCallback onWatchAd,
    required VoidCallback onClose,
  }) async {
    final stats = await WebUsageManager.getUsageStats();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange),
            SizedBox(width: 8),
            Text('使用制限に達しました'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今日のAIチャット使用回数: ${stats['currentChatCount']}/${stats['baseDailyLimit'] + stats['totalEarnedBonus']}'),
            const SizedBox(height: 8),
            if (stats['canGetAdBonus']) ...[
              const Text('追加使用回数を獲得できます！'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.play_circle, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('広告を見て追加回数を獲得', 
                             style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('広告${stats['adsUntilNextBonus']}回視聴で+${stats['adBonusLimit']}回使用可能'),
                  ],
                ),
              ),
            ] else ...[
              const Text('本日の使用可能回数をすべて使い切りました。'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '明日の0時にリセットされます。\nまたは広告を視聴して追加回数を獲得してください。',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (stats['canGetAdBonus'])
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onWatchAd();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('広告を見る'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}