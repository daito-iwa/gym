import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:csv/csv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';


import 'config.dart';
import 'd_score_calculator.dart'; // D-スコア計算とSkillクラスをインポート
import 'gymnastics_expert_database.dart'; // 専門知識データベース
import 'purchase_manager.dart'; // 正しいPurchaseManager
import 'admob_config.dart'; // AdMob設定
import 'platform_config.dart'; // プラットフォーム設定
import 'ad_widget.dart'; // ユニバーサル広告ウィジェット
import 'platform_ui_config.dart'; // プラットフォーム別UI設定
import 'web_config.dart'; // Web版設定
import 'web_ad_manager.dart'; // Web版広告管理
import 'propellerads_widget.dart'; // PropellerAds広告

// カスタム例外クラス
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class DataException implements Exception {
  final String message;
  DataException(this.message);
  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  @override
  String toString() => message;
}

// 分析用データモデル
class RoutineAnalysis {
  final String apparatus;
  final DateTime timestamp;
  final Map<String, int> difficultyDistribution;
  final Map<int, int> groupDistribution;
  final double connectionBonusRatio;
  final int totalSkills;
  final double averageDifficulty;
  final double completenessScore;
  final List<String> missingGroups;
  final Map<String, dynamic> recommendations;
  
  RoutineAnalysis({
    required this.apparatus,
    required this.timestamp,
    required this.difficultyDistribution,
    required this.groupDistribution,
    required this.connectionBonusRatio,
    required this.totalSkills,
    required this.averageDifficulty,
    required this.completenessScore,
    required this.missingGroups,
    required this.recommendations,
  });
}

// 演技構成分析クラス
class RoutineAnalyzer {
  // 演技構成の統計分析
  static Map<String, dynamic> analyzeRoutineStatistics(List<Skill> routine) {
    if (routine.isEmpty) {
      return {
        'totalSkills': 0,
        'averageDifficulty': 0.0,
        'highestDifficulty': 0.0,
        'lowestDifficulty': 0.0,
        'difficultyRange': 0.0,
      };
    }
    
    final difficulties = routine.map((skill) => skill.value).toList();
    final totalSkills = routine.length;
    final averageDifficulty = difficulties.reduce((a, b) => a + b) / totalSkills;
    final highestDifficulty = difficulties.reduce((a, b) => a > b ? a : b);
    final lowestDifficulty = difficulties.reduce((a, b) => a < b ? a : b);
    
    return {
      'totalSkills': totalSkills,
      'averageDifficulty': averageDifficulty,
      'highestDifficulty': highestDifficulty,
      'lowestDifficulty': lowestDifficulty,
      'difficultyRange': highestDifficulty - lowestDifficulty,
    };
  }
  
  // 難度分布の計算
  static Map<String, int> calculateDifficultyDistribution(List<Skill> routine) {
    final distribution = <String, int>{};
    for (final skill in routine) {
      final key = skill.valueLetter;
      distribution[key] = (distribution[key] ?? 0) + 1;
    }
    return distribution;
  }
  
  // グループ別技数統計
  static Map<int, int> calculateGroupDistribution(List<Skill> routine) {
    final distribution = <int, int>{};
    for (final skill in routine) {
      final group = skill.group;
      distribution[group] = (distribution[group] ?? 0) + 1;
    }
    return distribution;
  }
  
  // 改善提案の生成
  static List<String> generateImprovementSuggestions(
    String apparatus,
    List<Skill> routine,
    Map<int, int> groupDistribution,
    Map<String, int> difficultyDistribution,
  ) {
    final suggestions = <String>[];
    
    // 基本統計の取得
    final stats = analyzeRoutineStatistics(routine);
    final averageDifficulty = stats['averageDifficulty'] as double;
    final totalSkills = stats['totalSkills'] as int;
    
    // 難度改善提案
    if (averageDifficulty < 0.3) {
      suggestions.add('平均難度が低めです。C難度以上の技を増やすことを検討してください');
    } else if (averageDifficulty < 0.4) {
      suggestions.add('より高難度の技を追加することで得点アップが期待できます');
    }
    
    // 技数最適化
    if (totalSkills < 8) {
      suggestions.add('技数を増やして構成を充実させましょう（推奨：8-10技）');
    } else if (totalSkills > 12) {
      suggestions.add('技数を調整してリスクを下げることを検討してください');
    }
    
    // グループバランス改善
    final requiredGroups = _getRequiredGroupsForApparatus(apparatus);
    final missingGroups = requiredGroups.difference(groupDistribution.keys.toSet());
    if (missingGroups.isNotEmpty) {
      suggestions.add('グループ${missingGroups.join(', ')}の技を追加してください');
    }
    
    // 難度バランス改善
    final hasOnlyEasySkills = difficultyDistribution.keys.every((key) => 
      ['A', 'B'].contains(key));
    if (hasOnlyEasySkills && totalSkills > 0) {
      suggestions.add('C難度以上の技を追加してDスコアを向上させましょう');
    }
    
    // 特定の種目に対する提案
    switch (apparatus) {
      case 'FX':
        if (!groupDistribution.containsKey(4)) {
          suggestions.add('フロアでは終末技（グループ4）が重要です');
        }
        break;
      case 'HB':
        if (!groupDistribution.containsKey(5)) {
          suggestions.add('鉄棒では終末技（グループ5）が必須です');
        }
        break;
      case 'VT':
        if (totalSkills < 2) {
          suggestions.add('跳馬では第1跳躍と第2跳躍の両方が必要です');
        }
        break;
    }
    
    return suggestions;
  }
  
  // 種目に必要なグループを取得
  static Set<int> _getRequiredGroupsForApparatus(String apparatus) {
    switch (apparatus) {
      case 'FX':
        return {1, 2, 3, 4};
      case 'PH':
        return {1, 2, 3, 4, 5};
      case 'SR':
        return {1, 2, 3, 4, 5};
      case 'VT':
        return {1, 2, 3, 4, 5};
      case 'PB':
        return {1, 2, 3, 4, 5};
      case 'HB':
        return {1, 2, 3, 4, 5};
      default:
        return {1, 2, 3, 4};
    }
  }
  
  // 要求充足率の計算
  static double calculateCompletenessScore(String apparatus, Map<int, int> groupDistribution) {
    final requiredGroups = _getRequiredGroupsForApparatus(apparatus);
    final presentGroups = groupDistribution.keys.toSet();
    return presentGroups.intersection(requiredGroups).length / requiredGroups.length;
  }
  
  // 総合評価スコアの計算
  static double calculateOverallScore(
    String apparatus,
    List<Skill> routine,
    Map<int, int> groupDistribution,
  ) {
    if (routine.isEmpty) return 0.0;
    
    final stats = analyzeRoutineStatistics(routine);
    final averageDifficulty = stats['averageDifficulty'] as double;
    final completenessScore = calculateCompletenessScore(apparatus, groupDistribution);
    
    // 各要素の重み付け
    final difficultyWeight = 0.4;
    final completenessWeight = 0.4;
    final balanceWeight = 0.2;
    
    // バランススコア（技数の適正さ）
    final totalSkills = routine.length;
    final balanceScore = totalSkills >= 8 && totalSkills <= 12 ? 1.0 : 0.7;
    
    return (averageDifficulty / 0.6) * difficultyWeight +
           completenessScore * completenessWeight +
           balanceScore * balanceWeight;
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gymnastics AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF0f0f1e),
        ),
        // Add other theme properties as needed
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// AppMode enumはplatform_ui_config.dartで定義

// ユーザーティアシステム
enum UserTier { free, premium }

// ユーザーサブスクリプション情報
class UserSubscription {
  final UserTier tier;
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final bool isActive;

  UserSubscription({
    required this.tier,
    this.subscriptionStart,
    this.subscriptionEnd,
  }) : isActive = tier == UserTier.premium && 
                  subscriptionEnd != null && 
                  subscriptionEnd.isAfter(DateTime.now());


  bool get isPremium => tier == UserTier.premium && isActive;
  bool get isFree => tier == UserTier.free || !isActive;

  // 機能アクセス権限チェック（Web版拡張 + モバイル版フリーミアム）
  bool canAccessDScore() => true; // 全プラットフォーム対応
  bool canAccessAllApparatus() => PlatformConfig.isWeb || isPremium; // Web無料 or モバイルプレミアム
  bool canAccessAnalytics() => PlatformConfig.isWeb || isPremium; // Web無料 or モバイルプレミアム
  bool canAccessUnlimitedChat() => !PlatformConfig.isWeb && isPremium; // モバイル限定プレミアム
  bool shouldShowAds() => isFree;
}

// D-Score計算使用量追跡クラス
class DScoreUsageTracker {
  // プラットフォーム別の制限を使用
  static int get dailyFreeLimit => PlatformConfig.maxDailyDScoreCalculations;
  static int get dailyBonusLimit => dailyFreeLimit + 2; // ボーナス含めて+2回
  
  static const String _dailyUsageKey = 'dscore_daily_usage';
  static const String _bonusCreditsKey = 'dscore_bonus_credits';
  static const String _lastResetDateKey = 'dscore_last_reset_date';
  
  static Future<void> _resetUsageIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastReset = prefs.getString(_lastResetDateKey);
    
    if (lastReset != today) {
      await prefs.setInt(_dailyUsageKey, 0);
      await prefs.setString(_lastResetDateKey, today);
    }
  }
  
  static Future<int> getDailyUsage() async {
    await _resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyUsageKey) ?? 0;
  }
  
  static Future<int> getBonusCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_bonusCreditsKey) ?? 0;
  }
  
  static Future<bool> canCalculateDScore(UserSubscription subscription) async {
    if (subscription.isPremium) {
      return true; // プレミアムユーザーは無制限
    }
    
    final dailyUsage = await getDailyUsage();
    final bonusCredits = await getBonusCredits();
    
    return dailyUsage < dailyFreeLimit || bonusCredits > 0;
  }
  
  static Future<void> recordDScoreUsage(UserSubscription subscription) async {
    if (subscription.isPremium) {
      return; // プレミアムユーザーは記録しない
    }
    
    final prefs = await SharedPreferences.getInstance();
    final dailyUsage = await getDailyUsage();
    
    if (dailyUsage < dailyFreeLimit) {
      // 無料枠を使用
      await prefs.setInt(_dailyUsageKey, dailyUsage + 1);
    } else {
      // ボーナスクレジットを使用
      final bonusCredits = await getBonusCredits();
      if (bonusCredits > 0) {
        await prefs.setInt(_bonusCreditsKey, bonusCredits - 1);
      }
    }
  }
  
  static Future<void> grantCalculationBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final currentBonus = await getBonusCredits();
    await prefs.setInt(_bonusCreditsKey, currentBonus + 2); // +2回ボーナス
  }
  
  static Future<bool> isNearDailyLimit() async {
    final dailyUsage = await getDailyUsage();
    return dailyUsage >= (dailyFreeLimit * 0.8).round(); // 80%に達したら警告
  }
  
  static Future<String> getUsageStatus(UserSubscription subscription) async {
    if (subscription.isPremium) {
      return 'プレミアム: 無制限';
    }
    
    final dailyUsage = await getDailyUsage();
    final bonusCredits = await getBonusCredits();
    
    return '本日: $dailyUsage/$dailyFreeLimit | ボーナス: ${bonusCredits}回';
  }
}

// チャット使用量追跡クラス
class ChatUsageTracker {
  static const String _dailyUsageKey = 'daily_chat_usage';
  static const String _monthlyUsageKey = 'monthly_chat_usage';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _monthlyResetDateKey = 'monthly_reset_date';
  
  // プラットフォーム別の制限を使用
  static int get dailyFreeLimit => PlatformConfig.maxDailyChatCount;
  static int get monthlyFreeLimit => PlatformConfig.maxMonthlyChatCount;
  
  static Future<void> _resetUsageIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = DateTime(now.year, now.month);
    
    // 日次リセット
    final lastResetString = prefs.getString(_lastResetDateKey);
    if (lastResetString != null) {
      final lastReset = DateTime.parse(lastResetString);
      if (lastReset.isBefore(today)) {
        await prefs.setInt(_dailyUsageKey, 0);
        await prefs.setString(_lastResetDateKey, today.toIso8601String());
      }
    } else {
      await prefs.setString(_lastResetDateKey, today.toIso8601String());
    }
    
    // 月次リセット
    final monthlyResetString = prefs.getString(_monthlyResetDateKey);
    if (monthlyResetString != null) {
      final monthlyReset = DateTime.parse(monthlyResetString);
      if (monthlyReset.isBefore(thisMonth)) {
        await prefs.setInt(_monthlyUsageKey, 0);
        await prefs.setString(_monthlyResetDateKey, thisMonth.toIso8601String());
      }
    } else {
      await prefs.setString(_monthlyResetDateKey, thisMonth.toIso8601String());
    }
  }
  
  static Future<int> getDailyUsage() async {
    await _resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyUsageKey) ?? 0;
  }
  
  static Future<int> getMonthlyUsage() async {
    await _resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_monthlyUsageKey) ?? 0;
  }
  
  static Future<void> incrementUsage() async {
    await _resetUsageIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    
    await prefs.setInt(_dailyUsageKey, dailyUsage + 1);
    await prefs.setInt(_monthlyUsageKey, monthlyUsage + 1);
  }
  
  static Future<int> getBonusCredits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('chat_bonus_credits') ?? 0;
  }
  
  static Future<void> useBonusCredit() async {
    final prefs = await SharedPreferences.getInstance();
    final currentBonus = await getBonusCredits();
    if (currentBonus > 0) {
      await prefs.setInt('chat_bonus_credits', currentBonus - 1);
    }
  }
  
  static Future<void> recordChatUsage(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return; // Premium users don't need usage tracking
    }
    
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    
    // If within normal limits, use normal usage tracking
    if (dailyUsage < dailyFreeLimit && monthlyUsage < monthlyFreeLimit) {
      await incrementUsage();
    } else {
      // User has exceeded limits, use bonus credit instead
      await useBonusCredit();
    }
  }
  
  static Future<bool> canSendMessage(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return true;
    }
    
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    final bonusCredits = await getBonusCredits();
    
    // Check if within normal limits
    if (dailyUsage < dailyFreeLimit && monthlyUsage < monthlyFreeLimit) {
      return true;
    }
    
    // Check if can use bonus credits to exceed daily/monthly limits
    return bonusCredits > 0;
  }
  
  static Future<String> getUsageStatus(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return 'プレミアム: 無制限';
    }
    
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    final bonusCredits = await getBonusCredits();
    
    final baseStatus = '本日: $dailyUsage/$dailyFreeLimit | 今月: $monthlyUsage/$monthlyFreeLimit';
    
    if (bonusCredits > 0) {
      return '$baseStatus | ボーナス: $bonusCredits回';
    }
    
    return baseStatus;
  }
  
  static Future<bool> isNearDailyLimit(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return false;
    }
    
    final dailyUsage = await getDailyUsage();
    return dailyUsage >= (dailyFreeLimit * 0.8).round();
  }
  
  static Future<bool> isNearMonthlyLimit(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return false;
    }
    
    final monthlyUsage = await getMonthlyUsage();
    return monthlyUsage >= (monthlyFreeLimit * 0.8).round();
  }
}


// 広告システム管理クラス
class AdManager {
  
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;
  
  // 広告システム初期化
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    print('AdMob initialized');
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
  }
  
  // バナー広告読み込み
  void _loadBannerAd({int retryCount = 0}) {
    _bannerAd = BannerAd(
      adUnitId: _getBannerAdId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('Banner ad loaded');
          _isBannerAdReady = true;
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
          _isBannerAdReady = false;
          
          // Retry logic with exponential backoff
          if (retryCount < 3) {
            final delaySeconds = (retryCount + 1) * 2;
            Timer(Duration(seconds: delaySeconds), () {
              _loadBannerAd(retryCount: retryCount + 1);
            });
          }
        },
      ),
    );
    
    _bannerAd?.load();
    
    // Add timeout handling
    Timer(Duration(seconds: 10), () {
      if (!_isBannerAdReady && _bannerAd != null) {
        print('Banner ad load timeout');
        _bannerAd?.dispose();
        _isBannerAdReady = false;
      }
    });
  }
  
  // インタースティシャル広告読み込み
  void _loadInterstitialAd({int retryCount = 0}) {
    InterstitialAd.load(
      adUnitId: _getInterstitialAdId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('Interstitial ad loaded');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;
          
          // Retry logic with exponential backoff
          if (retryCount < 3) {
            final delaySeconds = (retryCount + 1) * 2;
            Timer(Duration(seconds: delaySeconds), () {
              _loadInterstitialAd(retryCount: retryCount + 1);
            });
          }
        },
      ),
    );
    
    // Add timeout handling
    Timer(Duration(seconds: 15), () {
      if (!_isInterstitialAdReady) {
        print('Interstitial ad load timeout');
        _isInterstitialAdReady = false;
      }
    });
  }
  
  // リワード広告読み込み
  void _loadRewardedAd({int retryCount = 0}) {
    RewardedAd.load(
      adUnitId: _getRewardedAdId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('Rewarded ad loaded');
          _rewardedAd = ad;
          _isRewardedAdReady = true;
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
          _isRewardedAdReady = false;
          
          // Retry logic with exponential backoff
          if (retryCount < 3) {
            final delaySeconds = (retryCount + 1) * 2;
            Timer(Duration(seconds: delaySeconds), () {
              _loadRewardedAd(retryCount: retryCount + 1);
            });
          }
        },
      ),
    );
    
    // Add timeout handling
    Timer(Duration(seconds: 15), () {
      if (!_isRewardedAdReady) {
        print('Rewarded ad load timeout');
        _isRewardedAdReady = false;
      }
    });
  }
  
  // バナー広告ID取得
  String _getBannerAdId() {
    return AdMobConfig.bannerAdUnitId;
  }
  
  // インタースティシャル広告ID取得
  String _getInterstitialAdId() {
    return AdMobConfig.interstitialAdUnitId;
  }
  
  // リワード広告ID取得
  String _getRewardedAdId() {
    return AdMobConfig.rewardedAdUnitId;
  }
  
  // インタースティシャル広告表示
  void showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
      
      // 次の広告を準備
      _loadInterstitialAd();
    } else {
      print('Interstitial ad is not ready');
    }
  }
  
  // リワード広告表示
  Future<bool> showRewardedAd() async {
    if (_isRewardedAdReady && _rewardedAd != null) {
      bool rewardEarned = false;
      
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          print('Rewarded ad dismissed');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          _loadRewardedAd(); // 次の広告を準備
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          print('Rewarded ad failed to show: $error');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          _loadRewardedAd(); // 次の広告を準備
        },
      );
      
      await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
        rewardEarned = true;
      });
      
      return rewardEarned;
    } else {
      print('Rewarded ad is not ready');
      // 広告が準備できていない場合は再読み込みを試す
      if (!_isRewardedAdReady) {
        _loadRewardedAd();
      }
      return false;
    }
  }
  
  // バナー広告ウィジェット作成
  Widget? createBannerAdWidget() {
    if (_isBannerAdReady && _bannerAd != null) {
      return Container(
        height: _bannerAd!.size.height.toDouble(),
        width: _bannerAd!.size.width.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return null;
  }
  
  // リソース解放
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
  
  // 公開メソッド
  void loadRewardedAd() => _loadRewardedAd();
  
  // ゲッター
  bool get isBannerAdReady => _isBannerAdReady;
  bool get isInterstitialAdReady => _isInterstitialAdReady;
  bool get isRewardedAdReady => _isRewardedAdReady;
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  AppMode _currentMode = AppMode.dScore; // 全プラットフォームでD-Score計算を初期画面に設定
  final TextEditingController _textController = TextEditingController();
  
  // ユーザーサブスクリプション管理
  UserSubscription _userSubscription = UserSubscription(tier: UserTier.free);
  bool _isLoadingSubscription = false;
  bool _isAdmin = false;
  Timer? _subscriptionCheckTimer; // 定期的なサブスクリプション状態チェック用
  
  // 課金システム管理
  PurchaseManager? _purchaseManager;
  bool _isPurchaseManagerInitialized = false;
  
  // 広告システム管理
  late AdManager _adManager;
  bool _isAdManagerInitialized = false;
  
  // サーバー接続状態
  bool _isServerOnline = false;
  
  // バックグラウンド初期化状態
  bool _isBackgroundInitComplete = false;
  
  // 管理者パネル用データ
  Map<String, dynamic>? _adminAnalytics;
  List<dynamic>? _adminUsers;
  bool _isLoadingAdminData = false;

  // プレミアム機能アクセス制御
  bool _checkPremiumAccess(AppMode mode) {
    switch (mode) {
      case AppMode.dScore:
        return _userSubscription.canAccessDScore();
      case AppMode.allApparatus:
        return _userSubscription.canAccessAllApparatus();
      case AppMode.analytics:
        return _userSubscription.canAccessAnalytics();
      case AppMode.admin:
        return _isAdmin;
      case AppMode.chat:
        return PlatformConfig.isWeb ? false : true; // Web版では制限、モバイル版では無料
    }
  }

  // 安全にモード切り替えを行うメソッド（プレミアムチェック付き）
  bool _safeSwitchToMode(AppMode targetMode, {String? featureName}) {
    if (_checkPremiumAccess(targetMode)) {
      setState(() {
        _currentMode = targetMode;
      });
      
      // 特殊処理
      if (targetMode == AppMode.admin) {
        _loadAdminData();
      }
      return true;
    } else {
      final displayName = featureName ?? _getModeDisplayName(targetMode);
      _showUpgradeDialog(displayName);
      return false;
    }
  }

  // モード表示名を取得
  String _getModeDisplayName(AppMode mode) {
    switch (mode) {
      case AppMode.dScore:
        return 'D-Score計算';
      case AppMode.allApparatus:
        return '全種目分析';
      case AppMode.analytics:
        return 'アナリティクス';
      case AppMode.admin:
        return '管理者パネル';
      case AppMode.chat:
        return 'AIチャット';
    }
  }

  // アップグレード促進ダイアログ
  void _showUpgradeDialog(String featureName) {
    if (PlatformConfig.isWeb) {
      // Web版ではAIチャット機能のモバイルアプリ誘導
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              '📱 モバイルアプリ限定機能',
              style: TextStyle(color: Colors.blue[300]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smartphone,
                  color: Colors.blue,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'AIチャット機能はモバイルアプリでのみご利用いただけます。',
                  style: TextStyle(color: Colors.grey[300]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'モバイルアプリでは以下の追加機能をご利用いただけます：',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                SizedBox(height: 8),
                Column(
                  children: [
                    Text('🤖 高度なAIチャット機能', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    Text('📱 オフライン利用', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    Text('🔔 プッシュ通知', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                    Text('⚡ 高速レスポンス', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('閉じる', style: TextStyle(color: Colors.grey[400])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _launchAppStore();
                },
                child: Text('📱 アプリをダウンロード'),
              ),
            ],
          );
        },
      );
    } else {
      // モバイル版では従来のアップグレードダイアログ
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              _getText('premiumFeatures'),
              style: TextStyle(color: Colors.blue[300]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  '$featureName ${_getText('premiumFeatureDescription')}',
                  style: TextStyle(color: Colors.grey[300]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  _getText('premiumMessage'),
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(_getText('cancel'), style: TextStyle(color: Colors.grey[400])),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
                child: Text(_getText('upgrade')),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSubscriptionPage();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // サブスクリプション購入画面
  void _showSubscriptionPage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            _getText('premiumPurchase'),
            style: TextStyle(color: Colors.blue[300]),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star,
                color: Colors.amber,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                '月額500円',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'プレミアム機能で解除される内容:',
                style: TextStyle(color: Colors.grey[300]),
              ),
              SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureRow('D-Score計算機能'),
                  _buildFeatureRow('全種目分析機能'),
                  _buildFeatureRow('アナリティクス機能'),
                  _buildFeatureRow('広告なし'),
                ],
              ),
              SizedBox(height: 16),
              if (!kIsWeb && _purchaseManager?.purchasePending == true)
                CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: Text(_getText('purchase')),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _purchasePremium();
                      },
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      child: Text('購入履歴を復元', style: TextStyle(color: Colors.grey[400])),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _restorePurchases();
                      },
                    ),
                    SizedBox(height: 8),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(_getText('cancel'), style: TextStyle(color: Colors.grey[400])),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text(feature, style: TextStyle(color: Colors.grey[300])),
        ],
      ),
    );
  }
  
  // 機能アイテム表示ヘルパー
  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(Icons.check, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text(feature, style: TextStyle(color: Colors.grey[300])),
        ],
      ),
    );
  }
  
  // プレミアム購入処理
  Future<void> _purchasePremium() async {
    try {
      // Web版では購入機能を無効化
      if (kIsWeb) {
        _showMessage('Web版では購入機能をご利用いただけません。モバイルアプリ版をお試しください。');
        return;
      }
      
      setState(() {
        _isLoadingSubscription = true;
      });
      
      final bool success = await _purchaseManager!.purchasePremium();
      
      if (success) {
        _showMessage('購入処理を開始しました');
      } else {
        _showMessage('購入に失敗しました');
      }
    } catch (e) {
      _showMessage('購入エラー: $e');
    } finally {
      setState(() {
        _isLoadingSubscription = false;
      });
    }
  }
  
  // 購入成功ダイアログ
  void _showPurchaseSuccessDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Row(
            children: [
              const Icon(Icons.celebration, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                _currentLang == 'English' ? 'Purchase Successful!' : '購入完了！',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentLang == 'English' 
                  ? 'Thank you for upgrading to Premium! You now have access to all features.'
                  : 'プレミアムプランへのアップグレードありがとうございます！全ての機能がご利用いただけます。',
                style: TextStyle(color: Colors.grey[300]),
              ),
              const SizedBox(height: 16),
              Text(
                _currentLang == 'English' ? 'Premium Features:' : 'プレミアム機能:',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem(_currentLang == 'English' ? 'D-Score Calculator' : 'D-スコア計算'),
              _buildFeatureItem(_currentLang == 'English' ? 'All Apparatus Analysis' : '全種目分析'),
              _buildFeatureItem(_currentLang == 'English' ? 'Advanced Analytics' : '高度な分析機能'),
              _buildFeatureItem(_currentLang == 'English' ? 'Unlimited Chat' : '無制限チャット'),
              _buildFeatureItem(_currentLang == 'English' ? 'Ad-free Experience' : '広告なし'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                _currentLang == 'English' ? 'OK' : 'OK',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // 購入履歴復元
  Future<void> _restorePurchases() async {
    try {
      // Web版では購入復元機能を無効化
      if (kIsWeb) {
        _showMessage('Web版では購入復元機能をご利用いただけません。');
        return;
      }
      
      setState(() {
        _isLoadingSubscription = true;
      });
      
      await _purchaseManager!.restorePurchases();
      _showMessage('購入履歴を復元しました');
    } catch (e) {
      _showMessage('復元エラー: $e');
    } finally {
      setState(() {
        _isLoadingSubscription = false;
      });
    }
  }

  final List<ChatMessage> _messages = []; // 型定義のため保持（使用しない）
  final List<AnalyticsMessage> _analyticsMessages = [];
  String _session_id = Uuid().v4(); // 型定義のため保持（使用しない）
  bool _isLoading = false; // 型定義のため保持（使用しない）
  bool _isAnalyticsLoading = false;
  String _currentLang = '日本語';
  
  // 翻訳辞書
  Map<String, Map<String, String>> _appTexts = {
    '日本語': {
      // ナビゲーション
      'ruleBookChat': 'ルールブックAIチャット',
      'dScoreCalculator': 'Dスコア計算',
      'allApparatus': '全種目一覧',
      'routineAnalysis': '演技構成分析',
      'adminPanel': '管理者パネル',
      'settings': '設定',
      'modeSelection': 'モード選択',
      
      // ボタン
      'upgrade': 'アップグレード',
      'purchase': '購入する',
      'resetChat': 'チャットをリセット',
      'getStatistics': '統計情報を取得',
      'clearCache': 'キャッシュクリア',
      'calculate': '計算実行',
      'addSkill': '技を追加',
      'changeSkill': '技を変更',
      'connectionSettings': '連続技設定',
      'connectWithPrevious': '前の技と繋げる',
      'cancel': 'キャンセル',
      'delete': '削除',
      'save': '保存',
      'confirm': '確認',
      'close': '閉じる',
      'back': '戻る',
      'next': '次へ',
      'retry': '再試行',
      'send': '送信',
      
      // メッセージ
      'loginSuccess': 'ログインに成功しました',
      'accountCreated': 'アカウントが作成されました',
      'cacheCleared': 'キャッシュをクリアしました',
      'routineSaved': '演技構成を保存しました',
      'loadingError': '読み込み中にエラーが発生しました',
      'deleteError': '削除中にエラーが発生しました',
      'analysisError': '分析中にエラーが発生しました',
      'networkError': 'ネットワークエラーが発生しました',
      'checkConnection': 'インターネット接続を確認してください',
      'instagramError': 'Instagramを開くことができませんでした',
      
      // ダイアログ
      'premiumFeatures': 'プレミアム機能',
      'premiumPurchase': 'プレミアム購入',
      'cacheConfirm': 'キャッシュをクリアしますか？この操作は取り消せません。',
      'deleteConfirm': '削除確認',
      'premiumUpgrade': '月額500円でアップグレード',
      'premiumFeatureDescription': 'はプレミアム機能です',
      'premiumMessage': '月額500円でD-Score計算、全種目分析、アナリティクス機能が使い放題！',
      
      // フォーム
      'selectApparatus': '種目を選択してください',
      'tapToEdit': '技をタップして編集',
      'rulebookLanguage': 'ルールブックの言語:',
      'language': '言語',
      'skillName': '技名',
      'difficulty': '難度',
      'group': 'グループ',
      
      // エクスポート
      'exportTitle': '体操 D-スコア計算結果',
      'generatedTime': '生成日時:',
      'apparatus': '種目:',
      'routine': '演技構成:',
      'dScoreResults': 'D-スコア結果:',
      'totalScore': '合計スコア:',
      'difficultyScore': '難度点:',
      'connectionBonus': 'つなぎ加点:',
      'groupBonus': 'グループボーナス:',
      'skillCount': '技数:',
      'averageDifficulty': '平均難度:',
      'analysis': '分析結果:',
      'completenessScore': '完成度スコア:',
      'connectionBonusRatio': 'つなぎ加点比率:',
      'missingGroups': '不足グループ:',
      
      // フィードバック
      'feedbackTitle': 'フィードバック・バグ報告',
      'feedbackMessage': 'アプリの改善点や不具合を報告してください。InstagramのDMでお気軽にお知らせください。',
      'openInstagram': 'Instagramを開く',
      
      // 統計情報
      'totalUsers': '総ユーザー数',
      'activeUsers': 'アクティブユーザー数',
      'premiumUsers': 'プレミアムユーザー数',
      'totalCalculations': '総計算回数',
      'averageSessionTime': '平均セッション時間',
      'loadingStats': '統計情報を読み込み中...',
      'loadingFailed': '統計情報の読み込みに失敗しました',
      
      // 管理者パネル
      'adminDashboard': '管理者ダッシュボード',
      'userManagement': 'ユーザー管理',
      'systemStats': 'システム統計',
      'errorLogs': 'エラーログ',
      'settings': '設定',
      
      // 課金システム
      'purchaseManager': '課金システム',
      'subscriptionPlan': 'サブスクリプションプラン',
      'monthlyPlan': '月額プラン',
      'freePlan': '無料プラン',
      'premiumPlan': 'プレミアムプラン',
      'purchaseError': '購入処理でエラーが発生しました',
      'purchaseSuccess': '購入が完了しました',
      'restorePurchase': '購入を復元',
      'manageSubscription': 'サブスクリプション管理',
      
      // 器具名
      'floor': '床',
      'pommelHorse': 'あん馬',
      'stillRings': 'つり輪',
      'vault': '跳馬',
      'parallelBars': '平行棒',
      'horizontalBar': '鉄棒',
      
      // その他
      'version': 'バージョン',
      'about': 'このアプリについて',
      'privacyPolicy': 'プライバシーポリシー',
      'termsOfService': '利用規約',
      'contact': 'お問い合わせ',
      'help': 'ヘルプ',
      'tutorial': 'チュートリアル',
      'login': 'ログイン',
      'profile': 'プロフィール',
      'notifications': '通知',
      'darkMode': 'ダークモード',
      'lightMode': 'ライトモード',
      'theme': 'テーマ',
    },
    'English': {
      // Navigation
      'ruleBookChat': 'Rulebook AI Chat',
      'dScoreCalculator': 'D-Score Calculator',
      'allApparatus': 'All Apparatus',
      'routineAnalysis': 'Routine Analysis',
      'adminPanel': 'Admin Panel',
      'settings': 'Settings',
      'modeSelection': 'Mode Selection',
      
      // Buttons
      'upgrade': 'Upgrade',
      'purchase': 'Purchase',
      'resetChat': 'Reset Chat',
      'getStatistics': 'Get Statistics',
      'clearCache': 'Clear Cache',
      'calculate': 'Calculate',
      'addSkill': 'Add Skill',
      'changeSkill': 'Change Skill',
      'connectionSettings': 'Connection Settings',
      'connectWithPrevious': 'Connect with Previous',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'confirm': 'Confirm',
      'close': 'Close',
      'back': 'Back',
      'next': 'Next',
      'retry': 'Retry',
      'send': 'Send',
      
      // Messages
      'loginSuccess': 'Login successful',
      'accountCreated': 'Account created',
      'cacheCleared': 'Cache cleared',
      'routineSaved': 'Routine saved',
      'loadingError': 'Error occurred during loading',
      'deleteError': 'Error occurred during deletion',
      'analysisError': 'Error occurred during analysis',
      'networkError': 'Network error occurred',
      'checkConnection': 'Please check your internet connection',
      'instagramError': 'Could not open Instagram',
      
      // Dialogs
      'premiumFeatures': 'Premium Features',
      'premiumPurchase': 'Premium Purchase',
      'cacheConfirm': 'Clear cache? This operation cannot be undone.',
      'deleteConfirm': 'Delete Confirmation',
      'premiumUpgrade': 'Upgrade for \$5/month',
      'premiumFeatureDescription': 'is a premium feature',
      'premiumMessage': 'Get unlimited access to D-Score calculation, all apparatus analysis, and analytics features for \$5/month!',
      
      // Forms
      'selectApparatus': 'Please select an apparatus',
      'tapToEdit': 'Tap skill to edit',
      'rulebookLanguage': 'Rulebook Language:',
      'language': 'Language',
      'skillName': 'Skill Name',
      'difficulty': 'Difficulty',
      'group': 'Group',
      
      // Export
      'exportTitle': 'Gymnastics D-Score Calculation Results',
      'generatedTime': 'Generated Time:',
      'apparatus': 'Apparatus:',
      'routine': 'Routine:',
      'dScoreResults': 'D-Score Results:',
      'totalScore': 'Total Score:',
      'difficultyScore': 'Difficulty Score:',
      'connectionBonus': 'Connection Bonus:',
      'groupBonus': 'Group Bonus:',
      'skillCount': 'Number of Skills:',
      'averageDifficulty': 'Average Difficulty:',
      'analysis': 'Analysis Results:',
      'completenessScore': 'Completeness Score:',
      'connectionBonusRatio': 'Connection Bonus Ratio:',
      'missingGroups': 'Missing Groups:',
      
      // Feedback
      'feedbackTitle': 'Feedback & Bug Report',
      'feedbackMessage': 'Please report any improvement suggestions or bugs. Feel free to reach out via Instagram DM.',
      'openInstagram': 'Open Instagram',
      
      // Statistics
      'totalUsers': 'Total Users',
      'activeUsers': 'Active Users',
      'premiumUsers': 'Premium Users',
      'totalCalculations': 'Total Calculations',
      'averageSessionTime': 'Average Session Time',
      'loadingStats': 'Loading statistics...',
      'loadingFailed': 'Failed to load statistics',
      
      // Admin Panel
      'adminDashboard': 'Admin Dashboard',
      'userManagement': 'User Management',
      'systemStats': 'System Statistics',
      'errorLogs': 'Error Logs',
      'settings': 'Settings',
      
      // Purchase System
      'purchaseManager': 'Purchase Manager',
      'subscriptionPlan': 'Subscription Plan',
      'monthlyPlan': 'Monthly Plan',
      'freePlan': 'Free Plan',
      'premiumPlan': 'Premium Plan',
      'purchaseError': 'Error occurred during purchase',
      'purchaseSuccess': 'Purchase completed successfully',
      'restorePurchase': 'Restore Purchase',
      'manageSubscription': 'Manage Subscription',
      
      // Apparatus names
      'floor': 'Floor Exercise',
      'pommelHorse': 'Pommel Horse',
      'stillRings': 'Still Rings',
      'vault': 'Vault',
      'parallelBars': 'Parallel Bars',
      'horizontalBar': 'Horizontal Bar',
      
      // Others
      'version': 'Version',
      'about': 'About',
      'privacyPolicy': 'Privacy Policy',
      'termsOfService': 'Terms of Service',
      'contact': 'Contact',
      'help': 'Help',
      'tutorial': 'Tutorial',
      'login': 'Login',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'theme': 'Theme',
    },
  };
  
  // 翻訳ヘルパー関数
  int _getTabIndex(AppMode mode) {
    switch (mode) {
      case AppMode.chat:
        return 0;
      case AppMode.dScore:
        return 1;
      case AppMode.allApparatus:
        return 2;
      case AppMode.analytics:
        return 3;
      case AppMode.admin:
        return 4;
      default:
        return 0;
    }
  }

  String _getText(String key) {
    // AI機能は常に英語表示（ダサくなるのを防ぐため）
    if (key == 'ruleBookChat') return 'Gymnastics AI Chat';
    if (key == 'dScoreCalculator') return 'D-Score Calculator';
    
    return _appTexts[_currentLang]![key] ?? _appTexts['English']![key] ?? key;
  }

  // AppBarタイトルを取得（モードと言語に応じて動的に変更）
  String _getAppBarTitle() {
    switch (_currentMode) {
      case AppMode.dScore:
        return 'D-Score Calculator'; // 常に英語表示
      case AppMode.allApparatus:
        return _currentLang == '日本語' ? '全種目一覧' : 'All Apparatus List';
      case AppMode.analytics:
        return _currentLang == '日本語' ? '演技構成分析' : 'Routine Analysis';
      case AppMode.admin:
        return _currentLang == '日本語' ? '管理者パネル' : 'Admin Panel';
      case AppMode.chat:
        return AppConfig.enableAIChat 
          ? 'Gymnastics AI Chat' 
          : _currentLang == '日本語' ? 'AIチャット (準備中)' : 'AI Chat (Coming Soon)';
      default:
        return _currentLang == '日本語' ? '体操アプリ' : 'Gymnastics App';
    }
  }

  // プラットフォーム別タブアイテム生成
  List<BottomNavigationBarItem> _buildTabItems() {
    final tabItems = PlatformUIConfig.getTabItems(isUserFree: _userSubscription.isFree);
    final navigationItems = <BottomNavigationBarItem>[];
    
    for (final tabInfo in tabItems) {
      navigationItems.add(
        BottomNavigationBarItem(
          icon: Stack(
            children: [
              Icon(tabInfo.icon),
              if (tabInfo.statusIcon != null)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Icon(
                    tabInfo.statusIcon!.icon,
                    size: tabInfo.statusIcon!.size,
                    color: tabInfo.statusIcon!.color,
                  ),
                ),
            ],
          ),
          label: tabInfo.label,
        ),
      );
    }
    
    // 管理者タブを条件付きで追加
    if (_isAdmin) {
      navigationItems.add(
        BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: '管理者',
        ),
      );
    }
    
    return navigationItems;
  }

  // プラットフォーム別タブタップハンドラー
  void _handleTabTap(int index) {
    HapticFeedback.lightImpact();
    
    // Web版でのタブ切り替え広告チェック
    if (PlatformConfig.isWeb && _userSubscription.shouldShowAds()) {
      if (WebAdManager().shouldShowTabSwitchAd()) {
        _showWebInterstitialAd('tab_switch');
      }
    }
    
    final tabItems = PlatformUIConfig.getTabItems(isUserFree: _userSubscription.isFree);
    
    AppMode targetMode;
    String featureName;
    
    if (index < tabItems.length) {
      final tabInfo = tabItems[index];
      targetMode = tabInfo.mode;
      featureName = tabInfo.featureName;
    } else {
      // 管理者タブ（条件付き表示）
      targetMode = AppMode.admin;
      featureName = _getText('adminPanel');
    }
    
    _safeSwitchToMode(targetMode, featureName: featureName);
  }

  // --- 認証関連の新しい状態 ---
  final _storage = const FlutterSecureStorage();
  bool _isAuthenticated = false;
  bool _isAuthLoading = true;
  String? _token;
  
  // iOS対応: Keychainエラー回避のためのシンプルストレージ
  bool _useSimpleStorage = true;
  
  // --- パフォーマンス最適化のためのキャッシュ ---
  final Map<String, List<Skill>> _skillDataCache = {};
  final Map<String, DScoreResult> _calculationCache = {};
  String? _lastCalculationKey;
  
  // --- 演技構成管理 ---
  final Map<String, Map<String, dynamic>> _savedRoutines = {};
  bool _isLoadingRoutines = false;
  
  // --- キャッシュ監視 ---
  Map<String, dynamic> _cacheStats = {};
  bool _isLoadingCacheStats = false;
  bool _showAdminPanel = false;
  
  // --- エラーハンドリング ---
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 1);
  
  // --- 分析機能 ---
  RoutineAnalysis? _currentAnalysis;
  bool _isAnalyzing = false;
  final TextEditingController _analyticsController = TextEditingController();
  final ScrollController _analyticsScrollController = ScrollController();

  // Dスコア計算用
  String? _selectedApparatus;
  final Map<String, Map<String, String>> _apparatusData = {
    "FX": {"ja": "床", "en": "Floor Exercise"},
    "PH": {"ja": "あん馬", "en": "Pommel Horse"},
    "SR": {"ja": "つり輪", "en": "Still Rings"},
    "VT": {"ja": "跳馬", "en": "Vault"},
    "PB": {"ja": "平行棒", "en": "Parallel Bars"},
    "HB": {"ja": "鉄棒", "en": "Horizontal Bar"},
  };
  List<Skill> _skillList = [];
  bool _isSkillLoading = false;
  List<Skill> _routine = []; // 演技構成(個別の技のリスト)
  List<int> _connectionGroups = []; // 連続技グループIDのリスト
  int _nextConnectionGroupId = 1; // 次の連続グループID
  DScoreResult? _dScoreResult; // 計算結果を保持
  
  // タブ間データ共有用
  Map<String, dynamic>? _lastSharedCalculationData; // 最後に計算したデータを全種目タブ用に保存
  RoutineAnalysis? _lastSharedAnalysisData; // 最後に生成した分析データを分析タブ用に保存
  Skill? _selectedSkill; // ドロップダウンで選択された技
  int? _selectedSkillIndex; // 選択された技のインデックス
  bool _isEditingSkill = false; // 技編集モードかどうか
  String _skillSearchQuery = ''; // 技検索クエリ
  final TextEditingController _skillSearchController = TextEditingController(); // 技検索用コントローラー
  int? _selectedGroupFilter; // グループフィルタ (1-8)
  String? _selectedDifficultyFilter; // 難度フィルタ (A-I)
  
  // 技選択リストのページネーション
  int _currentSkillPage = 0; // 現在のページ（0から開始）
  final int _skillsPerPage = 3; // 1ページあたりの技数
  
  // 全種目のデータ管理
  final Map<String, List<Skill>> _allRoutines = {
    "FX": [],
    "PH": [],
    "SR": [],
    "VT": [],
    "PB": [],
    "HB": [],
  };
  
  final Map<String, List<int>> _allConnectionGroups = {
    "FX": [],
    "PH": [],
    "SR": [],
    "VT": [],
    "PB": [],
    "HB": [],
  };
  
  final Map<String, int> _allNextConnectionGroupIds = {
    "FX": 1,
    "PH": 1,
    "SR": 1,
    "VT": 1,
    "PB": 1,
    "HB": 1,
  };
  
  final Map<String, DScoreResult?> _allDScoreResults = {
    "FX": null,
    "PH": null,
    "SR": null,
    "VT": null,
    "PB": null,
    "HB": null,
  };

  // === D-SCORE REWARDED AD METHODS ===
  
  /// D-Score計算用リワード広告ボタンを表示するかチェック
  Future<bool> _canShowDScoreRewardedAd() async {
    // プレミアムユーザーには表示しない
    if (_userSubscription.isPremium) {
      return false;
    }
    
    // D-Score計算が制限に達している場合のみ表示
    final canCalculate = await DScoreUsageTracker.canCalculateDScore(_userSubscription);
    return !canCalculate;
  }
  
  /// D-Score計算用リワード広告を表示
  void _showDScoreRewardedAd() async {
    bool success = await _adManager.showRewardedAd();
    
    if (success) {
      await DScoreUsageTracker.grantCalculationBonus();
      _showSuccessSnackBar('🎉 D-Score計算回数が+2回追加されました！');
      
      // UI更新のため画面をリフレッシュ
      if (mounted) {
        setState(() {});
      }
    } else {
      _showErrorDialog('エラー', '広告の読み込みに失敗しました。しばらく時間をおいて再度お試しください。');
    }
  }

  // === ERROR HANDLING METHODS ===
  
  /// Check if device has internet connectivity - 無効化済み
  Future<bool> _hasInternetConnection() async {
    return true; // チャット機能無効化のため常にtrueを返す
    final String healthUrl = '${Config.apiBaseUrl}/health';
    print('🔗 サーバー接続テスト開始: $healthUrl');
    print('🕐 テスト開始時刻: ${DateTime.now().toString().substring(0, 19)}');
    
    // DNS解決テスト（エラーハンドリング付き）
    try {
      await _performDnsCheck();
    } catch (e) {
      print('⚠️ DNS解決をスキップ: $e');
    }
    
    // 段階的タイムアウト設定（より短く）
    final timeouts = [5, 10, 15]; // 秒
    
    // 3回まで試行する
    for (int attempt = 1; attempt <= 3; attempt++) {
      final stopwatch = Stopwatch()..start();
      final timeoutDuration = Duration(seconds: timeouts[attempt - 1]);
      
      try {
        print('🔄 接続試行 $attempt/3 (タイムアウト: ${timeouts[attempt - 1]}秒)...');
        
        final response = await http.get(
          Uri.parse(healthUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'GymnasticsAI/1.3.0',
            'Accept': 'application/json',
          },
        ).timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException('接続タイムアウト: ${timeouts[attempt - 1]}秒');
          },
        );
        
        stopwatch.stop();
        final responseTime = stopwatch.elapsedMilliseconds;
        
        if (response.statusCode == 200) {
          print('✅ サーバー接続成功！ (試行 $attempt/3)');
          print('📊 レスポンス時間: ${responseTime}ms');
          print('📊 レスポンス: ${response.body}');
          print('🔒 HTTPS証明書検証: 成功');
          print('📶 ネットワーク品質: ${_evaluateNetworkQuality(responseTime)}');
          
          // チャットエンドポイントも軽量テスト（エラーハンドリング付き）
          try {
            await _testChatEndpoint();
          } catch (e) {
            print('⚠️ チャットエンドポイントテストをスキップ: $e');
          }
          
          return true;
        } else {
          print('⚠️ サーバー応答エラー: ${response.statusCode}');
          print('📊 レスポンス時間: ${responseTime}ms');
          print('📊 レスポンス内容: ${response.body}');
          
          // 4xxエラーの場合は認証問題の可能性
          if (response.statusCode >= 400 && response.statusCode < 500) {
            print('🔐 認証またはクライアントエラーの可能性があります');
          }
        }
      } catch (e) {
        stopwatch.stop();
        final responseTime = stopwatch.elapsedMilliseconds;
        
        print('❌ 接続試行 $attempt/3 失敗: $e');
        print('⏱️ 失敗までの時間: ${responseTime}ms');
        print('🔍 エラー詳細: ${e.runtimeType} - ${e.toString()}');
        
        // より詳細なエラータイプ分析
        final errorType = _analyzeConnectionError(e);
        print('🔍 エラータイプ: ${errorType['type']}');
        print('💡 推奨対策: ${errorType['suggestion']}');
        
        if (attempt < 3) {
          // 次の試行まで少し待機（指数的バックオフ + ジッター）
          int baseDelay = attempt * 3; // 3秒、6秒
          int jitter = math.Random().nextInt(2000); // 0-2秒のランダム
          int totalDelayMs = (baseDelay * 1000) + jitter;
          
          print('⏳ ${(totalDelayMs / 1000).toStringAsFixed(1)}秒後に再試行...');
          await Future.delayed(Duration(milliseconds: totalDelayMs));
        }
      }
    }
    
    print('💥 全ての接続試行が失敗しました');
    await _performNetworkDiagnostics();
    return false;
  }

  // ネットワーク品質評価
  String _evaluateNetworkQuality(int responseTimeMs) {
    if (responseTimeMs < 500) {
      return '優秀 (${responseTimeMs}ms)';
    } else if (responseTimeMs < 1000) {
      return '良好 (${responseTimeMs}ms)';
    } else if (responseTimeMs < 2000) {
      return '普通 (${responseTimeMs}ms)';
    } else if (responseTimeMs < 5000) {
      return '低速 (${responseTimeMs}ms)';
    } else {
      return '非常に低速 (${responseTimeMs}ms)';
    }
  }

  // 接続エラーの詳細分析
  Map<String, String> _analyzeConnectionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('socketexception')) {
      return {
        'type': 'ネットワーク接続エラー',
        'suggestion': 'Wi-Fi/モバイルデータ接続を確認してください'
      };
    } else if (errorStr.contains('timeoutexception')) {
      return {
        'type': 'タイムアウトエラー',
        'suggestion': 'ネットワーク速度が低下しています。時間をおいて再試行してください'
      };
    } else if (errorStr.contains('handshakeexception')) {
      return {
        'type': 'SSL/TLS証明書エラー',
        'suggestion': 'HTTPS接続に問題があります。端末の日時設定を確認してください'
      };
    } else if (errorStr.contains('clientexception')) {
      return {
        'type': 'クライアント設定エラー',
        'suggestion': 'アプリの設定に問題があります。アプリを再起動してください'
      };
    } else if (errorStr.contains('formatexception')) {
      return {
        'type': 'データ形式エラー',
        'suggestion': 'サーバーからの応答が不正です。サーバー側の問題の可能性があります'
      };
    } else {
      return {
        'type': '不明なエラー',
        'suggestion': '予期しない問題が発生しました。アプリを再起動してください'
      };
    }
  }

  // チャットエンドポイントの軽量テスト
  Future<void> _testChatEndpoint() async {
    try {
      print('🧪 チャットエンドポイント軽量テスト...');
      
      final chatUrl = '${Config.apiBaseUrl}/chat/message';
      final response = await http.head(
        Uri.parse(chatUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'GymnasticsAI/1.3.0',
        },
      ).timeout(Duration(seconds: 10));
      
      print('🔍 チャットエンドポイント応答: ${response.statusCode}');
      
      if (response.statusCode == 405) {
        print('✅ エンドポイント存在確認 (Method Not Allowed is expected)');
      } else if (response.statusCode == 401) {
        print('🔐 認証が必要です (予期される状態)');
      } else {
        print('⚠️ 予期しない応答: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ チャットエンドポイントテスト失敗: $e');
    }
  }
  
  Future<void> _performDnsCheck() async {
    try {
      print('🔍 DNS解決テスト開始...');
      final uri = Uri.parse(Config.apiBaseUrl);
      final host = uri.host;
      
      // DNS解決テスト（簡易版）
      final stopwatch = Stopwatch()..start();
      await InternetAddress.lookup(host);
      stopwatch.stop();
      
      print('✅ DNS解決成功: $host (${stopwatch.elapsedMilliseconds}ms)');
    } catch (e) {
      print('❌ DNS解決失敗: $e');
    }
  }
  
  Future<void> _performNetworkDiagnostics() async {
    print('\n🔧 ネットワーク診断を実行中...');
    
    // 基本情報
    print('📱 サーバーURL: ${Config.apiBaseUrl}');
    print('🌐 現在の環境: ${AppConfig.environment}');
    
    // 単純なHTTP接続テスト（google.com）
    try {
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'User-Agent': 'GymnasticsAI'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ インターネット接続: 正常');
      } else {
        print('⚠️ インターネット接続: 異常 (${response.statusCode})');
      }
    } catch (e) {
      print('❌ インターネット接続: 失敗 ($e)');
    }
    
    print('🔧 診断完了\n');
  }

  /// Retry a request with exponential backoff
  Future<T> _retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = _maxRetries,
    Duration initialDelay = _retryDelay,
    double backoffMultiplier = 2.0,
  }) async {
    Exception? lastException;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Don't retry on authentication errors
        if (e is AuthenticationException) {
          throw e;
        }
        
        // Don't retry on the last attempt
        if (attempt == maxRetries - 1) {
          break;
        }
        
        // Calculate delay with exponential backoff
        final delay = Duration(
          milliseconds: (initialDelay.inMilliseconds * math.pow(backoffMultiplier, attempt)).round(),
        );
        
        await Future.delayed(delay);
      }
    }
    
    throw lastException ?? Exception('Request failed after $maxRetries attempts');
  }

  /// Enhanced HTTP request with comprehensive error handling
  Future<http.Response> _makeApiRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Check internet connectivity
    if (!await _hasInternetConnection()) {
      throw NetworkException('インターネット接続を確認してください');
    }

    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    final headers = await _getAuthHeaders();
    
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    // return await _retryRequest<http.Response>(() async {
    try {
      http.Response response;
      
      try {
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(url, headers: headers).timeout(timeout);
            break;
          case 'POST':
            response = await http.post(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(timeout);
            break;
          case 'PUT':
            response = await http.put(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            ).timeout(timeout);
            break;
          case 'DELETE':
            response = await http.delete(url, headers: headers).timeout(timeout);
            break;
          default:
            throw DataException('サポートされていないHTTPメソッド: $method');
        }
      } on TimeoutException {
        throw NetworkException('リクエストがタイムアウトしました');
      } on SocketException {
        throw NetworkException('ネットワークエラーが発生しました');
      } on HttpException catch (e) {
        throw NetworkException('HTTPエラー: ${e.message}');
      }

      // Handle HTTP status codes
      _handleHttpStatus(response);
      
      return response;
    } catch (e, stackTrace) {
      print('API request error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // デバイスベース用APIリクエスト（認証不要）
  Future<http.Response> _makeDeviceApiRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}$endpoint');
    final headers = await _getDeviceHeaders();
    
    print('🌐 API Request Details:');
    print('📍 URL: $url');
    print('🔧 Method: $method');
    print('📋 Headers: ${headers.keys.map((k) => k == 'Authorization' ? '$k: Bearer ***' : '$k: ${headers[k]}').join(', ')}');
    if (body != null) {
      print('📦 Body: ${json.encode(body)}');
    }
    
    try {
      http.Response response;
      
      if (method == 'GET') {
        final queryParams = body?.map((k, v) => MapEntry(k, v.toString()));
        final urlWithParams = queryParams != null ? url.replace(queryParameters: queryParams) : url;
        response = await http.get(urlWithParams, headers: headers)
            .timeout(const Duration(seconds: 10));
      } else {
        response = await http.post(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ).timeout(const Duration(seconds: 10));
      }
      
      return response;
    } on TimeoutException {
      throw NetworkException('リクエストがタイムアウトしました');
    } on SocketException {
      throw NetworkException('ネットワークエラーが発生しました');  
    } on HttpException catch (e) {
      throw NetworkException('HTTPエラー: ${e.message}');
    } catch (error) {
      throw NetworkException('予期しないエラーが発生しました: $error');
    }
  }

  /// Handle HTTP status codes and throw appropriate exceptions
  void _handleHttpStatus(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
      case 204:
        // Success - no action needed
        break;
      case 400:
        throw DataException('リクエストが無効です');
      case 401:
        _handleUnauthorized();
        throw AuthenticationException('認証が必要です');
      case 403:
        throw AuthenticationException('このリソースへのアクセス権限がありません');
      case 404:
        throw DataException('要求されたリソースが見つかりません');
      case 409:
        throw DataException('データの競合が発生しました');
      case 422:
        throw DataException('入力データが無効です');
      case 429:
        throw NetworkException('リクエストが多すぎます。しばらく待ってから再試行してください');
      case 500:
        throw NetworkException('サーバーエラーが発生しました');
      case 502:
        throw NetworkException('不正なゲートウェイです');
      case 503:
        throw NetworkException('サービスが利用できません');
      case 504:
        throw NetworkException('ゲートウェイタイムアウトです');
      default:
        throw NetworkException('予期しないエラーが発生しました (${response.statusCode})');
    }
  }

  /// Handle authentication errors
  void _handleUnauthorized() {
    print('認証エラー：デバイスベース認証に移行');
    
    // Clear stored authentication data
    _clearStoredToken();
    
    setState(() {
      _isAuthenticated = false;
      _token = null;
    });
    
    // デバイスベースに移行済みなので、認証画面は不要
    _showMessage('認証が無効になりました。アプリは継続して利用できます。');
  }

  /// Show error dialog with retry option
  Future<void> _showErrorDialog(
    String title,
    String message, {
    VoidCallback? onRetry,
    String? retryText,
    String? cancelText,
  }) async {
    if (!mounted) return;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText ?? _getText('cancel')),
            ),
            if (onRetry != null)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                child: Text(retryText ?? _getText('retry')),
              ),
          ],
        );
      },
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message, {Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        duration: duration,
        action: SnackBarAction(
          label: _getText('close'),
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message, {Duration duration = const Duration(seconds: 3)}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        duration: duration,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // アプリライフサイクル監視を開始
    WidgetsBinding.instance.addObserver(this);
    
    // デバッグ時はプレミアム状態をクリア
    if (kDebugMode) {
      _clearDeviceSubscription();
    }
    _initializeApp(); // アプリの初期化を開始
    
    // Web版広告管理の初期化
    if (PlatformConfig.isWeb) {
      WebAdManager().loadFromStorage();
    }
    
    // 定期的なサブスクリプション状態チェックを開始
    _startPeriodicSubscriptionCheck();
  }

  // アプリの初期化を非同期で実行（認証不要版）
  void _initializeApp() async {
    try {
      print('アプリ初期化開始（認証不要モード）');
      
      // Critical startup path - show UI as quickly as possible
      // Show UI immediately without waiting for heavy operations
      setState(() {
        _isAuthLoading = false;
      });
      
      // Move essential operations to background for faster startup
      _initializeCriticalDataInBackground();
      
      // Background initialization - non-blocking
      _initializeAppInBackground();
      
      // Failsafe: Force complete after 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (mounted && !_isBackgroundInitComplete) {
          print('バックグラウンド初期化タイムアウト - 強制完了');
          setState(() {
            _isBackgroundInitComplete = true;
          });
        }
      });
      
      print('初期UI表示完了 - バックグラウンド初期化継続中');
    } catch (e) {
      print('アプリ初期化エラー: $e');
      // Still show UI even if there's an error
      setState(() {
        _isAuthLoading = false;
      });
    }
  }
  
  // 重要データの高速バックグラウンド初期化
  void _initializeCriticalDataInBackground() async {
    try {
      // デバイス認証トークンを高速で生成/取得
      await _generateDeviceAuthTokenFast();
      
      // サブスクリプション状態を高速チェック
      await _checkDeviceSubscriptionFast();
      
      print('重要データ初期化完了');
    } catch (e) {
      print('重要データ初期化エラー: $e');
      // エラーでも継続
    }
  }
  
  // 高速デバイス認証トークン生成（UI表示を優先）
  Future<void> _generateDeviceAuthTokenFast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 既存のトークンを優先チェック（最も高速）
      String? storedToken = prefs.getString('device_auth_token');
      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
        return; // 早期リターンで高速化
      }
      
      // デバイスIDを高速取得・生成
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        // バックグラウンドで保存（ノンブロッキング）
        prefs.setString('device_id', deviceId).catchError((e) {
          print('デバイスID保存エラー: $e');
        });
        print('📱 新しいデバイスIDを生成: $deviceId');
      }
      
      // 簡易トークン生成（高速化）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final simpleToken = '${deviceId}_$timestamp';
      _token = simpleToken;
      
      // バックグラウンドで保存（ノンブロッキング）
      prefs.setString('device_auth_token', simpleToken).catchError((e) {
        print('トークン保存エラー: $e');
      });
      
    } catch (e) {
      print('❌ デバイス認証トークン高速生成エラー: $e');
      // フォールバック: 一時的なトークンを生成
      _token = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
  
  // 高速サブスクリプション状態チェック
  Future<void> _checkDeviceSubscriptionFast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 基本的な状態のみを高速チェック
      final tierString = prefs.getString('user_subscription_tier');
      final isActive = prefs.getBool('user_subscription_active') ?? false;
      
      if (tierString != null && isActive) {
        final tier = tierString == 'premium' ? UserTier.premium : UserTier.free;
        _userSubscription = UserSubscription(
          tier: tier,
          subscriptionEnd: DateTime.now().add(Duration(days: 30)), // 仮の期限
        );
      } else {
        _userSubscription = UserSubscription(tier: UserTier.free);
      }
      
    } catch (e) {
      print('❌ サブスクリプション状態高速チェックエラー: $e');
      // フォールバック: 無料版として扱う
      _userSubscription = UserSubscription(tier: UserTier.free);
    }
  }
  
  // Background initialization that doesn't block UI
  void _initializeAppInBackground() async {
    try {
      print('バックグラウンド初期化開始');
      
      // All these operations run in background with individual error handling
      final futures = <Future>[
        // Server connection check (non-blocking)
        _checkServerConnection().catchError((e) {
          print('サーバー接続チェックエラー: $e');
          return null;
        }),
        // Load saved routines (lightweight)
        _loadSavedRoutines().catchError((e) {
          print('保存データ読み込みエラー: $e');
          return null;
        }),
        // Purchase and ad managers (heavy)
        _initializePurchaseManager().catchError((e) {
          print('購入マネージャー初期化エラー: $e');
          return null;
        }),
        _initializeAdManager().catchError((e) {
          print('広告マネージャー初期化エラー: $e');
          return null;
        }),
      ];
      
      // Skills data loading deferred until needed
      try {
        _initializeSkillsDataLazily();
      } catch (e) {
        print('技データ初期化エラー: $e');
      }
      
      // Wait for all background tasks
      await Future.wait(futures, eagerError: false);
      
      print('バックグラウンド初期化完了');
    } catch (e) {
      print('バックグラウンド初期化で予期しないエラー: $e');
    } finally {
      // Always mark as complete even if there were errors
      if (mounted) {
        setState(() {
          _isBackgroundInitComplete = true;
        });
        print('バックグラウンド初期化ステータス: 完了に設定');
      }
    }
  }
  
  // Lazy skills data initialization
  void _initializeSkillsDataLazily() async {
    // Only load skills data when actually needed
    // This prevents blocking the UI with heavy CSV parsing
    print('スキルデータの遅延初期化をスケジュール');
  }
  
  // サーバー接続を非同期でチェック (完全にノンブロッキング)
  Future<void> _checkServerConnection() async {
    try {
      print('🌐 バックグラウンドでサーバー接続確認中...');
      
      // Timeout to prevent long delays
      final isConnected = await _hasInternetConnection()
          .timeout(Duration(seconds: 5), onTimeout: () => false);
      
      if (mounted) {
        setState(() {
          _isServerOnline = isConnected;
        });
        
        if (isConnected) {
          print('✅ サーバー接続確認完了: オンライン');
          // チャットAPI機能テストを実行 (さらにバックグラウンドで)
          _testChatAPIFunctionality();
        } else {
          print('⚠️ サーバー接続確認完了: オフライン');
          // Show warning only after a delay to not interrupt startup
          Future.delayed(Duration(seconds: 2), () {
            if (mounted && !_isServerOnline) {
              _showConnectionWarning();
            }
          });
        }
      }
    } catch (e) {
      print('❌ サーバー接続確認エラー: $e');
      if (mounted) {
        setState(() {
          _isServerOnline = false;
        });
      }
    }
  }
  
  // チャットAPI機能をテスト (低優先度バックグラウンド処理)
  void _testChatAPIFunctionality() async {
    try {
      print('🧪 チャットAPI機能テスト開始...');
      
      // Add timeout and make it truly non-blocking
      final response = await _makeDeviceApiRequest(
        '/chat/message',
        method: 'POST',
        body: {'message': 'test'},
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('API test timeout');
      });
      
      if (response.statusCode == 200) {
        print('✅ チャットAPI機能: 正常動作');
        // 真のオンライン状態
      } else {
        print('⚠️ チャットAPI機能: メンテナンス中 (${response.statusCode})');
        // 接続はできるがAPI機能は利用不可
        if (mounted) {
          setState(() {
            _isServerOnline = false; // UI表示をオフラインに変更
          });
        }
      }
    } catch (e) {
      print('❌ チャットAPI機能テストエラー: $e');
      if (mounted) {
        setState(() {
          _isServerOnline = false;
        });
      }
    }
  }

  // 接続警告を表示
  void _showConnectionWarning() {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'サーバー接続がオフラインです。一部機能が制限される可能性があります。',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade800,
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: '再試行',
          textColor: Colors.white,
          onPressed: () => _checkServerConnection(),
        ),
      ),
    );
  }

  // デバイスベースの課金状態をチェック
  Future<void> _checkDeviceSubscription() async {
    try {
      print('デバイス課金状態チェック開始');
      
      // SharedPreferencesから課金状態を確認
      final prefs = await SharedPreferences.getInstance();
      final hasPremium = prefs.getBool('device_has_premium') ?? false;
      final subscriptionEnd = prefs.getString('premium_subscription_end');
      
      DateTime? endDate;
      if (subscriptionEnd != null) {
        try {
          endDate = DateTime.parse(subscriptionEnd);
        } catch (e) {
          print('課金終了日の解析エラー: $e');
        }
      }
      
      // 課金状態を設定
      if (hasPremium && endDate != null && endDate.isAfter(DateTime.now())) {
        // プレミアム会員
        _userSubscription = UserSubscription(
          tier: UserTier.premium,
          subscriptionStart: DateTime.now().subtract(Duration(days: 30)),
          subscriptionEnd: endDate,
        );
        print('デバイス課金状態: プレミアム（期限: ${endDate.toString()}）');
      } else {
        // 無料プラン
        _userSubscription = UserSubscription(
          tier: UserTier.free,
          subscriptionStart: DateTime.now(),
          subscriptionEnd: DateTime.now().add(Duration(days: 1)),
        );
        print('デバイス課金状態: 無料プラン');
      }
      
    } catch (e) {
      print('デバイス課金状態チェックエラー: $e');
      // エラー時は無料プランにフォールバック
      _userSubscription = UserSubscription(
        tier: UserTier.free,
        subscriptionStart: DateTime.now(),
        subscriptionEnd: DateTime.now().add(Duration(days: 1)),
      );
    }
  }

  // デバイスに課金状態を保存
  Future<void> _saveDeviceSubscription({
    required bool isPremium,
    required DateTime subscriptionEnd,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_has_premium', isPremium);
      await prefs.setString('premium_subscription_end', subscriptionEnd.toIso8601String());
      
      print('デバイス課金状態を保存: premium=$isPremium, end=$subscriptionEnd');
      
      // UI更新のため再チェック
      await _checkDeviceSubscription();
      setState(() {});
      
    } catch (e) {
      print('デバイス課金状態保存エラー: $e');
    }
  }

  // デバイスの課金状態をクリア（開発・テスト用）
  Future<void> _clearDeviceSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_has_premium');
      await prefs.remove('premium_subscription_end');
      
      // 無料プランに戻す
      _userSubscription = UserSubscription(tier: UserTier.free);
      
      print('デバイス課金状態をクリア: 無料プランに戻しました');
      setState(() {});
      
    } catch (e) {
      print('デバイス課金状態クリアエラー: $e');
    }
  }

  
  
  // スキルデータを更新
  Future<void> _refreshSkillsData() async {
    try {
      print('スキルデータリフレッシュ開始');
      
      // AIチャット用のスキルデータベースを非同期で読み込み
      GymnasticsKnowledgeBase.resetSkillsDatabase();
      // Don't await - let it load in background
      GymnasticsKnowledgeBase.loadSkillsDatabase().catchError((e) {
        print('Error loading knowledge base: $e');
      });
      
      // Clear cache but don't reload skills until needed
      _skillDataCache.clear();
      
      print('Skills data refresh initiated (background loading)');
    } catch (e) {
      print('Error in _refreshSkillsData: $e');
    }
  }
  
  // Enhanced lazy skills loading
  Future<void> _ensureSkillsLoaded(String apparatus) async {
    final lang = _currentLang == '日本語' ? 'ja' : 'en';
    final cacheKey = '${apparatus}_$lang';
    
    // Return immediately if already cached
    if (_skillDataCache.containsKey(cacheKey)) {
      setState(() {
        _skillList = _skillDataCache[cacheKey]!;
        _isSkillLoading = false;
      });
      return;
    }
    
    // Load skills for this apparatus
    await _loadSkills(apparatus);
  }
  
  // 課金システム初期化
  Future<void> _initializePurchaseManager() async {
    // Web版では課金システムを無効化
    if (kIsWeb) {
      print('PurchaseManager skipped for web platform');
      return;
    }
    
    _purchaseManager = PurchaseManager();
    
    // コールバック関数を設定
    _purchaseManager!.onPurchaseSuccess = () {
      _showPurchaseSuccessDialog();
      _refreshDeviceSubscriptionInfo();
    };
    
    // エラーコールバックを追加
    _purchaseManager!.onPurchaseError = (String error) {
      setState(() {
        _isLoadingSubscription = false;
      });
      _showMessage('購入エラー: $error');
    };
    
    // 復元コールバックを追加
    _purchaseManager!.onPurchaseRestore = (String message) {
      setState(() {
        _isLoadingSubscription = false;
      });
      _showMessage(message);
    };
    
    // サブスクリプション状態変更コールバックを追加
    _purchaseManager!.onSubscriptionStateChanged = (SubscriptionState oldState, SubscriptionState newState) {
      print('Subscription state changed: $oldState -> $newState');
      _refreshDeviceSubscriptionInfo();
    };
    
    // サブスクリプション期限切れコールバックを追加
    _purchaseManager!.onSubscriptionExpired = () {
      _showMessage('サブスクリプションが期限切れになりました');
      _refreshDeviceSubscriptionInfo();
    };
    
    try {
      await _purchaseManager!.initialize();
      setState(() {
        _isPurchaseManagerInitialized = true;
      });
      print('PurchaseManager initialized successfully');
    } catch (e) {
      print('Failed to initialize PurchaseManager: $e');
      _showMessage('課金システムの初期化に失敗しました。アプリを再起動してください。');
    }
  }
  
  // 定期的なサブスクリプション状態チェックを開始
  void _startPeriodicSubscriptionCheck() {
    // Web版では課金システムを使用しないためスキップ
    if (kIsWeb) return;
    
    // 10分ごとにサブスクリプション状態をチェック
    _subscriptionCheckTimer = Timer.periodic(Duration(minutes: 10), (timer) {
      if (_isPurchaseManagerInitialized && _purchaseManager != null) {
        _purchaseManager!.checkSubscriptionStatus();
      }
    });
  }
  
  // アプリライフサイクル状態変更時の処理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // アプリがフォアグラウンドに戻った時、サブスクリプション状態をチェック
        print('App resumed - checking subscription status');
        if (!kIsWeb && _isPurchaseManagerInitialized && _purchaseManager != null) {
          _purchaseManager!.checkSubscriptionStatus();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // アプリがバックグラウンドに移行時は特に何もしない
        break;
    }
  }
  
  // 広告システム初期化
  Future<void> _initializeAdManager() async {
    if (_userSubscription.shouldShowAds()) {
      _adManager = AdManager();
      try {
        await _adManager.initialize();
        setState(() {
          _isAdManagerInitialized = true;
        });
        print('AdManager initialized successfully');
      } catch (e) {
        print('Failed to initialize AdManager: $e');
      }
    }
  }
  
  Future<void> _tryAutoLogin() async {
    try {
      String? token;
      
      // iOS対応: Keychainエラー回避
      try {
        token = await _storage.read(key: 'auth_token');
      } catch (e) {
        print('Keychain access failed, using simple storage: $e');
        _useSimpleStorage = true;
        // SharedPreferencesからトークンを読み込み
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
      }
      
      if (token != null) {
        // Store token temporarily for validation
        setState(() {
          _token = token;
        });
        
        // Validate token with server
        final response = await _makeApiRequest('/users/me');
        
        if (response.statusCode == 200) {
          // Parse user data and subscription information
          final userData = json.decode(response.body);
          _loadUserSubscription(userData);
          
          setState(() {
            _isAuthenticated = true;
          });
          _resetChat();
        } else {
          await _clearStoredToken();
          setState(() {
            _token = null;
          });
        }
      }
    } on AuthenticationException catch (e) {
      // Token is invalid, clear it
      await _clearStoredToken();
      setState(() {
        _token = null;
      });
    } catch (e) {
      // Other errors during auto-login are not critical
      print('Auto-login failed: $e');
    } finally {
      setState(() {
        _isAuthLoading = false;
      });
    }
  }

  void _loadUserSubscription(Map<String, dynamic> userData) {
    final subscriptionTier = userData['subscription_tier'] ?? 'free';
    final subscriptionStartStr = userData['subscription_start'];
    final subscriptionEndStr = userData['subscription_end'];
    
    UserTier tier = subscriptionTier == 'premium' ? UserTier.premium : UserTier.free;
    DateTime? start;
    DateTime? end;
    
    if (subscriptionStartStr != null) {
      try {
        start = DateTime.parse(subscriptionStartStr);
      } catch (e) {
        print('Failed to parse subscription start date: $e');
      }
    }
    
    if (subscriptionEndStr != null) {
      try {
        end = DateTime.parse(subscriptionEndStr);
      } catch (e) {
        print('Failed to parse subscription end date: $e');
      }
    }
    
    // 管理者権限チェック
    final userRole = userData['role'] ?? 'free';
    bool isAdmin = userRole == 'admin';
    
    setState(() {
      _userSubscription = UserSubscription(
        tier: tier,
        subscriptionStart: start,
        subscriptionEnd: end,
      );
      _isAdmin = isAdmin;
    });
    
    print('User subscription loaded: tier=${tier.name}, active=${_userSubscription.isActive}, admin=$isAdmin');
  }

  Future<void> _loadUserInformation() async {
    try {
      final response = await _makeApiRequest('/users/me');
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _loadUserSubscription(userData);
      }
    } catch (e) {
      print('Failed to load user information: $e');
      // Set default free subscription if loading fails
      setState(() {
        _userSubscription = UserSubscription(tier: UserTier.free);
      });
    }
  }

  Future<void> _refreshUserSubscriptionInfo() async {
    try {
      final response = await _makeApiRequest('/users/me');
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _loadUserSubscription(userData);
        print('User subscription info refreshed successfully');
      } else {
        print('Failed to refresh user subscription info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error refreshing user subscription info: $e');
    }
  }

  // デバイスベースの課金状態を更新（課金成功時のコールバック）
  Future<void> _refreshDeviceSubscriptionInfo() async {
    try {
      print('デバイス課金状態更新開始');
      
      // 課金が成功した場合、デバイスにプレミアム状態を保存
      final subscriptionEnd = DateTime.now().add(Duration(days: 365)); // 1年間のサブスクリプション
      
      await _saveDeviceSubscription(
        isPremium: true,
        subscriptionEnd: subscriptionEnd,
      );
      
      print('デバイス課金状態更新完了: premium=true, end=$subscriptionEnd');
    } catch (e) {
      print('デバイス課金状態更新エラー: $e');
    }
  }

  Future<void> _clearStoredToken() async {
    try {
      if (!_useSimpleStorage) {
        await _storage.delete(key: 'auth_token');
      } else {
        // SharedPreferencesからトークンを削除
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
      }
    } catch (e) {
      print('Failed to clear stored token: $e');
    }
  }

  Future<void> _loadAdminData() async {
    if (!_isAdmin) return;
    
    setState(() {
      _isLoadingAdminData = true;
    });
    
    try {
      // 分析データ取得
      final analyticsResponse = await _makeApiRequest('/admin/analytics');
      if (analyticsResponse.statusCode == 200) {
        _adminAnalytics = json.decode(analyticsResponse.body);
      }
      
      // ユーザー一覧取得
      final usersResponse = await _makeApiRequest('/admin/users');
      if (usersResponse.statusCode == 200) {
        final usersData = json.decode(usersResponse.body);
        _adminUsers = usersData['users'];
      }
      
      setState(() {});
    } catch (e) {
      print('Failed to load admin data: $e');
    } finally {
      setState(() {
        _isLoadingAdminData = false;
      });
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    if (_token == null) return {};
    return {
      'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
    };
  }
  
  // デバイスベースシステム用のヘッダー取得（認証付き）
  Future<Map<String, String>> _getDeviceHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'unknown_device';
    
    final headers = {
      'Content-Type': 'application/json',
      'X-Device-ID': deviceId,
      'X-App-Version': '1.3.0',
    };
    
    // 認証トークンがある場合は追加
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      print('🔐 認証ヘッダー追加: Bearer token included');
    } else {
      print('⚠️ 認証トークンが設定されていません');
    }
    
    return headers;
  }

  // デバイスベースの認証トークン生成
  Future<void> _generateDeviceAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // デバイスIDを確認・生成
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        // UUIDを使ってユニークなデバイスIDを生成
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
        print('📱 新しいデバイスIDを生成: $deviceId');
      } else {
        print('📱 既存のデバイスIDを使用: $deviceId');
      }
      
      // 既存のトークンを確認
      String? storedToken = prefs.getString('device_auth_token');
      
      if (storedToken != null && storedToken.isNotEmpty) {
        _token = storedToken;
        print('🔐 既存の認証トークンを使用: ${_token!.substring(0, 8)}...');
        return;
      }
      
      // 新しいデバイスベース認証トークンを生成
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final random = math.Random().nextInt(999999).toString().padLeft(6, '0');
      
      // プロダクション環境用認証トークン生成
      // アプリケーション固有のトークン形式を使用
      final appSecret = 'gymnastics_ai_mobile_app_2024';
      final tokenPayload = '${deviceId}_${timestamp}_$appSecret';
      final deviceToken = '${tokenPayload.hashCode.abs()}';
      
      // トークンを保存
      await prefs.setString('device_auth_token', deviceToken);
      _token = deviceToken;
      
      print('🔐 新しいデバイス認証トークンを生成: ${_token!.substring(0, 20)}...');
      print('📱 デバイスID: $deviceId');
      
    } catch (e) {
      print('❌ デバイス認証トークン生成エラー: $e');
      // フォールバックとしてデバイスIDをトークンとして使用
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
        print('📱 フォールバック時にデバイスIDを生成: $deviceId');
      }
      _token = 'fallback_$deviceId';
    }
  }

  void _submitAuthForm(
    String username,
    String password,
    String? email,
    String? fullName,
    bool isLogin,
  ) async {
    print('認証開始: username=$username, isLogin=$isLogin');
    setState(() {
      _isLoading = true;
    });

    try {
      // 🚀 強制オンラインモー��設定 - オフライン不可
      const bool useOnlineAuth = true; // 定数として固定
      
      // Check internet connectivity first (より寛容な接続チェック)
      final hasConnection = await _hasInternetConnection();
      print('🔍 Server connection test result: $hasConnection');
      
      if (!hasConnection) {
        // 接続テストに失敗した場合でも、一度だけAPIリクエストを試行
        print('⚠️ 接続テスト失敗、APIリクエストで再確認します...');
        
        try {
          // 実際のAPIエンドポイントで軽量テスト
          final response = await http.get(
            Uri.parse('${Config.apiBaseUrl}/health'),
            headers: {'User-Agent': 'GymnasticsAI/1.3.0'},
          ).timeout(Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            print('✅ APIエンドポイント直接確認で接続成功');
            // 接続成功として処理続行
          } else {
            throw Exception('API endpoint returned ${response.statusCode}');
          }
        } catch (e) {
          print('❌ API直接確認も失敗: $e');
          setState(() {
            _isLoading = false;
          });
          _showConnectionErrorDialog();
          return;
        }
      } else {
        print('✅ サーバー接続成功、オンラインモードを使用');
      }
      

      http.Response response;
      if (isLogin) {
        final url = Uri.parse('${AppConfig.apiBaseUrl}/token');
        print('ログインURL: $url');
        print('送信データ: username=$username');
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': username, 'password': password},
        ).timeout(const Duration(seconds: 30));
      } else {
        final url = Uri.parse('${AppConfig.apiBaseUrl}/signup');
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': username,
            'password': password,
            'email': email,
            'full_name': fullName,
          }),
        ).timeout(const Duration(seconds: 30));
      }

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (isLogin) {
          final token = responseData['access_token'];
          
          // iOS対応: Keychainエラー回避
          try {
            if (!_useSimpleStorage) {
              await _storage.write(key: 'auth_token', value: token);
            } else {
              // SharedPreferencesにトークンを保存
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', token);
            }
          } catch (e) {
            print('Keychain write failed, using simple storage: $e');
            _useSimpleStorage = true;
            // フォールバック: SharedPreferencesにトークンを保存
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', token);
            } catch (fallbackError) {
              print('SharedPreferences write also failed: $fallbackError');
            }
          }
          
          setState(() {
            _token = token;
          });
          
          // Load user information after successful login
          await _loadUserInformation();
          
          setState(() {
            _isAuthenticated = true;
          });
          _resetChat();
          _showSuccessSnackBar('ログインに成功しました');
        } else {
          // サインアップ成功後、自動でログインさせる
          _showSuccessSnackBar('アカウントが作成されました');
          _submitAuthForm(username, password, null, null, true);
        }
      } else {
        final errorMessage = responseData['detail'] ?? 'エラーが発生しました';
        _showErrorDialog(
          isLogin ? 'ログインエラー' : 'サインアップエラー',
          errorMessage,
          onRetry: () => _submitAuthForm(username, password, email, fullName, isLogin),
        );
      }
    } on TimeoutException {
      _showErrorDialog(
        'タイムアウト',
        'リクエストがタイムアウトしました',
        onRetry: () => _submitAuthForm(username, password, email, fullName, isLogin),
      );
    } on SocketException {
      _showErrorDialog(
        'ネットワークエラー',
        'ネットワークエラーが発生しました',
        onRetry: () => _submitAuthForm(username, password, email, fullName, isLogin),
      );
    } catch (error) {
      print('Auth error: $error');
      _showErrorDialog(
        'エラー',
        '認証に失敗しました。エラー: $error',
        onRetry: () => _submitAuthForm(username, password, email, fullName, isLogin),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



  // フィードバック・バグ報告機能
  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'フィードバック・バグ報告',
            style: TextStyle(color: Colors.blue[300]),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.feedback,
                color: Colors.blue[300],
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'アプリの改善要望やバグ報告は\nInstagram DMにお送りください',
                style: TextStyle(color: Colors.grey[300]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'お気軽にご連絡ください！',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(_getText('cancel'), style: TextStyle(color: Colors.grey[400])),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
              ),
              child: Text('Instagram DMで連絡'),
              onPressed: () {
                Navigator.of(context).pop();
                _openInstagramDM();
              },
            ),
          ],
        );
      },
    );
  }

  // Instagram DMを開く
  Future<void> _openInstagramDM() async {
    final String instagramUsername = 'daito_iwasaki'; // 実際のInstagramユーザー名
    final String instagramUrl = 'https://instagram.com/direct/t/$instagramUsername';
    
    try {
      final Uri url = Uri.parse(instagramUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Instagram アプリが利用できない場合はWebブラウザで開く
        final Uri webUrl = Uri.parse('https://instagram.com/$instagramUsername');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          _showMessage(_getText('instagramError'));
        }
      }
    } catch (e) {
      _showMessage('${_getText('instagramError')}: $e');
    }
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showMessage(_currentLang == '日本語' 
          ? 'URLを開けませんでした。ブラウザを確認してください。'
          : 'Could not launch URL. Please check your browser.');
      }
    } catch (e) {
      _showMessage(_currentLang == '日本語' 
        ? 'URLを開く際にエラーが発生しました: $e'
        : 'Error launching URL: $e');
    }
  }

  Future<void> _launchAppStore() async {
    // App Store（iOS）とGoogle Play Store（Android））のリンク
    const iosAppUrl = 'https://apps.apple.com/app/id1234567890'; // 実際のApp Store URLに変更
    const androidAppUrl = 'https://play.google.com/store/apps/details?id=com.example.app'; // 実際のGoogle Play URLに変更
    
    try {
      // iOS用App Store URLを優先して試行
      final Uri iosUrl = Uri.parse(iosAppUrl);
      if (await canLaunchUrl(iosUrl)) {
        await launchUrl(iosUrl, mode: LaunchMode.externalApplication);
        return;
      }
      
      // Android用Google Play URLを試行
      final Uri androidUrl = Uri.parse(androidAppUrl);
      if (await canLaunchUrl(androidUrl)) {
        await launchUrl(androidUrl, mode: LaunchMode.externalApplication);
        return;
      }
      
      // 両方とも開けない場合
      _showMessage('アプリストアを開けませんでした。直接App StoreまたはGoogle Play Storeで「Gymnastics AI」を検索してください。');
    } catch (e) {
      _showMessage('アプリストアを開く際にエラーが発生しました: $e');
    }
  }


  void _connectWithPrevious() {
    if (_selectedSkillIndex != null && _selectedSkillIndex! > 0) {
      setState(() {
        final currentIndex = _selectedSkillIndex!;
        final previousIndex = currentIndex - 1;
        
        // 前の技が既に連続技グループに属しているかチェック
        if (_connectionGroups[previousIndex] != 0) {
          // 前の技が既に連続技グループに属している場合、同じグループに追加
          _connectionGroups[currentIndex] = _connectionGroups[previousIndex];
        } else {
          // 新しい連続グループを作成
          _connectionGroups[previousIndex] = _nextConnectionGroupId;
          _connectionGroups[currentIndex] = _nextConnectionGroupId;
          _nextConnectionGroupId++;
        }
        _dScoreResult = null;
        // 編集モードの場合は選択をリセットしない
        if (!_isEditingSkill) {
          _selectedSkillIndex = null;
        }
      });
    }
  }
  
  void _disconnectSkill() {
    if (_selectedSkillIndex != null) {
      setState(() {
        final index = _selectedSkillIndex!;
        _connectionGroups[index] = 0; // 連続を解除
        _dScoreResult = null;
        _selectedSkillIndex = null;
      });
    }
  }
  
  void _startEditingSkill() {
    if (_selectedSkillIndex != null) {
      setState(() {
        _isEditingSkill = true;
        // 現在選択されている技をドロップダウンにセット
        _selectedSkill = _routine[_selectedSkillIndex!];
      });
    }
  }
  
  void _saveEditedSkill() {
    if (_selectedSkillIndex != null && _selectedSkill != null) {
      setState(() {
        _routine[_selectedSkillIndex!] = _selectedSkill!;
        _isEditingSkill = false;
        _selectedSkill = null;
        _selectedSkillIndex = null;
        _dScoreResult = null;
      });
    }
  }
  
  void _cancelEditingSkill() {
    setState(() {
      _isEditingSkill = false;
      _selectedSkill = null;
      _selectedSkillIndex = null;
    });
  }

  void _deleteSelectedSkill() {
    if (_selectedSkillIndex != null) {
      setState(() {
        _routine.removeAt(_selectedSkillIndex!);
        _connectionGroups.removeAt(_selectedSkillIndex!);
        _selectedSkillIndex = null;
        _selectedSkill = null;
        _dScoreResult = null;
      });
    }
  }

  void _retryAuthentication() {
    // 正当な再認証試行
    setState(() {
      _isLoading = true;
    });
    
    // 実際の認証プロセスを再実行
    try {
      _initializeApp();
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('認証エラー', '認証に失敗しました。');
    }
  }

  void _showConnectionErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // ユーザーが外側をタップしても閉じない
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text(
                'AIチャット接続エラー',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AIチャット機能は現在利用できません。',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'オフラインでも利用可能な機能',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('• D-Score計算機能', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                    Text('• 全種目分析機能', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                    Text('• アナリティクス機能', style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('🔧 AIチャット復旧方法:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Wi-Fiまたはモバイルデータ接続を確認'),
              Text('• アプリを再起動してみる'),
              Text('• 数分後に再試行する'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // D-Score計算機能に安全に移動（プレミアムチェック付き）
                _safeSwitchToMode(AppMode.dScore);
              },
              child: Text('D-Score計算を使用', style: TextStyle(fontSize: 16, color: Colors.green)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // 再試行
                _retryAuthentication();
              },
              child: Text('再試行', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('閉じる', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            _getText('connectionSettings'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400, // 高さを増やして余裕を持たせる
            child: ListView.builder(
              itemCount: _routine.length,
              itemBuilder: (context, index) {
                final skill = _routine[index];
                final isConnected = _connectionGroups[index] != 0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    elevation: isConnected ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isConnected 
                        ? BorderSide(color: Colors.orange.shade300, width: 2)
                        : BorderSide.none,
                    ),
                    color: isConnected ? Colors.orange.shade50 : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 上部：技番号と技名
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isConnected ? Colors.orange.shade400 : Colors.grey.shade500,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      skill.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Group ${skill.group} • D値: ${skill.valueLetter}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // 下部：連続技ボタン
                          if (index > 0) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      final previousIndex = index - 1;
                                      if (_connectionGroups[previousIndex] != 0) {
                                        _connectionGroups[index] = _connectionGroups[previousIndex];
                                      } else {
                                        _connectionGroups[previousIndex] = _nextConnectionGroupId;
                                        _connectionGroups[index] = _nextConnectionGroupId;
                                        _nextConnectionGroupId++;
                                      }
                                      _dScoreResult = null;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.link, size: 16),
                                  label: Text(
                                    _getText('connectWithPrevious'),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0), // ダイアログの余白調整
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _getText('close'),
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }
  
  // サーバー接続エラー用メッセージ（詳細診断付き）
  String _getServerErrorMessage(String userInput, {String? errorDetails, String? errorType}) {
    final baseMessage = '''🚨 **サーバー接続エラー**

申し訳ございません。現在サーバーとの通信に問題が発生しています。

**🔧 解決方法：**
• Wi-Fi/モバイルデータ接続を確認してください
• アプリを再起動してください  
• 数分後に再度お試しください''';

    String diagnosticInfo = '';
    if (errorType != null) {
      switch (errorType) {
        case 'network':
          diagnosticInfo = '''

**🌐 ネットワークエラー詳細：**
• インターネット接続を確認してください
• 企業ネットワークの場合、ファイアウォール設定を確認
• VPN使用時は接続を一時的に無効にしてお試しください''';
          break;
        case 'timeout':
          diagnosticInfo = '''

**⏰ タイムアウトエラー詳細：**
• サーバーの応答が遅すぎます
• ネットワーク速度が低下している可能性があります
• しばらく時間をおいて再度お試しください''';
          break;
        case 'auth':
          diagnosticInfo = '''

**🔐 認証エラー詳細：**
• アプリの認証に問題が発生しています
• アプリを一度終了し、再起動してください
• 問題が続く場合は、アプリを再インストールをお試しください''';
          break;
        case 'server':
          diagnosticInfo = '''

**⚙️ サーバーエラー詳細：**
• サーバー側で一時的な問題が発生しています
• メンテナンス中の可能性があります  
• 10-15分後に再度お試しください''';
          break;
        case 'maintenance':
          diagnosticInfo = '''

**🔧 メンテナンス中：**
• サーバーが一時的にメンテナンス中です
• AI機能は現在利用できませんが、オフライン機能をご利用ください
• D-Score計算、全種目分析、アナリティクス機能は利用可能です
• 復旧まで10-15分程度お待ちください''';
          break;
        default:
          diagnosticInfo = '''

**❓ 不明なエラー：**
• 予期しない問題が発生しました
• アプリを再起動してお試しください''';
      }
    }

    final detailedError = errorDetails != null ? '''

**🔍 技術的詳細：**
$errorDetails''' : '';

    return '''$baseMessage$diagnosticInfo$detailedError

**📱 このアプリについて：**
このアプリはクラウドベースの高度なAI体操コーチです。
オフラインでの動作はサポートしていません。

**⚡️ サーバー情報：**
URL: ${Config.apiBaseUrl}
エンドポイント: /chat/message
状態: 接続失敗
時刻: ${DateTime.now().toString().substring(0, 19)}

お困りの場合は再試行ボタンをお試しください。''';
  }

  // オフライン専門知識データベースから回答を取得
  String? _getOfflineAnswer(String userInput) {
    try {
      print('🔍 オフライン専門知識データベースを検索中...');
      final expertAnswer = GymnasticsExpertDatabase.getExpertAnswer(userInput);
      
      if (expertAnswer != null && expertAnswer.isNotEmpty) {
        print('✅ オフライン専門知識で回答が見つかりました');
        return '''**🤖 オフライン体操専門AI**

$expertAnswer

---
*注意: サーバーメンテナンス中のため、オフライン専門知識データベースから回答しています。最新のAI機能は復旧後にご利用ください。*''';
      } else {
        print('❌ オフライン専門知識データベースに該当する回答が見つかりませんでした');
        return null;
      }
    } catch (e) {
      print('❌ オフライン専門知識データベースの検索エラー: $e');
      return null;
    }
  }

  Future<void> _loadSkills(String apparatus) async {
    final lang = _currentLang == '日本語' ? 'ja' : 'en';
    final cacheKey = '${apparatus}_$lang';
    
    // Check cache first - enable caching for better performance
    if (_skillDataCache.containsKey(cacheKey)) {
      print('Using cached skills for $apparatus ($lang)');
      setState(() {
        _skillList = _skillDataCache[cacheKey]!;
        _isSkillLoading = false;
      });
      return;
    }

    setState(() {
      _isSkillLoading = true;
      _skillList = [];
    });

    final path = 'data/skills_$lang.csv';
    try {
      print('Loading skills from: $path for apparatus: $apparatus');
      final rawCsv = await rootBundle.loadString(path);
      
      // Use compute for heavy CSV parsing to avoid blocking UI
      final skills = await _parseSkillsCsv(rawCsv, apparatus);
      
      print('Loaded ${skills.length} skills for $apparatus');

      // Cache the results
      _skillDataCache[cacheKey] = skills;

      if (mounted) {
        setState(() {
          _skillList = skills;
          _isSkillLoading = false;
        });
      }
    } catch (e) {
      print('Error loading skills: $e');
      if (mounted) {
        setState(() {
          _isSkillLoading = false;
        });
      }
    }
  }
  
  // Helper method for parsing CSV in isolate (if needed)
  Future<List<Skill>> _parseSkillsCsv(String rawCsv, String apparatus) async {
    final List<List<dynamic>> listData = const CsvToListConverter().convert(rawCsv);
    
    if (listData.isEmpty) return [];
    
    final headers = listData[0].map((e) => e.toString()).toList();
    
    final skills = listData
        .skip(1)
        .map((row) {
          final map = Map<String, dynamic>.fromIterables(headers, row);
          return map;
        })
        .where((map) => map['apparatus'] == apparatus)
        .map((map) => Skill.fromMap(map))
        .toList();
    
    skills.sort((a, b) => a.name.compareTo(b.name));
    return skills;
  }

  // メッセージを送信し、APIから応答を受け取る - 無効化済み
  void _handleSendPressed() async {
    return; // チャット機能無効化のため何もしない
    final userInput = _textController.text;
    if (userInput.trim().isEmpty) return;

    // 使用制限チェック
    final canSend = await ChatUsageTracker.canSendMessage(_userSubscription);
    if (!canSend) {
      _showChatLimitReachedDialog();
      return;
    }

    HapticFeedback.lightImpact(); // 送信時のフィードバック

    // ユーザーメッセージを追加
    setState(() {
      _messages.insert(0, ChatMessage(text: userInput, isUser: true));
      _isLoading = true;
    });
    _textController.clear();

    try {
      // デバッグ用：サーバー優先モード
      print('Sending message to server: $userInput');
      
      // 専門知識データベースをチェック（100%対応）
      final expertAnswer = GymnasticsExpertDatabase.getExpertAnswer(userInput);
      
      // 専門知識データベースに完全な回答がある場合
      if (false && !expertAnswer.contains('より正確な回答のために詳細を教えてください')) { // 一時的に無効化
        setState(() {
          _messages.insert(0, ChatMessage(
            text: expertAnswer,
            isUser: false,
          ));
          _isLoading = false;
        });
        
        // 使用量を記録（ボーナスクレジットを考慮）
        await ChatUsageTracker.recordChatUsage(_userSubscription);
        _checkChatUsageWarning();
        return;
      }
      
      // 従来の専門知識データベースも確認
      final knowledgeResponse = GymnasticsKnowledgeBase.getKnowledgeResponse(userInput);
      
      if (false && knowledgeResponse != null) { // 一時的に無効化
        setState(() {
          _messages.insert(0, ChatMessage(
            text: knowledgeResponse,
            isUser: false,
          ));
          _isLoading = false;
        });
        
        await ChatUsageTracker.recordChatUsage(_userSubscription);
        _checkChatUsageWarning();
        return;
      }

      // 専門知識データベースに完全な回答がある場合
      if (!expertAnswer.contains('より正確な回答のために詳細を教えてください')) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: expertAnswer,
            isUser: false,
          ));
          _isLoading = false;
        });
        
        // 使用量を記録（ボーナスクレジットを考慮）
        await ChatUsageTracker.recordChatUsage(_userSubscription);
        _checkChatUsageWarning();
        return;
      }
      
      // 従来の専門知識データベースも確認
      if (knowledgeResponse != null) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: '$knowledgeResponse\n\n🏆 体操専門知識データベースより',
            isUser: false,
          ));
          _isLoading = false;
        });
        
        // 使用量を記録（ボーナスクレジットを考慮）
        await ChatUsageTracker.recordChatUsage(_userSubscription);
        _checkChatUsageWarning();
        return;
      }

      // 専門知識データベースに回答がない場合、AIサーバーにリクエストを送信
      print('🚀 チャットAPI リクエスト送信開始');
      print('📤 エンドポイント: /chat/message');
      print('📤 メッセージ: ${userInput.substring(0, math.min(50, userInput.length))}${userInput.length > 50 ? "..." : ""}');
      
      final response = await _makeDeviceApiRequest(
        '/chat/message',
        method: 'POST',
        body: {
          'message': userInput,
        },
      );

      // レスポンスを確認してデバッグ
      print('📥 API Response Status: ${response.statusCode}');
      print('📥 API Response Body: ${utf8.decode(response.bodyBytes)}');
      
      // サーバーエラー時は接続エラーメッセージを表示
      if (response.statusCode != 200) {
        print('🚨 サーバーエラー: ${response.statusCode}');
        
        // HTTP 500エラーの場合は特別な処理
        if (response.statusCode == 500) {
          print('⚠️ サーバー内部エラー検出 - メンテナンス中の可能性');
          
          // オフライン専門知識データベースを再試行
          final offlineAnswer = _getOfflineAnswer(userInput);
          if (offlineAnswer != null) {
            print('💡 オフライン専門知識で回答を提供');
            setState(() {
              _messages.insert(0, ChatMessage(text: offlineAnswer, isUser: false));
              _isLoading = false;
            });
            return;
          }
        }
        
        String errorType = 'server';
        if (response.statusCode == 401 || response.statusCode == 403) {
          errorType = 'auth';
        } else if (response.statusCode == 500) {
          errorType = 'maintenance';
        }
        
        final errorMessage = _getServerErrorMessage(
          userInput,
          errorDetails: 'HTTP ${response.statusCode}: ${utf8.decode(response.bodyBytes)}',
          errorType: errorType,
        );
        setState(() {
          _messages.insert(0, ChatMessage(text: errorMessage, isUser: false));
          _isLoading = false;
        });
        
        // 接続エラーダイアログを表示
        _showConnectionErrorDialog();
        return;
      }
      
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        // AIの応答を安全に取得  
        final aiResponse = data['response'] as String? ?? 
                          _getServerErrorMessage(userInput, errorType: 'server', errorDetails: 'Empty response from server'); // フォールバック
        
        setState(() {
          _messages.insert(0, ChatMessage(text: aiResponse, isUser: false));
        });
      } catch (e) {
        print('🚨 JSON解析エラー: $e');
        // JSON解析に失敗した場合はサーバーエラー
        final errorMessage = _getServerErrorMessage(
          userInput,
          errorDetails: 'JSON Parse Error: $e',
          errorType: 'server',
        );
        setState(() {
          _messages.insert(0, ChatMessage(text: errorMessage, isUser: false));
          _isLoading = false;
        });
        
        // 接続エラーダイアログを表示
        _showConnectionErrorDialog();
      }
      
      // 使用量を記録（ボーナスクレジットを考慮）
      await ChatUsageTracker.recordChatUsage(_userSubscription);
      _checkChatUsageWarning();
      
    } on NetworkException catch (e) {
      // ネットワークエラー時はサーバー接続エラーを表示
      print('🚨 ネットワークエラー: $e');
      String errorType = 'network';
      if (e.toString().contains('TimeoutException')) {
        errorType = 'timeout';
      }
      final errorMessage = _getServerErrorMessage(
        userInput,
        errorDetails: e.toString(),
        errorType: errorType,
      );
      setState(() {
        _messages.insert(0, ChatMessage(
          text: errorMessage,
          isUser: false,
        ));
        _isLoading = false;
      });
      
      // 接続エラーダイアログを表示
      _showConnectionErrorDialog();
    } on AuthenticationException catch (e) {
      // 認証エラー時は自動再認証を試行
      print('🚨 認証エラー: $e');
      print('🔄 認証トークンを再生成して再試行中...');
      
      try {
        // 認証トークンを再生成
        await _generateDeviceAuthToken();
        
        // 再度APIリクエストを試行
        final retryResponse = await _makeDeviceApiRequest(
          '/chat/message',
          method: 'POST',
          body: {
            'message': userInput,
          },
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(utf8.decode(retryResponse.bodyBytes));
          final aiResponse = data['response'] as String? ?? 
                            _getServerErrorMessage(userInput, errorType: 'server', errorDetails: 'Empty response from server');
          
          setState(() {
            _messages.insert(0, ChatMessage(text: aiResponse, isUser: false));
            _isLoading = false;
          });
          return; // 成功したので終了
        }
      } catch (retryError) {
        print('❌ 再認証試行も失敗: $retryError');
      }
      
      final errorMessage = _getServerErrorMessage(
        userInput,
        errorDetails: e.toString(),
        errorType: 'auth',
      );
      setState(() {
        _messages.insert(0, ChatMessage(
          text: errorMessage,
          isUser: false,
        ));
        _isLoading = false;
      });
      
      // 接続エラーダイアログを表示
      _showConnectionErrorDialog();
    } on DataException catch (e) {
      print('🚨 データエラー: $e');
      final errorMessage = _getServerErrorMessage(
        userInput,
        errorDetails: e.toString(),
        errorType: 'server',
      );
      setState(() {
        _messages.insert(0, ChatMessage(
          text: errorMessage,
          isUser: false,
        ));
        _isLoading = false;
      });
      
      // 接続エラーダイアログを表示
      _showConnectionErrorDialog();
    } catch (e) {
      print('🚨 予期せぬエラー: $e');
      final errorMessage = _getServerErrorMessage(
        userInput,
        errorDetails: e.toString(),
        errorType: 'unknown',
      );
      setState(() {
        _messages.insert(0, ChatMessage(
          text: errorMessage,
          isUser: false,
        ));
        _isLoading = false;
      });
      
      // 接続エラーダイアログを表示
      _showConnectionErrorDialog();
    }
  }

  // チャット使用量の警告チェック
  void _checkChatUsageWarning() async {
    if (_userSubscription.canAccessUnlimitedChat()) {
      return;
    }
    
    final isDailyNearLimit = await ChatUsageTracker.isNearDailyLimit(_userSubscription);
    final isMonthlyNearLimit = await ChatUsageTracker.isNearMonthlyLimit(_userSubscription);
    
    if (isDailyNearLimit || isMonthlyNearLimit) {
      _showChatUsageWarningDialog();
    }
  }

  // チャット制限到達時のダイアログ
  void _showChatLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('チャット制限に達しました'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('無料版では以下の制限があります：'),
              const SizedBox(height: 10),
              const Text('• 1日10回までのメッセージ'),
              const Text('• 1ヶ月50回までのメッセージ'),
              const SizedBox(height: 15),
              const Text('プレミアム版では無制限でご利用いただけます。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
            // リワード広告ボタン（無料でボーナスを獲得）
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showRewardAdForChatBonus();
              },
              icon: Icon(Icons.play_circle_fill, color: Colors.green[400]),
              label: Text(
                '広告を見て+5回',
                style: TextStyle(color: Colors.green[400]),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green[400]!),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _purchasePremium();
              },
              child: const Text('プレミアムにアップグレード'),
            ),
          ],
        );
      },
    );
  }

  // リワード広告でチャットボーナスを獲得
  Future<void> _showRewardAdForChatBonus() async {
    try {
      print('リワード広告を表示してチャットボーナスを獲得');
      
      bool success = false;
      
      if (_adManager.isRewardedAdReady) {
        success = await _adManager.showRewardedAd();
      } else {
        // リワード広告が読み込まれていない場合
        _showMessage('広告の準備中です。しばらく待ってから再度お試しください。');
        _adManager.loadRewardedAd();
        return;
      }
      
      if (success) {
        // 広告を最後まで見た場合、ボーナスクレジットを付与
        await _grantChatBonus();
      } else {
        _showMessage('広告の視聴が完了しませんでした');
      }
    } catch (e) {
      print('リワード広告エラー: $e');
      _showMessage('広告の表示中にエラーが発生しました');
    }
  }

  // チャットボーナスクレジットを付与
  Future<void> _grantChatBonus() async {
    try {
      final bonusCredits = 5; // 5回分のボーナス
      
      // ボーナスクレジットをSharedPreferencesに保存
      final prefs = await SharedPreferences.getInstance();
      final currentBonus = prefs.getInt('chat_bonus_credits') ?? 0;
      await prefs.setInt('chat_bonus_credits', currentBonus + bonusCredits);
      
      // 成功メッセージ
      _showSuccessSnackBar('🎉 チャットボーナス +${bonusCredits}回を獲得しました！');
      
      // UIを更新
      setState(() {});
      
      print('チャットボーナス付与完了: +$bonusCredits 合計: ${currentBonus + bonusCredits}');
      
    } catch (e) {
      print('チャットボーナス付与エラー: $e');
      _showMessage('ボーナスの付与中にエラーが発生しました');
    }
  }

  // チャット使用量警告ダイアログ
  void _showChatUsageWarningDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('チャット使用量のお知らせ'),
          content: FutureBuilder<String>(
            future: ChatUsageTracker.getUsageStatus(_userSubscription),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('現在の使用量: ${snapshot.data}'),
                    const SizedBox(height: 10),
                    const Text('制限に近づいています。プレミアム版では無制限でご利用いただけます。'),
                  ],
                );
              }
              return const CircularProgressIndicator();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _purchasePremium();
              },
              child: const Text('プレミアムにアップグレード'),
            ),
          ],
        );
      },
    );
  }

  // 体操コンテキストを構築（APIに送信用）
  String _buildGymnasticsContext() {
    return '''
体操競技の専門システムです。簡潔で正確な回答をしてください：

基本ルール：
- 跳馬：1技のみ、グループ点なし
- その他種目：最大8技、各グループ最大4技（グループ4除く）
- 床運動：バランス技必須、最大グループ点2.0点
- 連続技：種目別ルール（床等G2,3,4、鉄棒G1,2,3）、詳細は専門知識参照

分かりやすく簡潔に説明してください。
''';
  }

  // チャットをリセットする - 無効化済み
  void _resetChat() {
    return; // チャット機能無効化のため何もしない
    /*
    setState(() {
      _messages.clear();
      _session_id = Uuid().v4();
    });
    */
  }




  // 連続技グループを適切に構築
  List<List<Skill>> _buildConnectedSkillGroups(List<Skill> skills, List<int> connectionGroups) {
    final routine = <List<Skill>>[];
    
    if (skills.isEmpty) return routine;
    
    List<Skill> currentGroup = [skills[0]];
    
    for (int i = 1; i < skills.length; i++) {
      // 前の技と連続する場合
      if (i < connectionGroups.length && connectionGroups[i] != 0) {
        currentGroup.add(skills[i]);
      } else {
        // 連続技グループを確定し、新しいグループを開始
        routine.add(List.from(currentGroup));
        currentGroup = [skills[i]];
      }
    }
    
    // 最後のグループを追加
    if (currentGroup.isNotEmpty) {
      routine.add(currentGroup);
    }
    
    return routine;
  }

  // D-スコアを再計算
  Future<void> _calculateDScoreFromRoutine() async {
    if (_selectedApparatus == null || _routine.isEmpty) {
      return;
    }
    
    // 使用量チェック
    final canCalculate = await DScoreUsageTracker.canCalculateDScore(_userSubscription);
    if (!canCalculate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('D-Score計算の使用制限に達しました。プレミアムにアップグレードするか、明日再度お試しください。'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    // 連続技グループを適切に構築
    final routine = _buildConnectedSkillGroups(_routine, _connectionGroups);
    
    // D-スコアを計算
    final result = calculateDScore(_selectedApparatus!, routine);
    
    // 使用量を記録
    await DScoreUsageTracker.recordDScoreUsage(_userSubscription);
    
    setState(() {
      _dScoreResult = result;
    });
    
    // 無料ユーザーの場合、計算完了後にインタースティシャル広告を表示
    if (_userSubscription.shouldShowAds() && _isAdManagerInitialized) {
      // 計算結果の表示後、少し遅らせて広告を表示（UX向上のため）
      Future.delayed(const Duration(milliseconds: 1500), () {
        _showCalculationCompletedWithAd();
      });
    }
  }

  // 計算完了時の広告表示とプレミアム誘導
  void _showCalculationCompletedWithAd() {
    if (!_userSubscription.shouldShowAds() || !_isAdManagerInitialized) {
      return;
    }
    
    if (_adManager.isInterstitialAdReady) {
      _adManager.showInterstitialAd();
      
      // 広告表示後にプレミアム誘導メッセージを表示
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showPremiumUpgradePrompt();
        }
      });
    } else {
      // 広告が利用できない場合は直接プレミアム誘導
      _showPremiumUpgradePrompt();
    }
  }
  
  // プレミアムアップグレード誘導
  void _showPremiumUpgradePrompt() {
    if (!mounted || !_userSubscription.isFree) return;
    
    // モバイル版のプレミアム誘導に統一
    if (false) { // Web版条件を無効化
      // Web版では広告付きで全機能が利用可能であることを案内
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.web, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Web版では広告付きで全機能が無料でご利用いただけます！',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'モバイル版',
            textColor: Colors.white,
            onPressed: () {
              _showMessage('モバイル版ではプレミアム機能が利用できます');
            },
          ),
        ),
      );
    } else {
      // モバイル版では従来のプレミアム誘導
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'プレミアムなら広告なしで計算結果をすぐに確認できます！',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade800,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'アップグレード',
            textColor: Colors.amber,
            onPressed: () {
              // TODO: プレミアム購入画面に遷移
              _showMessage('プレミアム機能は準備中です');
            },
          ),
        ),
      );
    }
  }

  // メッセージを表示
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 初期化中のみローディング表示
    if (_isAuthLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 直接メイン画面へ（認証不要）
    return GestureDetector(
      onTap: () {
        // キーボードフォーカスを外す
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0, // タイトル領域のスペーシングを最小化
          title: SizedBox(
            width: MediaQuery.of(context).size.width * 0.75, // 画面幅の75%まで使用
            child: Text(
              _getAppBarTitle(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          actions: [
            // バックグラウンド初期化インジケーター
            if (!_isBackgroundInitComplete)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
            // メニューボタン（複数の機能を統合）
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) {
                switch (value) {
                  case 'feedback':
                    _showFeedbackDialog();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'feedback',
                  child: Row(
                    children: [
                      Icon(Icons.feedback, size: 20),
                      SizedBox(width: 8),
                      Text(_currentLang == '日本語' ? 'フィードバック' : 'Feedback'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          currentIndex: PlatformUIConfig.getTabIndex(_currentMode),
          type: BottomNavigationBarType.fixed,
          onTap: _handleTabTap,
          items: _buildTabItems(),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
                color: Theme.of(context).drawerTheme.backgroundColor,
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: MediaQuery.of(context).size.height * 0.15,
                  ),
                ),
              ),
              // プレミアム状態表示
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _userSubscription.isPremium ? Colors.amber.shade900 : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _userSubscription.isPremium ? Colors.amber : Colors.grey.shade600,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _userSubscription.isPremium ? Icons.star : Icons.star_border,
                          color: _userSubscription.isPremium ? Colors.amber : Colors.grey.shade400,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _userSubscription.isPremium ? 'プレミアムユーザー' : '無料ユーザー',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _userSubscription.isPremium ? Colors.amber.shade200 : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_userSubscription.isFree && !kIsWeb) ...[
                      SizedBox(height: 12),
                      Text(
                        'プレミアムでもっと多くの機能を！',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 36),
                        ),
                        onPressed: _showSubscriptionPage,
                        child: Text(_getText('premiumUpgrade')),
                      ),
                    ] else if (_userSubscription.isFree && kIsWeb) ...[
                      SizedBox(height: 12),
                      Text(
                        'Web版では全機能を広告付きで無料提供',
                        style: TextStyle(color: Colors.green.shade300, fontSize: 14),
                      ),
                    ] else ...[
                      SizedBox(height: 8),
                      Text(
                        'すべての機能をご利用いただけます',
                        style: TextStyle(color: Colors.amber.shade200, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('設定', style: Theme.of(context).textTheme.titleLarge),
              ),
              ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(_getText('rulebookLanguage'), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    DropdownButton<String>(
                      value: _currentLang,
                      onChanged: (String? newValue) {
                        setState(() {
                          _currentLang = newValue!;
                          _resetChat();
                          // UIを更新するためにsetStateを呼び出す
                        });
                      },
                      items: <String>['日本語', 'English']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
               Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(_getText('modeSelection'), style: Theme.of(context).textTheme.titleSmall),
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('dScoreCalculator')),
                value: AppMode.dScore,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                  // プレミアムチェック付きでモード切り替え
                  if (value != null) {
                    _safeSwitchToMode(value);
                  }
                },
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('allApparatus')),
                value: AppMode.allApparatus,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                  // プレミアムチェック付きでモード切り替え
                  if (value != null) {
                    _safeSwitchToMode(value);
                  }
                },
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('routineAnalysis')),
                value: AppMode.analytics,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                  // プレミアムチェック付きでモード切り替え
                  if (value != null) {
                    _safeSwitchToMode(value);
                  }
                },
              ),
              RadioListTile<AppMode>(
                title: Text('AIチャット${AppConfig.enableAIChat ? '' : ' (準備中)'}'),
                value: AppMode.chat,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                  // プレミアムチェック付きでモード切り替え
                  if (value != null) {
                    _safeSwitchToMode(value);
                  }
                },
              ),
              const Divider(),
              // 利用規約
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(_currentLang == '日本語' ? '利用規約' : 'Terms of Service'),
                onTap: () {
                  Navigator.of(context).pop();
                  _launchURL('https://www.gymnastics-ai.com/terms');
                },
              ),
              // プライバシーポリシー
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(_currentLang == '日本語' ? 'プライバシーポリシー' : 'Privacy Policy'),
                onTap: () {
                  Navigator.of(context).pop();
                  _launchURL('https://www.gymnastics-ai.com/privacy');
                },
              ),
              const Divider(),
              // 管理者パネル（管理者のみ表示）
              if (_isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: Text(_getText('adminPanel')),
                  onTap: () {
                    setState(() {
                      _showAdminPanel = !_showAdminPanel;
                    });
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _currentMode == AppMode.dScore
                    ? _buildDScoreInterface()
                    : _currentMode == AppMode.allApparatus
                      ? _buildAllApparatusInterface()
                      : _currentMode == AppMode.analytics
                        ? _buildAnalyticsInterface()
                        : _currentMode == AppMode.chat
                          ? _buildChatInterface()
                          : _buildAdminInterface(),
            ),
            // Web版フッターバナー広告
            if (PlatformConfig.isWeb && _userSubscription.shouldShowAds())
              Container(
                height: 90,
                width: double.infinity,
                color: Colors.grey[900],
                child: Center(
                  child: PropellerAdsWidget(
                    zoneId: PropellerAdsConfig.bannerZoneId,
                    adType: PropellerAdType.banner,
                    width: 728,
                    height: 90,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 管理者パネル用のUI
  Widget _buildAdminPanel() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'キャッシュ監視パネル',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showAdminPanel = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isLoadingCacheStats ? null : _fetchCacheStats,
                icon: _isLoadingCacheStats 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                label: const Text('統計情報を取得'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showClearCacheDialog(),
                icon: const Icon(Icons.clear_all),
                label: const Text('キャッシュクリア'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_cacheStats.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'キャッシュ統計情報:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._cacheStats.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            entry.value.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // キャッシュクリア確認ダイアログ
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('キャッシュクリア'),
          content: const Text('キャッシュをクリアしますか？この操作は取り消せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_getText('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearCache();
              },
              child: const Text('クリア'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  // Dスコア計算用のUI
  Widget _buildDScoreInterface() {
    final langCode = _currentLang == '日本語' ? 'ja' : 'en';
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 無料ユーザーにはバナー広告を表示
          if (_userSubscription.shouldShowAds() && _isAdManagerInitialized)
            Container(
              margin: EdgeInsets.only(bottom: isMobile ? 12.0 : 16.0),
              child: _buildBannerAd(),
            ),
          
          // 種目選択カード
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: isMobile ? 12.0 : 16.0),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '種目選択', 
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 16.0 : 18.0
                    )
                  ),
                  SizedBox(height: isMobile ? 8.0 : 12.0),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedApparatus,
                        hint: Text(_getText('selectApparatus')),
                        isExpanded: true,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              // 現在のデータを全種目データに保存
                              if (_selectedApparatus != null) {
                                _allRoutines[_selectedApparatus!] = List.from(_routine);
                                _allConnectionGroups[_selectedApparatus!] = List.from(_connectionGroups);
                                _allNextConnectionGroupIds[_selectedApparatus!] = _nextConnectionGroupId;
                                _allDScoreResults[_selectedApparatus!] = _dScoreResult;
                              }
                              
                              // 新しい種目のデータを読み込み
                              _selectedApparatus = newValue;
                              _routine = List.from(_allRoutines[newValue] ?? []);
                              _connectionGroups = List.from(_allConnectionGroups[newValue] ?? []);
                              _nextConnectionGroupId = _allNextConnectionGroupIds[newValue] ?? 1;
                              _dScoreResult = _allDScoreResults[newValue];
                              _selectedSkill = null;
                              _selectedSkillIndex = null;
                              _resetSkillPagination(); // 種目変更時にページをリセット
                            });
                            _ensureSkillsLoaded(newValue);
                          }
                        },
                        items: _apparatusData.keys.map<DropdownMenuItem<String>>((String key) {
                          return DropdownMenuItem<String>(
                            value: key,
                            child: Text(_apparatusData[key]![langCode]!),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          // 技選択カード
          if (_selectedApparatus != null)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('技選択', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12.0),
                    _buildSkillSelector(),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16.0),
          
          // 演技構成カード
          Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: isMobile ? 12.0 : 16.0),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '演技構成', 
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 16.0 : 18.0
                              )
                            ),
                            SizedBox(width: 12),
                            // 技数カウンター
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _routine.length >= 8 ? Colors.orange[100] : Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedApparatus != null && 
                                (_selectedApparatus!.toLowerCase() == 'vault' || 
                                 _selectedApparatus!.toLowerCase() == 'vt')
                                  ? '${_routine.length}/1技'
                                  : '${_routine.length}/8技',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _routine.length >= 8 ? Colors.orange[800] : Colors.blue[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.save_alt, size: 20),
                            onPressed: _routine.isNotEmpty ? () {
                              if (!_userSubscription.isPremium) {
                                _showUpgradeDialog('演技構成の保存');
                                return;
                              }
                              _saveCurrentRoutine();
                            } : null,
                            tooltip: '構成を保存',
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 20),
                            onPressed: () {
                              if (!_userSubscription.isPremium) {
                                _showUpgradeDialog('演技構成の読み込み');
                                return;
                              }
                              _showSavedRoutines();
                            },
                            tooltip: '保存済み構成',
                            padding: const EdgeInsets.all(4),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8.0 : 12.0, 
                              vertical: isMobile ? 4.0 : 6.0
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_routine.length}技', 
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                fontSize: isMobile ? 12.0 : 14.0
                              )
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 8.0 : 12.0),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: 140,
                      maxHeight: 300,
                    ),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: _routine.isEmpty
                        ? const Center(
                            child: Text(
                              '技を選択して追加してください',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: _buildRoutineDisplay(),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12.0),
                  if (_isEditingSkill) 
                    // 編集モード中のボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 左下に「前の技と繋げる」ボタンを配置
                        if (_selectedSkillIndex != null && _selectedSkillIndex! > 0)
                          TextButton.icon(
                            onPressed: _connectWithPrevious,
                            icon: const Icon(Icons.link, size: 16),
                            label: Text(_getText('connectWithPrevious')),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        // 右側のボタン
                        TextButton.icon(
                          onPressed: _cancelEditingSkill,
                          icon: const Icon(Icons.cancel, size: 18),
                          label: Text(_getText('cancel')),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  else
                    // 通常モードのボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_selectedSkillIndex != null) ...[
                            TextButton.icon(
                              onPressed: _deleteSelectedSkill,
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('削除'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ] else if (_routine.length >= 2 && (_selectedApparatus == 'FX' || _selectedApparatus == 'HB'))
                          ElevatedButton.icon(
                            onPressed: () {
                              if (!_userSubscription.isPremium) {
                                _showUpgradeDialog('連続技設定');
                                return;
                              }
                              _showConnectionDialog();
                            },
                            icon: const Icon(Icons.link, size: 16),
                            label: Text(_getText('connectionSettings')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          )
                        else
                          const Expanded(
                            child: Text('技をタップして編集', style: TextStyle(color: Colors.grey)),
                          ),
                        
                        ElevatedButton.icon(
                          onPressed: _routine.isNotEmpty && _selectedApparatus != null
                            ? () async {
                                // 使用量チェック
                                final canCalculate = await DScoreUsageTracker.canCalculateDScore(_userSubscription);
                                if (!canCalculate) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('D-Score計算の使用制限に達しました。プレミアムにアップグレードするか、明日再度お試しください。'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }
                                
                                // 床運動の場合、バランス技チェック
                                if (_selectedApparatus!.toLowerCase() == 'floor' || 
                                    _selectedApparatus!.toLowerCase() == 'fx') {
                                  final floorError = _checkFloorRequirements(_routine);
                                  if (floorError != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(floorError),
                                        backgroundColor: Colors.red,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                    return;
                                  }
                                }
                                
                                final routineForCalculation = _convertToGroupedRoutine();
                                
                                // 計算キャッシュキーを生成
                                final cacheKey = _generateCalculationCacheKey(_selectedApparatus!, routineForCalculation);
                                
                                // キャッシュから取得を試行
                                if (_calculationCache.containsKey(cacheKey)) {
                                  setState(() {
                                    _dScoreResult = _calculationCache[cacheKey]!;
                                    // 全種目一覧用にもスコアを保存
                                    if (_selectedApparatus != null) {
                                      _allDScoreResults[_selectedApparatus!] = _dScoreResult;
                                    }
                                  });
                                  
                                  // キャッシュからの取得でも全種目と分析タブにデータを共有
                                  _shareCalculationDataToOtherTabs();
                                  return;
                                }
                                
                                // 新規計算
                                final result = calculateDScore(_selectedApparatus!, routineForCalculation);
                                
                                // 使用量を記録
                                await DScoreUsageTracker.recordDScoreUsage(_userSubscription);
                                
                                // キャッシュに保存
                                _calculationCache[cacheKey] = result;
                                _lastCalculationKey = cacheKey;
                                
                                setState(() {
                                  _dScoreResult = result;
                                  // 全種目一覧用にもスコアを保存
                                  if (_selectedApparatus != null) {
                                    _allDScoreResults[_selectedApparatus!] = result;
                                  }
                                });
                                
                                // 計算完了後に全種目と分析タブにデータを自動共有
                                _shareCalculationDataToOtherTabs();
                              }
                            : null,
                          icon: const Icon(Icons.calculate),
                          label: Text(_getText('calculate')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                    
                    // D-Score計算使用回数ステータス
                    if (!_userSubscription.isPremium)
                      FutureBuilder<String>(
                        future: DScoreUsageTracker.getUsageStatus(_userSubscription),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Container(
                              margin: const EdgeInsets.only(top: 8.0),
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                snapshot.data!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    
                    // D-Score計算制限時の広告視聴ボタン（Row外に配置）
                    FutureBuilder<bool>(
                      future: _canShowDScoreRewardedAd(),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: ElevatedButton.icon(
                                onPressed: () => _showDScoreRewardedAd(),
                                icon: const Icon(Icons.play_circle_outline, size: 16),
                                label: const Text('広告を見て+2回計算'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16.0),
          
          // 計算結果カード
          if (_dScoreResult != null)
            _buildDScoreResultDetails(_dScoreResult!),
          
          // ローディング表示
          if (_isSkillLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_selectedApparatus != null && _skillList.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Text('${_apparatusData[_selectedApparatus]![langCode]} の技データが見つかりません。'),
                ),
              ),
            )
          else if (_selectedApparatus == null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: Text(
                    _getText('selectApparatus'),
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Column(
      children: [
        // 検索フィールド
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[400]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _skillSearchController,
            decoration: InputDecoration(
              hintText: '技を検索...',
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 14 : 16,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
              suffixIcon: _skillSearchQuery.isNotEmpty 
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[700]),
                    onPressed: () {
                      setState(() {
                        _skillSearchQuery = '';
                        _skillSearchController.clear();
                        _resetSkillPagination(); // 検索クリア時にページをリセット
                      });
                    },
                  )
                : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16, 
                vertical: isMobile ? 12 : 16
              ),
            ),
            style: TextStyle(
              color: Colors.black87,
              fontSize: isMobile ? 14 : 16,
            ),
            onChanged: (value) {
              setState(() {
                _skillSearchQuery = value;
                _resetSkillPagination(); // 検索時にページをリセット
              });
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        // フィルタチップ
        _buildFilterChips(),
        
        const SizedBox(height: 12),
        
        // 技選択カード表示（常時表示）
        if (_getFilteredSkillList().isNotEmpty)
          Container(
            height: isMobile ? 150 : 180,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              itemCount: _getPaginatedSkillList().length,
              itemBuilder: (context, index) {
                final skill = _getPaginatedSkillList()[index];
                final isSelected = _selectedSkill?.name == skill.name;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  child: Material(
                    elevation: isSelected ? 2 : 0.5,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          if (_selectedSkill?.name == skill.name) {
                            _selectedSkill = null; // 選択解除
                          } else {
                            _selectedSkill = skill; // 新規選択
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: isSelected 
                            ? Colors.blue[50] 
                            : Colors.white,
                          border: isSelected 
                            ? Border.all(color: Colors.blue[400]!, width: 1.5)
                            : Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    skill.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isMobile ? 13 : 14,
                                      color: isSelected ? Colors.blue[800] : Colors.black87,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCompactSkillBadge(
                                      'グループ${skill.group}',
                                      Colors.blue,
                                      isMobile
                                    ),
                                    const SizedBox(width: 4),
                                    _buildCompactSkillBadge(
                                      '${skill.valueLetter}(${skill.value.toStringAsFixed(1)})',
                                      _getDifficultyColor(skill.valueLetter),
                                      isMobile
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.blue[600],
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (skill.description.isNotEmpty && isSelected) ...[
                              const SizedBox(height: 4),
                              Text(
                                skill.description,
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else if (_getFilteredSkillList().isEmpty)
          Container(
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, color: Colors.grey, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '該当する技が見つかりません',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
        // ページネーション コントロール
        if (_getFilteredSkillList().isNotEmpty && _getTotalPages() > 1)
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 技数表示
                Text(
                  '${_getFilteredSkillList().length}技中 ${(_currentSkillPage * _skillsPerPage) + 1}-${((_currentSkillPage + 1) * _skillsPerPage).clamp(0, _getFilteredSkillList().length)}技を表示',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
                // ページナビゲーション
                Row(
                  children: [
                    IconButton(
                      onPressed: _currentSkillPage > 0 ? () {
                        setState(() {
                          _currentSkillPage--;
                        });
                      } : null,
                      icon: const Icon(Icons.chevron_left),
                      style: IconButton.styleFrom(
                        backgroundColor: _currentSkillPage > 0 ? Colors.blue[50] : Colors.grey[100],
                        foregroundColor: _currentSkillPage > 0 ? Colors.blue[700] : Colors.grey[400],
                        minimumSize: Size(isMobile ? 32 : 36, isMobile ? 32 : 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: '前のページ',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 12,
                        vertical: isMobile ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        '${_currentSkillPage + 1} / ${_getTotalPages()}',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _currentSkillPage < _getTotalPages() - 1 ? () {
                        setState(() {
                          _currentSkillPage++;
                        });
                      } : null,
                      icon: const Icon(Icons.chevron_right),
                      style: IconButton.styleFrom(
                        backgroundColor: _currentSkillPage < _getTotalPages() - 1 ? Colors.blue[50] : Colors.grey[100],
                        foregroundColor: _currentSkillPage < _getTotalPages() - 1 ? Colors.blue[700] : Colors.grey[400],
                        minimumSize: Size(isMobile ? 32 : 36, isMobile ? 32 : 36),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: '次のページ',
                    ),
                  ],
                ),
              ],
            ),
          ),
        
        // 選択された技の表示と追加ボタン
        const SizedBox(height: 12),
        
        // 技選択状態の表示
        if (_selectedSkill != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '選択中: ${_selectedSkill!.name}',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ),
                Text(
                  _selectedSkill!.valueLetter,
                  style: TextStyle(
                    color: Colors.blue[600],
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
        
        // 技追加ボタン（常に表示、状態に応じて有効/無効）
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _selectedSkill != null && 
                      (_isEditingSkill || // 編集モードは常に有効
                       _selectedApparatus == null || // 種目未選択
                       _selectedApparatus!.toLowerCase() == 'vault' || // 跳馬
                       _selectedApparatus!.toLowerCase() == 'vt' || // 跳馬
                       _routine.length < 8) // 8技未満
                ? () {
                    HapticFeedback.mediumImpact();
                    if (_isEditingSkill) {
                      // 編集モードの場合は保存処理
                      _saveEditedSkill();
                    } else {
                      // 通常モードの場合は追加処理
                      bool canAdd = true;
                      String errorMessage = '';
                      
                      if (_selectedApparatus != null && 
                          _selectedApparatus!.toLowerCase() != 'vault' && 
                          _selectedApparatus!.toLowerCase() != 'vt') {
                        // 跳馬以外の場合
                        
                        // 8技制限チェック
                        if (_routine.length >= 8) {
                          canAdd = false;
                          errorMessage = '演技構成は最大8技までです';
                        }
                        
                        // グループ制限チェック（グループ1-3は最大4技）
                        if (canAdd && _selectedSkill!.group >= 1 && _selectedSkill!.group <= 3) {
                          final groupCounts = _countSkillsPerGroup(_routine);
                          final currentGroupCount = groupCounts[_selectedSkill!.group] ?? 0;
                          if (currentGroupCount >= 4) {
                            canAdd = false;
                            errorMessage = 'グループ${_selectedSkill!.group}は最大4技までです';
                          }
                        }
                      }
                      
                      if (canAdd) {
                        setState(() {
                          _routine.add(_selectedSkill!);
                          _connectionGroups.add(0); // 0は連続技ではないことを意味
                          _selectedSkill = null;
                          _selectedSkillIndex = null;
                          _dScoreResult = null;
                        });
                      } else {
                        // 制限に達した場合の警告
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  }
                : null,
            icon: Icon(_isEditingSkill ? Icons.edit : Icons.add),
            label: Text(
              _selectedSkill != null 
                ? (_isEditingSkill ? _getText('changeSkill') : _getText('addSkill'))
                : '技を選択してください',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedSkill != null ? Colors.blue : Colors.grey[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: _selectedSkill != null ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // グループフィルタチップ
        FilterChip(
          label: Text('グループ: ${_selectedGroupFilter ?? "全て"}'),
          selected: _selectedGroupFilter != null,
          onSelected: (selected) {
            _showGroupFilterDialog();
          },
          backgroundColor: Colors.grey[100],
          selectedColor: Colors.blue[100],
          checkmarkColor: Colors.blue[700],
        ),
        
        // 難度フィルタチップ
        FilterChip(
          label: Text('難度: ${_selectedDifficultyFilter ?? "全て"}'),
          selected: _selectedDifficultyFilter != null,
          onSelected: (selected) {
            _showDifficultyFilterDialog();
          },
          backgroundColor: Colors.grey[100],
          selectedColor: Colors.orange[100],
          checkmarkColor: Colors.orange[700],
        ),
        
        // フィルタクリアボタン
        if (_selectedGroupFilter != null || _selectedDifficultyFilter != null)
          ActionChip(
            label: const Text('フィルタクリア'),
            onPressed: _clearFilters,
            backgroundColor: Colors.red[50],
            labelStyle: TextStyle(color: Colors.red[700]),
            avatar: Icon(Icons.clear, size: 18, color: Colors.red[700]),
          ),
      ],
    );
  }

  void _showGroupFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('グループフィルタ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('全て'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _selectedGroupFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupFilter = value;
                      _resetSkillPagination(); // フィルタ変更時にページをリセット
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ...List.generate(_getMaxGroupsForApparatus(_selectedApparatus), (index) => index + 1).map((group) =>
                ListTile(
                  title: Text('グループ $group'),
                  leading: Radio<int?>(
                    value: group,
                    groupValue: _selectedGroupFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupFilter = value;
                        _resetSkillPagination(); // フィルタ変更時にページをリセット
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDifficultyFilterDialog() {
    final difficulties = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('難度フィルタ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('全て'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedDifficultyFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedDifficultyFilter = value;
                      _resetSkillPagination(); // フィルタ変更時にページをリセット
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ...difficulties.map((difficulty) =>
                ListTile(
                  title: Text('$difficulty難度'),
                  leading: Radio<String?>(
                    value: difficulty,
                    groupValue: _selectedDifficultyFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedDifficultyFilter = value;
                        _resetSkillPagination(); // フィルタ変更時にページをリセット
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedGroupFilter = null;
      _selectedDifficultyFilter = null;
      _resetSkillPagination(); // フィルタクリア時にページをリセット
    });
  }

  Widget _buildDScoreResultDetails(DScoreResult result) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Card(
            elevation: 6,
            shadowColor: Colors.green.withOpacity(0.3),
            margin: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.05),
                    Colors.blue.withOpacity(0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                child: Column(
                  children: [
                    // メインスコア表示（アニメーション付き）
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween(begin: 0.0, end: result.totalDScore),
                      curve: Curves.easeOutCubic,
                      builder: (context, animatedValue, child) {
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.withOpacity(0.2),
                                Colors.blue.withOpacity(0.2)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: Colors.green[700],
                                    size: isMobile ? 24 : 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'D-Score',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: isMobile ? 20 : 24,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(-1.0, -1.0),
                                          color: Colors.white,
                                        ),
                                        Shadow(
                                          offset: Offset(1.0, -1.0),
                                          color: Colors.white,
                                        ),
                                        Shadow(
                                          offset: Offset(1.0, 1.0),
                                          color: Colors.white,
                                        ),
                                        Shadow(
                                          offset: Offset(-1.0, 1.0),
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                animatedValue.toStringAsFixed(3),
                                style: TextStyle(
                                  fontSize: isMobile ? 36 : 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(-1.5, -1.5),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(1.5, -1.5),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(1.5, 1.5),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(-1.5, 1.5),
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'points',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(-1.0, -1.0),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(1.0, -1.0),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(1.0, 1.0),
                                      color: Colors.white,
                                    ),
                                    Shadow(
                                      offset: Offset(-1.0, 1.0),
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: isMobile ? 16 : 24),
                    
                    // 詳細スコア表示（順次アニメーション）
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '内訳',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 16 : 18,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: isMobile ? 12 : 16),
                          _buildAnimatedScoreRow(
                            '難度点合計', 
                            result.difficultyValue, 
                            Colors.blue, 
                            0,
                            isMobile
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          _buildAnimatedScoreRow(
                            'グループ要求 (${result.fulfilledGroups}/${result.requiredGroups})', 
                            result.groupBonus, 
                            Colors.orange, 
                            200,
                            isMobile
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          _buildAnimatedScoreRow(
                            '連続技ボーナス', 
                            result.connectionBonus, 
                            Colors.purple, 
                            400,
                            isMobile
                          ),
                        ],
                      ),
                    ),
                    
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildScoreRow(String label, double value, MaterialColor color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color[700],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnimatedScoreRow(String label, double value, MaterialColor color, int delay, bool isMobile) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset((1 - animationValue) * 50, 0),
          child: Opacity(
            opacity: animationValue,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 600 + delay),
                  tween: Tween(begin: 0.0, end: value),
                  curve: Curves.easeOutQuart,
                  builder: (context, animatedValue, child) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12, 
                        vertical: isMobile ? 6 : 8
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        animatedValue.toStringAsFixed(3),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // AIチャット情報バー
  Widget _buildChatInfoBar() {
    if (!AppConfig.enableAIChat) {
      return Container(); // 準備中の場合は表示しない
    }
    
    return FutureBuilder<bool>(
      future: _hasInternetConnection(),
      builder: (context, snapshot) {
        final bool isOnline = snapshot.data ?? true;
        final Color bgColor = isOnline ? Colors.blue.shade50 : Colors.orange.shade50;
        final Color borderColor = isOnline ? Colors.blue.shade200 : Colors.orange.shade200;
        final Color iconColor = isOnline ? Colors.blue.shade600 : Colors.orange.shade600;
        final Color textColor = isOnline ? Colors.blue.shade800 : Colors.orange.shade800;
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1.0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud : Icons.cloud_off,
                color: iconColor,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOnline ? 'AIチャット機能（オンライン）' : 'AIチャット機能（オフライン）',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      isOnline 
                        ? 'サーバーに接続済み - AI機能が利用可能です' 
                        : 'D-Score計算機能をご利用ください',
                      style: TextStyle(
                        fontSize: 10,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(iconColor),
                  ),
                )
              else
                Icon(
                  isOnline ? Icons.check_circle : Icons.info_outline,
                  color: isOnline ? Colors.green : iconColor,
                  size: 16,
                ),
            ],
          ),
        );
      },
    );
  }

  // チャットコンテンツの共通UI
  Widget _buildChatContent() {
    return SafeArea(
      child: Column(
        children: [
          // AIチャット機能の説明バー
          _buildChatInfoBar(),
          // 無料ユーザーのみ広告を表示
          if (_userSubscription.shouldShowAds() && _isAdManagerInitialized)
            _buildBannerAd(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _messages[index],
            ),
          ),
          if (_isLoading) const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[700]!)),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _handleSendPressed(),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'メッセージを入力...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _handleSendPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // チャット用のUI - 準備中画面
  Widget _buildChatInterface() {
    if (AppConfig.enableAIChat) {
      // デスクトップWeb版の場合はサイドバー広告付きレイアウト
      final isDesktopWeb = PlatformConfig.isWeb && MediaQuery.of(context).size.width > 1024;
      
      if (isDesktopWeb && _userSubscription.shouldShowAds()) {
        return Row(
          children: [
            // メインチャットエリア
            Expanded(
              child: _buildChatContent(),
            ),
            // 右サイドバー広告
            Container(
              width: 320,
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[900],
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    '広告',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // サイドバー広告（300x250）
                  UniversalAdWidget(
                    adType: AdType.banner,
                    adUnitId: WebConfig.adUnits.sidebarRectangle,
                  ),
                  const SizedBox(height: 16),
                  // 追加の広告スペース
                  UniversalAdWidget(
                    adType: AdType.banner,
                    adUnitId: WebConfig.adUnits.sidebarRectangle,
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        // モバイルまたは広告なしの場合は通常レイアウト
        return _buildChatContent();
      }
    }
    
    // 準備中画面の場合
    return _buildComingSoonInterface();
  }

  // 準備中画面のUI
  Widget _buildComingSoonInterface() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 工事アイコン
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction,
                  size: 80,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 32),
              
              // タイトル
              Text(
                _currentLang == '日本語' ? 'AIチャット機能 準備中' : 'AI Chat Feature Coming Soon',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 説明文
              Text(
                _currentLang == '日本語' 
                  ? '現在、AIチャット機能を開発中です。\n体操のルールや技について質問できる\n高度なAIアシスタント機能を準備しています。\n\n他の機能（D-Score計算、全種目分析、\nアナリティクス）は通常通りご利用いただけます。'
                  : 'AI Chat feature is currently under development.\nWe are preparing an advanced AI assistant\nthat can answer questions about gymnastics\nrules and techniques.\n\nOther features (D-Score Calculator,\nAll Apparatus Analysis, Analytics)\nare available as usual.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[300],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // 予定表示
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentLang == '日本語' ? 'リリース予定: 近日公開' : 'Release Schedule: Coming Soon',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 以下は既存のチャット機能コード（無効化中）
  Widget _buildDisabledChatInterface() {
    return SafeArea(
      child: Column(
        children: [
          // AIチャット機能の説明バー
          _buildChatInfoBar(),
          // 無料ユーザーにはバナー広告を表示
          if (_userSubscription.shouldShowAds() && _isAdManagerInitialized)
            _buildBannerAd(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _messages[index],
            ),
          ),
          if (_isLoading) const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: CircularProgressIndicator(),
          ),
          // 使用量インジケーター（無料ユーザーのみ）
          if (!_userSubscription.canAccessUnlimitedChat())
            FutureBuilder<String>(
              future: ChatUsageTracker.getUsageStatus(_userSubscription),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      snapshot.data!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[700]!)),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _getText('enterMessage'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (text) => () {}, // 無効化
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {}, // 無効化
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Web版インタースティシャル広告表示
  void _showWebInterstitialAd(String adType) {
    if (!PlatformConfig.isWeb) return;
    
    // 広告表示を記録
    WebAdManager().recordAdShown(adType);
    
    // ダイアログで全画面広告を模擬
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.black.withOpacity(0.8),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.8,
                    constraints: const BoxConstraints(
                      maxWidth: 728,
                      maxHeight: 600,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // 広告ヘッダー
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '広告',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              // 5秒後に閉じるボタンを表示
                              StatefulBuilder(
                                builder: (context, setState) {
                                  int countdown = 5;
                                  Timer.periodic(const Duration(seconds: 1), (timer) {
                                    if (countdown > 0) {
                                      setState(() {
                                        countdown--;
                                      });
                                    } else {
                                      timer.cancel();
                                    }
                                  });
                                  
                                  return countdown > 0
                                      ? Text(
                                          '閉じる ($countdown)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('閉じる'),
                                        );
                                },
                              ),
                            ],
                          ),
                        ),
                        // 広告コンテンツ
                        Expanded(
                          child: UniversalAdWidget(
                            adType: AdType.interstitial,
                            adUnitId: WebConfig.adUnits.responsive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // バナー広告ウィジェット
  Widget _buildBannerAd() {
    if (PlatformConfig.isWeb) {
      // Web版：AdSenseバナー広告を表示
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: UniversalAdWidget(
          adType: AdType.banner,
          adUnitId: WebConfig.adUnits.headerBanner,
        ),
      );
    } else {
      // モバイル版：既存のAdMob実装
      final adWidget = _adManager.createBannerAdWidget();
      
      if (adWidget != null) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: adWidget,
        );
      } else {
        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              '広告読み込み中...',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      }
    }
  }

  // テキスト入力欄
  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(25.0),
        ),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: (text) => _handleSendPressed(),
                decoration: const InputDecoration.collapsed(hintText: 'メッセージを送信'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isLoading ? null : () => _handleSendPressed(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 演技構成を表示するWidgetリストを構築
  List<Widget> _buildRoutineDisplay() {
    List<Widget> widgets = [];
    
    for (int i = 0; i < _routine.length; i++) {
      final skill = _routine[i];
      final connectionGroupId = _connectionGroups[i];
      final isSelected = _selectedSkillIndex == i;
      final isConnected = connectionGroupId != 0;
      final isBeingEdited = _isEditingSkill && _selectedSkillIndex == i;
      
      // 技の行を作成
      widgets.add(
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext dialogContext) {
                return _SkillSelectionDialog(
                  currentSkill: skill,
                  skillList: _skillList,
                  currentLang: _currentLang,
                  apparatus: _selectedApparatus,
                  onSkillSelected: (Skill selectedSkill) {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _routine[i] = selectedSkill;
                      _dScoreResult = null;
                      _selectedSkillIndex = null;
                      _selectedSkill = null;
                    });
                  },
                );
              },
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                // 技番号（シンプルに）
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 技名のコンテナ（より美しく）
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isBeingEdited
                        ? Colors.purple.shade50
                        : isSelected 
                          ? Colors.blue.shade50 
                          : isConnected 
                            ? Colors.orange.shade50 
                            : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBeingEdited
                          ? Colors.purple
                          : isSelected 
                            ? Colors.blue 
                            : isConnected 
                              ? Colors.orange.shade300 
                              : Colors.grey.shade300,
                        width: (isSelected || isBeingEdited) ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            skill.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _routine.removeAt(i);
                              _connectionGroups.removeAt(i);
                              _dScoreResult = null;
                            });
                          },
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // 連続技の線を追加（次の技と連続している場合）
      if (i < _routine.length - 1 && 
          connectionGroupId != 0 && 
          _connectionGroups[i + 1] == connectionGroupId) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 11.0),
            child: Container(
              width: 2,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }
    }
    
    return widgets;
  }
  
  // 連続技グループを考慮してList<List<Skill>>形式に変換
  List<List<Skill>> _convertToGroupedRoutine() {
    if (_routine.isEmpty) return [];
    
    List<List<Skill>> grouped = [];
    List<Skill> currentGroup = [];
    int currentConnectionId = 0;
    
    for (int i = 0; i < _routine.length; i++) {
      final skill = _routine[i];
      final connectionId = _connectionGroups[i];
      
      if (connectionId == 0 || connectionId != currentConnectionId) {
        // 新しいグループを開始
        if (currentGroup.isNotEmpty) {
          grouped.add(List.from(currentGroup));
          currentGroup.clear();
        }
        currentGroup.add(skill);
        currentConnectionId = connectionId;
      } else {
        // 現在のグループに追加
        currentGroup.add(skill);
      }
    }
    
    // 最後のグループを追加
    if (currentGroup.isNotEmpty) {
      grouped.add(currentGroup);
    }
    
    return grouped;
  }
  
  // 計算キャッシュキーを生成
  String _generateCalculationCacheKey(String apparatus, List<List<Skill>> routine) {
    final routineKey = routine.map((group) => 
      group.map((skill) => '${skill.id}_${skill.valueLetter}').join(',')
    ).join('|');
    return '${apparatus}_$routineKey';
  }

  // D-Score計算完了後に全種目と分析タブにデータを自動共有
  void _shareCalculationDataToOtherTabs() {
    if (_selectedApparatus == null || _routine.isEmpty || _dScoreResult == null) {
      return;
    }

    try {
      // 全種目一覧用のデータも更新
      _allRoutines[_selectedApparatus!] = List.from(_routine);
      _allConnectionGroups[_selectedApparatus!] = List.from(_connectionGroups);
      _allNextConnectionGroupIds[_selectedApparatus!] = _nextConnectionGroupId;
      // 全種目タブ用のデータ構造を作成
      final apparatusData = {
        'apparatus': _selectedApparatus!,
        'routine': _routine.map((skill) => {
          'name': skill.name,
          'value': skill.value,
          'valueLetter': skill.valueLetter,
          'group': skill.group,
          'id': skill.id,
        }).toList(),
        'dScoreResult': {
          'dScore': _dScoreResult!.totalDScore,
          'difficultyValue': _dScoreResult!.difficultyValue,
          'groupBonus': _dScoreResult!.groupBonus,
          'connectionBonus': _dScoreResult!.connectionBonus,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'connectionGroups': _connectionGroups,
      };

      // 分析データを生成（既存の分析ロジックを使用）
      final analysisData = _generateRoutineAnalysis();

      // データを共有状態として保存
      _lastSharedCalculationData = apparatusData;
      _lastSharedAnalysisData = analysisData;

      print('計算データを全種目・分析タブに共有しました: ${_selectedApparatus}');
      
    } catch (e) {
      print('データ共有でエラーが発生しました: $e');
    }
  }

  // 現在の演技構成から分析データを生成
  RoutineAnalysis _generateRoutineAnalysis() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      // デフォルトの空分析データを返す
      return RoutineAnalysis(
        apparatus: _selectedApparatus ?? 'Unknown',
        timestamp: DateTime.now(),
        difficultyDistribution: {},
        groupDistribution: {},
        connectionBonusRatio: 0.0,
        totalSkills: 0,
        averageDifficulty: 0.0,
        completenessScore: 0.0,
        missingGroups: [],
        recommendations: {},
      );
    }

    try {
      // 基本統計の計算
      final stats = RoutineAnalyzer.analyzeRoutineStatistics(_routine);
      final groupDistribution = RoutineAnalyzer.calculateGroupDistribution(_routine);
      
      // 要求充足率の計算
      final List<String> missingGroups = [];
      final totalRequiredGroups = 5; // 体操では通常5グループ
      final completenessScore = groupDistribution.length / totalRequiredGroups;
      
      // 不足グループの特定
      for (int i = 1; i <= totalRequiredGroups; i++) {
        if (!groupDistribution.containsKey(i) || groupDistribution[i] == 0) {
          missingGroups.add('グループ$i');
        }
      }
      
      // 改善案の生成
      final List<String> suggestions = [];
      if (missingGroups.isNotEmpty) {
        suggestions.add('不足グループを補完してください: ${missingGroups.join('、')}');
      }
      if (stats['averageDifficulty'] < 0.3) {
        suggestions.add('より高難度の技を追加することを検討してください');
      }
      
      final recommendations = {
        'suggestions': suggestions,
        'priority': suggestions.isNotEmpty ? 'high' : 'low',
      };
      
      return RoutineAnalysis(
        apparatus: _selectedApparatus!,
        timestamp: DateTime.now(),
        difficultyDistribution: stats['difficultyDistribution'] as Map<String, int>? ?? {},
        groupDistribution: groupDistribution.map((key, value) => MapEntry(key, value)),
        connectionBonusRatio: (_dScoreResult?.connectionBonus ?? 0.0) / 0.4, // 0.4が最大連続ボーナス
        totalSkills: _routine.length,
        averageDifficulty: stats['averageDifficulty'] as double? ?? 0.0,
        completenessScore: completenessScore,
        missingGroups: missingGroups,
        recommendations: recommendations,
      );
      
    } catch (e) {
      print('分析データ生成でエラーが発生しました: $e');
      // エラー時も基本的な分析データを返す
      return RoutineAnalysis(
        apparatus: _selectedApparatus!,
        timestamp: DateTime.now(),
        difficultyDistribution: {},
        groupDistribution: {},
        connectionBonusRatio: 0.0,
        totalSkills: _routine.length,
        averageDifficulty: 0.0,
        completenessScore: 0.0,
        missingGroups: [],
        recommendations: {'suggestions': [], 'priority': 'low'},
      );
    }
  }
  Widget _buildSharedAnalysisCard() {
    if (_lastSharedAnalysisData == null) return Container();
    
    final analysis = _lastSharedAnalysisData!;
    
    return Card(
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.purple.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '自動生成された分析結果',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  Chip(
                    label: Text(
                      analysis.apparatus,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.orange.shade600,
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('技数:', style: TextStyle(color: Colors.white70)),
                        Text(
                          '${analysis.totalSkills}技',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('平均難度:', style: TextStyle(color: Colors.white70)),
                        Text(
                          analysis.averageDifficulty.toStringAsFixed(2),
                          style: TextStyle(
                            color: Colors.blue.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('要求充足率:', style: TextStyle(color: Colors.white70)),
                        Text(
                          '${(analysis.completenessScore * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: analysis.completenessScore >= 1.0 
                                ? Colors.green.shade300 
                                : Colors.orange.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (analysis.missingGroups.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '不足: ${analysis.missingGroups.join('、')}',
                                style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'D-Score計算完了時に自動生成されました',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // 保存された演技構成を読み込み
  Future<void> _loadSavedRoutines() async {
    try {
      String? routinesData;
      
      if (kIsWeb) {
        // Web版ではLocalStorageを使用
        // ignore: avoid_web_libraries_in_flutter
        // ignore: undefined_prefixed_name
        routinesData = (await SharedPreferences.getInstance()).getString('saved_routines');
      } else {
        // モバイル版では従来のflutter_secure_storageを使用
        routinesData = await _storage.read(key: 'saved_routines');
      }
      
      if (routinesData != null) {
        final Map<String, dynamic> decoded = json.decode(routinesData);
        setState(() {
          _savedRoutines.clear();
          decoded.forEach((key, value) {
            _savedRoutines[key] = Map<String, dynamic>.from(value);
          });
        });
      }
    } catch (e) {
      print('Error loading saved routines: $e');
    }
  }
  
  // キャッシュ統計情報を取得
  Future<void> _fetchCacheStats() async {
    setState(() {
      _isLoadingCacheStats = true;
    });
    
    try {
      final response = await _makeApiRequest('/cache/stats');
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      
      setState(() {
        _cacheStats = data;
      });
      
      _showSuccessSnackBar('キャッシュ統計情報を取得しました');
      
    } on NetworkException catch (e) {
      _showErrorDialog(
        'ネットワークエラー',
        e.message,
        onRetry: _fetchCacheStats,
      );
    } on AuthenticationException catch (e) {
      _showErrorDialog(
        '認証エラー',
        e.message,
        onRetry: () {
          // Authentication will be handled by _handleUnauthorized()
        },
      );
    } on DataException catch (e) {
      _showErrorSnackBar('データエラー: ${e.message}');
    } catch (e) {
      print('Error fetching cache stats: $e');
      _showErrorDialog(
        'エラー',
        'キャッシュ統計情報の取得に失敗しました: $e',
        onRetry: _fetchCacheStats,
      );
    } finally {
      setState(() {
        _isLoadingCacheStats = false;
      });
    }
  }
  
  // キャッシュをクリア
  Future<void> _clearCache() async {
    try {
      final response = await _makeApiRequest(
        '/cache/clear',
        method: 'POST',
        additionalHeaders: {'Content-Type': 'application/json'},
      );
      
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _showSuccessSnackBar('キャッシュをクリアしました: ${data['message'] ?? 'キャッシュクリア完了'}');
      
      // キャッシュクリア後、統計情報を再取得
      await _fetchCacheStats();
      
    } on NetworkException catch (e) {
      _showErrorDialog(
        'ネットワークエラー',
        e.message,
        onRetry: _clearCache,
      );
    } on AuthenticationException catch (e) {
      _showErrorDialog(
        '認証エラー',
        e.message,
        onRetry: () {
          // Authentication will be handled by _handleUnauthorized()
        },
      );
    } on DataException catch (e) {
      _showErrorSnackBar('データエラー: ${e.message}');
    } catch (e) {
      print('Error clearing cache: $e');
      _showErrorDialog(
        'エラー',
        'キャッシュクリアに失敗しました: $e',
        onRetry: _clearCache,
      );
    }
  }
  
  // 現在の演技構成を保存
  Future<void> _saveCurrentRoutine() async {
    if (_selectedApparatus == null || _routine.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => _SaveRoutineDialog(
        currentLang: _currentLang,
        onSave: (name) async {
          try {
            final routineData = {
              'name': name,
              'apparatus': _selectedApparatus!,
              'routine': _routine.map((skill) => {
                'id': skill.id,
                'name': skill.name,
                'group': skill.group,
                'valueLetter': skill.valueLetter,
                'description': skill.description,
                'apparatus': skill.apparatus,
                'value': skill.value,
              }).toList(),
              'connectionGroups': _connectionGroups,
              'nextConnectionGroupId': _nextConnectionGroupId,
              'savedAt': DateTime.now().toIso8601String(),
            };
            
            final key = '${_selectedApparatus!}_${DateTime.now().millisecondsSinceEpoch}';
            _savedRoutines[key] = routineData;
            
            // プラットフォーム別ストレージに保存
            if (kIsWeb) {
              // Web版ではSharedPreferencesを使用
              (await SharedPreferences.getInstance()).setString('saved_routines', json.encode(_savedRoutines));
            } else {
              // モバイル版では従来のflutter_secure_storageを使用
              await _storage.write(
                key: 'saved_routines',
                value: json.encode(_savedRoutines),
              );
            }
            
            setState(() {});
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('演技構成「$name」を保存しました'),
                backgroundColor: Colors.green,
              ),
            );
            
            // Web版での保存完了時広告
            if (PlatformConfig.isWeb && _userSubscription.shouldShowAds()) {
              if (WebAdManager().shouldShowSaveCompletedAd()) {
                Future.delayed(const Duration(milliseconds: 2000), () {
                  _showWebInterstitialAd('save_completed');
                });
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存中にエラーが発生しました: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
  
  // 保存された演技構成を読み込み
  Future<void> _loadSavedRoutine(String key) async {
    try {
      final routineData = _savedRoutines[key];
      if (routineData == null) return;
      
      final apparatus = routineData['apparatus'];
      final routineList = routineData['routine'] as List;
      final connectionGroups = List<int>.from(routineData['connectionGroups'] ?? []);
      final nextConnectionGroupId = routineData['nextConnectionGroupId'] ?? 1;
      
      // 技データを復元
      final skills = routineList.map((skillData) => Skill(
        id: skillData['id'],
        name: skillData['name'],
        group: skillData['group'],
        valueLetter: skillData['valueLetter'],
        description: skillData['description'],
        apparatus: skillData['apparatus'],
        value: skillData['value'],
      )).toList();
      
      setState(() {
        _selectedApparatus = apparatus;
        _routine = skills;
        _connectionGroups = connectionGroups;
        _nextConnectionGroupId = nextConnectionGroupId;
        _dScoreResult = null;
      });
      
      // 技データをロード
      await _loadSkills(apparatus);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('演技構成「${routineData['name']}」を読み込みました'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('読み込み中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 保存された演技構成を削除
  Future<void> _deleteSavedRoutine(String key) async {
    try {
      _savedRoutines.remove(key);
      
      // プラットフォーム別ストレージに保存
      if (kIsWeb) {
        // Web版ではSharedPreferencesを使用
        (await SharedPreferences.getInstance()).setString('saved_routines', json.encode(_savedRoutines));
      } else {
        // モバイル版では従来のflutter_secure_storageを使用
        await _storage.write(
          key: 'saved_routines',
          value: json.encode(_savedRoutines),
        );
      }
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('演技構成を削除しました'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('削除中にエラーが発生しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 保存された演技構成一覧を表示
  void _showSavedRoutines() {
    showDialog(
      context: context,
      builder: (context) => _SavedRoutinesDialog(
        savedRoutines: _savedRoutines,
        onLoad: _loadSavedRoutine,
        onDelete: _deleteSavedRoutine,
        currentLang: _currentLang,
      ),
    );
  }

  // 全種目一覧表示画面
  Widget _buildAllApparatusInterface() {
    final langCode = _currentLang == '日本語' ? 'ja' : 'en';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // シンプルなタイトル
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _getText('allApparatus'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 合計得点カード
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    '合計 Dスコア',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_calculateTotalDScore().toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade300,
                    ),
                  ),
                  const Text(
                    '点',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 6種目カード一覧
          ...(_apparatusData.keys.map((apparatus) => _buildApparatusCard(apparatus, langCode)).toList()),
        ],
      ),
    );
  }
  
  // 各種目カードの構築
  Widget _buildApparatusCard(String apparatus, String langCode) {
    final routineData = _allRoutines[apparatus] ?? [];
    final scoreResult = _allDScoreResults[apparatus];
    final apparatusName = _apparatusData[apparatus]![langCode]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _navigateToApparatusEdit(apparatus);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getApparatusIcon(apparatus),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apparatusName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${routineData.length}技登録済み',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          scoreResult?.dScore.toStringAsFixed(3) ?? '0.000',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: scoreResult != null ? Colors.green.shade300 : Colors.white70,
                          ),
                        ),
                        const Text(
                          '点',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                if (routineData.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  const Text(
                    '登録技:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: routineData.take(5).map((skill) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Text(
                        skill.name,
                        style: const TextStyle(fontSize: 10),
                      ),
                    )).toList(),
                  ),
                  if (routineData.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '他${routineData.length - 5}技...',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
                
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'タップして編集',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 分析画面のインターフェイス
  Widget _buildAnalyticsInterface() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // タイトル
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              _getText('routineAnalysis'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 分析対象選択
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分析対象種目',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedApparatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('分析する種目を選択'),
                    items: _apparatusData.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text('${entry.value['ja']} (${entry.key})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedApparatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedApparatus != null ? _analyzeCurrentRoutine : null,
                      child: _isAnalyzing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('分析開始'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 分析結果表示
          if (_currentAnalysis != null) _buildAnalysisResults(),
          
          const SizedBox(height: 20),
          
          // 分析情報バー
          if (_currentAnalysis != null) _buildAnalysisInfoBar(),
          
          const SizedBox(height: 16),
          
          // 分析AIチャット機能
          if (_currentAnalysis != null) _buildAnalysisChat(),
        ],
      ),
    );
  }

  // 現在の演技構成を分析
  Future<void> _analyzeCurrentRoutine() async {
    if (_selectedApparatus == null) return;
    
    setState(() {
      _isAnalyzing = true;
    });
    
    try {
      final routine = _allRoutines[_selectedApparatus!] ?? [];
      final analysis = await _performRoutineAnalysis(_selectedApparatus!, routine);
      
      setState(() {
        _currentAnalysis = analysis;
        // 分析完了時に自動的に改善案を提示
        _initializeAnalyticsChat(analysis);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析中にエラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // 演技構成の分析を実行（簡素化版）
  Future<RoutineAnalysis> _performRoutineAnalysis(String apparatus, List<Skill> routine) async {
    // 基本統計のみ計算
    final stats = RoutineAnalyzer.analyzeRoutineStatistics(routine);
    final groupDistribution = RoutineAnalyzer.calculateGroupDistribution(routine);
    
    // 要求充足率の計算
    final requiredGroups = _getRequiredGroups(apparatus);
    final presentGroups = groupDistribution.keys.toSet();
    final fulfillmentRate = presentGroups.intersection(requiredGroups).length / requiredGroups.length;
    
    // 不足グループ特定（要求充足率計算用）
    final missingGroups = requiredGroups.difference(presentGroups)
        .map((group) => 'グループ$group')
        .toList();
    
    // 改善提案生成
    final suggestions = RoutineAnalyzer.generateImprovementSuggestions(
      apparatus, 
      routine, 
      groupDistribution, 
      {} // 難度分布は不要なので空のMapを渡す
    );
    
    final recommendations = {
      'suggestions': suggestions,
      'priority': suggestions.isNotEmpty ? 'high' : 'low',
    };
    
    return RoutineAnalysis(
      apparatus: apparatus,
      timestamp: DateTime.now(),
      difficultyDistribution: {}, // 削除：難度分布は表示しない
      groupDistribution: {}, // 削除：グループ別技数は表示しない
      connectionBonusRatio: 0.0, // 簡素化
      totalSkills: routine.length,
      averageDifficulty: stats['averageDifficulty'] as double,
      completenessScore: fulfillmentRate, // 要求充足率として使用
      missingGroups: missingGroups,
      recommendations: recommendations,
    );
  }

  // 種目に必要なグループを取得（体操競技）
  Set<int> _getRequiredGroups(String apparatus) {
    switch (apparatus) {
      case 'VT':
        return {1, 2, 3, 4, 5}; // 跳馬は5グループ存在
      default:
        return {1, 2, 3, 4}; // 他の種目は4グループ要求
    }
  }


  // 分析結果の表示
  Widget _buildAnalysisResults() {
    final analysis = _currentAnalysis!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 簡素化された概要カード
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分析概要',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('技数', analysis.totalSkills.toString()),
                    const SizedBox(width: 16),
                    _buildStatCard('平均難度', analysis.averageDifficulty.toStringAsFixed(2)),
                    const SizedBox(width: 16),
                    _buildStatCard('要求充足率', '${(analysis.completenessScore * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 改善案提案チャット
        _buildImprovementChat(analysis),
      ],
    );
  }

  // 分析情報バー
  Widget _buildAnalysisInfoBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[900]!, Colors.blue[700]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[400]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[200], size: 20),
              const SizedBox(width: 8),
              Text(
                'この分析について質問する',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '下のAIチャットで現在の分析結果について詳しく質問できます。',
            style: TextStyle(
              color: Colors.blue[100],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildInfoChip('💪', 'グループ別技構成'),
              _buildInfoChip('📈', '難度向上提案'), 
              _buildInfoChip('🔗', '連続ボーナス最適化'),
              _buildInfoChip('🎯', '技術的アドバイス'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[800]!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber[300], size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '例：「グループ3のB難度何がある？」「不足しているグループは？」',
                    style: TextStyle(
                      color: Colors.blue[50],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 情報チップ
  Widget _buildInfoChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 分析AIチャット機能（高度な体操専門知識対応）
  Widget _buildAnalysisChat() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '分析AIチャット',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_done, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'オンライン',
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '現在の分析結果について質問してください。例：「グループ3のB難度何がある？」',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _analyticsScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _analyticsMessages.length,
                      itemBuilder: (context, index) {
                        final message = _analyticsMessages[index];
                        return _buildAnalyticsMessage(message);
                      },
                    ),
                  ),
                  if (_isAnalyticsLoading)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'AI分析中...',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _analyticsController,
                    decoration: InputDecoration(
                      hintText: '分析について質問する...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    style: TextStyle(color: Colors.white),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty && _currentAnalysis != null) {
                        _sendAnalyticsMessage(text.trim(), _currentAnalysis!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    final text = _analyticsController.text.trim();
                    if (text.isNotEmpty && _currentAnalysis != null) {
                      _sendAnalyticsMessage(text, _currentAnalysis!);
                    }
                  },
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.send, color: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildQuickActionChip('グループ3のB難度一覧'),
                _buildQuickActionChip('不足しているグループは何？'),
                _buildQuickActionChip('難度を上げるには？'),
                _buildQuickActionChip('連続ボーナスのアドバイス'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // クイックアクションチップ
  Widget _buildQuickActionChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.white),
      ),
      backgroundColor: Colors.grey[800],
      onPressed: () {
        if (_currentAnalysis != null) {
          _sendAnalyticsMessage(text, _currentAnalysis!);
        }
      },
    );
  }

  // 改善案提案チャット機能
  Widget _buildImprovementChat(RoutineAnalysis analysis) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '改善案相談',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _analyticsMessages.length,
                      itemBuilder: (context, index) {
                        final message = _analyticsMessages[index];
                        return _buildAnalyticsMessage(message);
                      },
                    ),
                  ),
                  if (_isAnalyticsLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[700]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _analyticsController,
                            decoration: const InputDecoration(
                              hintText: '改善について相談してください...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (text) => _sendAnalyticsMessage(text, analysis),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _sendAnalyticsMessage(_analyticsController.text, analysis),
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '演技構成について質問やご相談がありましたらお気軽にどうぞ！',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // 分析チャットメッセージのウィジェット
  Widget _buildAnalyticsMessage(AnalyticsMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: message.isUser ? Colors.blue : Colors.green,
            child: Icon(
              message.isUser ? Icons.person : Icons.psychology,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 分析メッセージの送信
  void _sendAnalyticsMessage(String text, RoutineAnalysis analysis) {
    if (text.trim().isEmpty) return;

    setState(() {
      _analyticsMessages.add(AnalyticsMessage(text: text, isUser: true));
      _isAnalyticsLoading = true;
    });

    _analyticsController.clear();

    // AIの応答を生成（実際の分析に基づく）
    _generateAnalyticsResponse(text, analysis);
  }

  // AI応答の生成（高度な体操専門知識対応）
  void _generateAnalyticsResponse(String userInput, RoutineAnalysis analysis) {
    final lowerInput = userInput.toLowerCase();
    String response = '';
    
    // 高度な質問パターンマッチング
    if (lowerInput.contains('グループ') && lowerInput.contains('b難度')) {
      response = _handleGroupDifficultyQuery(userInput, analysis);
    } else if (lowerInput.contains('グループ') && RegExp(r'[1-5]').hasMatch(lowerInput)) {
      response = _handleSpecificGroupQuery(userInput, analysis);
    } else if (lowerInput.contains('連続') || lowerInput.contains('ボーナス')) {
      response = _handleConnectionBonusQuery(analysis);
    } else if (lowerInput.contains('不足') || lowerInput.contains('足りない')) {
      response = _handleMissingElementsQuery(analysis);
    } else if (lowerInput.contains('難度') && (lowerInput.contains('上げ') || lowerInput.contains('向上'))) {
      response = _handleDifficultyUpgradeQuery(analysis);
    } else if (lowerInput.contains('技') && (lowerInput.contains('追加') || lowerInput.contains('増や'))) {
      response = _handleSkillAdditionQuery(analysis);
    } else {
      // 一般的な質問に対するコンテキスト回答
      response = _handleGeneralAnalyticsQuery(lowerInput, analysis);
    }

    // サーバーベースのAI回答を模擬（実際の実装ではAPI呼び出し）
    _processAdvancedAnalyticsResponse(userInput, response);
  }

  // 高度なAI回答処理（サーバー連携）
  Future<void> _processAdvancedAnalyticsResponse(String userInput, String fallbackResponse) async {
    try {
      // 体操専門知識データベースから詳細回答を取得
      final expertResponse = GymnasticsExpertDatabase.getExpertAnswer(userInput);
      
      // 現在の分析データと組み合わせて回答を生成
      String contextualResponse = _combineExpertResponseWithAnalysis(expertResponse, _currentAnalysis!);
      
      // 実際のサーバー連携時間を模擬
      await Future.delayed(const Duration(milliseconds: 2000));
      
      setState(() {
        _analyticsMessages.add(AnalyticsMessage(text: contextualResponse, isUser: false));
        _isAnalyticsLoading = false;
      });
    } catch (e) {
      // フォールバック回答
      await Future.delayed(const Duration(milliseconds: 1500));
      setState(() {
        _analyticsMessages.add(AnalyticsMessage(text: fallbackResponse, isUser: false));
        _isAnalyticsLoading = false;
      });
    }
  }

  // 専門知識と分析データの組み合わせ
  String _combineExpertResponseWithAnalysis(String expertResponse, RoutineAnalysis analysis) {
    if (expertResponse.contains('サーバー接続が必要です')) {
      // オンライン必須回答をより詳細な分析ベース回答に置き換え
      return '''🎯 **分析ベース回答**

現在の演技構成分析：
• **技数**: ${analysis.totalSkills}技
• **平均難度**: ${analysis.averageDifficulty.toStringAsFixed(2)}
• **要求充足率**: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%
• **連続ボーナス**: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%

**📚 専門知識が必要な質問**
より詳細な技術情報が必要です。以下をお試しください：

🔸 **グループ別技構成**: 各グループの技分布
🔸 **難度向上提案**: 現在の構成から無理なくレベルアップ
🔸 **連続ボーナス最適化**: CV獲得のための技順序

**💡 具体的な質問例:**
• "このルーティンの弱点は？"
• "C難度技を追加するなら？"
• "連続ボーナスを増やすには？"

現在の分析結果を基に、より具体的にご質問ください！''';
    }
    
    // 専門知識回答に現在の分析データを追加
    return '''$expertResponse

**📊 現在の演技分析との関連：**
• 技数: ${analysis.totalSkills}技 (理想: 8-10技)
• 平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}
• 要求充足率: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%
${analysis.missingGroups.isNotEmpty ? "• 不足グループ: ${analysis.missingGroups.join('、')}" : "• ✅ 全グループ要求充足"}''';
  }

  // グループ別難度クエリ処理
  String _handleGroupDifficultyQuery(String query, RoutineAnalysis analysis) {
    final groupNumber = RegExp(r'グループ([1-5])').firstMatch(query)?.group(1);
    if (groupNumber != null) {
      return '''🎯 **グループ${groupNumber}のB難度技**

【${analysis.apparatus}・グループ${groupNumber}】

**📋 代表的なB難度技 (0.2点):**
• 種目により異なりますが、一般的なB難度技をご紹介します
• より具体的な技名は種目別に確認が必要です

**📊 現在の構成での${groupNumber}グループ:**
${analysis.groupDistribution[int.parse(groupNumber)] != null ? 
"現在${analysis.groupDistribution[int.parse(groupNumber)]}技を使用中" :
"このグループの技は未使用です"}

**💡 アドバイス:**
B難度技はD-scoreの基礎となる重要な技です。
安定して実施できるB難度技から段階的に習得しましょう！''';
    }
    return 'グループ番号を指定して再度質問してください（例：グループ3のB難度）';
  }

  // 特定グループクエリ処理
  String _handleSpecificGroupQuery(String query, RoutineAnalysis analysis) {
    final groupNumber = RegExp(r'[1-5]').firstMatch(query)?.group(0);
    if (groupNumber != null) {
      final groupCount = analysis.groupDistribution[int.parse(groupNumber)] ?? 0;
      return '''🎯 **グループ${groupNumber}の詳細分析**

**📊 現在の状況:**
• 使用技数: ${groupCount}技
• グループ要求: ${groupCount > 0 ? "✅ 充足" : "❌ 不足"}

**🎯 グループ${groupNumber}の特徴:**
${_getGroupDescription(int.parse(groupNumber), analysis.apparatus)}

**💡 改善提案:**
${groupCount == 0 ? 
"このグループの技を1技以上追加することで0.5点のボーナスを獲得できます！" :
"十分な技数があります。より高難度技への挑戦を検討しましょう。"}''';
    }
    return '特定のグループ番号を指定してください（1-5）';
  }

  // 連続ボーナスクエリ処理
  String _handleConnectionBonusQuery(RoutineAnalysis analysis) {
    return '''🔗 **連続ボーナス（CV）分析**

**📊 現在の状況:**
• 連続ボーナス率: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%
• 最大可能: 0.4点

**⚡️ CV獲得の基本ルール:**
• C+D: +0.1点
• D+D: +0.2点  
• D+E: +0.2点
• E+E: +0.2点

**💡 最適化のコツ:**
1. 技と技の間に停止を作らない
2. 着地で中断すると連続認定されない
3. 演技の流れを重視した構成

現在の構成で連続可能な技の組み合わせを見直してみましょう！''';
  }

  // 不足要素クエリ処理
  String _handleMissingElementsQuery(RoutineAnalysis analysis) {
    if (analysis.missingGroups.isEmpty) {
      return '''✅ **要求充足完了**

すべてのグループ要求を満たしています！
現在の要求充足率: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%

**🎯 次のステップ:**
• より高難度技への挑戦
• 連続ボーナスの最適化
• 演技の芸術性向上''';
    }
    
    return '''❌ **不足要素の分析**

**🚨 不足しているグループ:**
${analysis.missingGroups.map((group) => "• $group").join('\n')}

**💰 失われているボーナス:**
${analysis.missingGroups.length * 0.5}点（各グループ0.5点×${analysis.missingGroups.length}）

**💡 優先改善提案:**
1. 最も習得しやすいグループから追加
2. 現在の技レベルに合った難度選択
3. 演技全体のバランスを考慮

どのグループから改善したいか教えてください！''';
  }

  // 難度向上クエリ処理  
  String _handleDifficultyUpgradeQuery(RoutineAnalysis analysis) {
    return '''📈 **難度向上戦略**

**📊 現在の難度状況:**
• 平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}
• 総技数: ${analysis.totalSkills}技

**🎯 向上戦略:**
1. **段階的アップグレード**: 現在のA→B、B→Cに変更
2. **技数最適化**: 8技以上で構成（上位8技がカウント）
3. **バランス重視**: 全グループから均等に選択

**💡 効率的な方法:**
• 得意な技から難度を上げる
• 安全性を最優先に選択
• 連続ボーナスも考慮した配置

具体的にどの技をアップグレードしたいですか？''';
  }

  // 技追加クエリ処理
  String _handleSkillAdditionQuery(RoutineAnalysis analysis) {
    return '''➕ **技追加の戦略的アプローチ**

**📊 現在の構成:**
• 技数: ${analysis.totalSkills}技
• 推奨技数: 8-10技（上位8技がD-scoreに反映）

**🎯 追加優先度:**
1. **不足グループ**: ${analysis.missingGroups.isNotEmpty ? analysis.missingGroups.join('、') : "なし"}
2. **高難度技**: 現在の平均${analysis.averageDifficulty.toStringAsFixed(2)}以上
3. **連続可能技**: CV獲得のため

**💡 選択基準:**
• 安全に実施可能な技
• 演技の流れに適合
• グループ要求を満たす技

どのグループの技を追加したいか、具体的に教えてください！''';
  }

  // 一般クエリ処理
  String _handleGeneralAnalyticsQuery(String lowerInput, RoutineAnalysis analysis) {
    if (lowerInput.contains('弱点') || lowerInput.contains('問題')) {
      final issues = <String>[];
      if (analysis.missingGroups.isNotEmpty) issues.add('グループ要求不足');
      if (analysis.averageDifficulty < 0.3) issues.add('難度が低い');
      if (analysis.connectionBonusRatio < 0.5) issues.add('連続ボーナス未活用');
      
      return '''🔍 **演技の弱点分析**

${issues.isNotEmpty ? 
"**⚠️ 主な改善点:**\n${issues.map((issue) => "• $issue").join('\n')}" :
"**✅ 良好な構成です！**"}

**📊 詳細分析:**
• 完成度: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%
• 技数バランス: ${analysis.totalSkills >= 8 ? "適切" : "不足"}
• 難度分布: 平均${analysis.averageDifficulty.toStringAsFixed(2)}

さらに詳しい改善提案が必要でしたら、具体的な項目を教えてください！''';
    }
    
    return '''💬 **分析サマリー**

**📊 現在の演技状況:**
• 技数: ${analysis.totalSkills}技
• 平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}
• 要求充足率: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%
• 連続ボーナス活用率: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%

**🎯 質問例:**
• "不足しているグループは？"
• "難度を上げるには？"  
• "連続ボーナスのコツは？"
• "グループ3の技一覧"

何について詳しく知りたいですか？''';
  }

  // グループ説明の取得
  String _getGroupDescription(int groupNumber, String apparatus) {
    // 種目別のグループ特徴説明（簡略版）
    final descriptions = {
      1: "基本的な動作・姿勢グループ",
      2: "回転・ひねり系技グループ", 
      3: "宙返り・跳躍系技グループ",
      4: "複合・応用技グループ",
      5: "終末技・特殊技グループ",
    };
    return descriptions[groupNumber] ?? "詳細な技術情報";
  }

  // 分析チャットの初期化
  void _initializeAnalyticsChat(RoutineAnalysis analysis) {
    _analyticsMessages.clear();
    
    // 専門知識データベースから改善案を生成
    final expertSuggestions = GymnasticsKnowledgeBase.generateImprovementSuggestions(
      _selectedApparatus!,
      analysis,
    );
    
    String initialMessage = '📊 **分析完了**\n\n';
    initialMessage += '【現在の状況】\n';
    initialMessage += '・技数: ${analysis.totalSkills}技\n';
    initialMessage += '・平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}\n';
    initialMessage += '・要求充足率: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%\n\n';
    
    initialMessage += expertSuggestions;
    
    _analyticsMessages.add(AnalyticsMessage(text: initialMessage, isUser: false));
  }

  // 統計カード
  Widget _buildStatCard(String title, String value, [IconData? icon]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 4),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 総合評価スコアカード
  Widget _buildOverallScoreCard(double score) {
    Color scoreColor;
    String scoreText;
    
    if (score >= 0.8) {
      scoreColor = Colors.green;
      scoreText = '優秀';
    } else if (score >= 0.6) {
      scoreColor = Colors.orange;
      scoreText = '良好';
    } else if (score >= 0.4) {
      scoreColor = Colors.yellow;
      scoreText = '改善要';
    } else {
      scoreColor = Colors.red;
      scoreText = '要見直し';
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            '総合評価',
            style: TextStyle(
              fontSize: 14,
              color: scoreColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(score * 100).toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '点',
                    style: TextStyle(
                      fontSize: 14,
                      color: scoreColor,
                    ),
                  ),
                  Text(
                    scoreText,
                    style: TextStyle(
                      fontSize: 12,
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
        ],
      ),
    );
  }

  // 難度分布の円グラフ
  Widget _buildDifficultyChart() {
    final analysis = _currentAnalysis!;
    if (analysis.difficultyDistribution.isEmpty) {
      return const Center(
        child: Text('データがありません', style: TextStyle(color: Colors.white70)),
      );
    }
    
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.yellow.shade400,
      Colors.green.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
    ];
    
    final sections = analysis.difficultyDistribution.entries.map((entry) {
      final index = analysis.difficultyDistribution.keys.toList().indexOf(entry.key);
      final color = colors[index % colors.length];
      
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
    
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  // グループ別技数の棒グラフ
  Widget _buildGroupChart() {
    final analysis = _currentAnalysis!;
    if (analysis.groupDistribution.isEmpty) {
      return const Center(
        child: Text('データがありません', style: TextStyle(color: Colors.white70)),
      );
    }
    
    final maxValue = analysis.groupDistribution.values.reduce((a, b) => a > b ? a : b).toDouble();
    final barGroups = analysis.groupDistribution.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.blue.shade400,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
    
    return BarChart(
      BarChartData(
        barGroups: barGroups,
        maxY: maxValue + 1,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  'G${value.toInt()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: false,
        ),
      ),
    );
  }
  
  // 各種目のアイコンを返す
  Widget _getApparatusIcon(String apparatus) {
    IconData iconData;
    Color iconColor;
    
    switch (apparatus) {
      case 'FX':
        iconData = Icons.grid_4x4;
        iconColor = Colors.red.shade600;
        break;
      case 'PH':
        iconData = Icons.sports;
        iconColor = Colors.orange.shade600;
        break;
      case 'SR':
        iconData = Icons.circle;
        iconColor = Colors.yellow.shade700;
        break;
      case 'VT':
        iconData = Icons.arrow_upward;
        iconColor = Colors.green.shade600;
        break;
      case 'PB':
        iconData = Icons.horizontal_rule;
        iconColor = Colors.blue.shade600;
        break;
      case 'HB':
        iconData = Icons.horizontal_rule;
        iconColor = Colors.purple.shade600;
        break;
      default:
        iconData = Icons.sports_gymnastics;
        iconColor = Colors.grey.shade600;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        size: 24,
        color: iconColor,
      ),
    );
  }
  
  // 合計Dスコアを計算
  double _calculateTotalDScore() {
    double total = 0.0;
    for (final result in _allDScoreResults.values) {
      if (result != null) {
        total += result.dScore;
      }
    }
    return total;
  }
  
  // フィルタリングされた技リストを取得
  List<Skill> _getFilteredSkillList() {
    return _skillList.where((skill) {
      // テキスト検索フィルタ
      bool matchesSearch = _skillSearchQuery.isEmpty ||
          _matchesSearchQuery(skill.name, _skillSearchQuery) ||
          skill.valueLetter.toLowerCase().contains(_skillSearchQuery.toLowerCase()) ||
          skill.group.toString().contains(_skillSearchQuery);
      
      // グループフィルタ
      bool matchesGroup = _selectedGroupFilter == null || 
          skill.group == _selectedGroupFilter;
      
      // 難度フィルタ
      bool matchesDifficulty = _selectedDifficultyFilter == null || 
          skill.valueLetter.toUpperCase() == _selectedDifficultyFilter!.toUpperCase();
      
      return matchesSearch && matchesGroup && matchesDifficulty;
    }).toList();
  }
  
  // ページネーション対応の技リスト取得
  List<Skill> _getPaginatedSkillList() {
    final allFilteredSkills = _getFilteredSkillList();
    final startIndex = _currentSkillPage * _skillsPerPage;
    final endIndex = (startIndex + _skillsPerPage).clamp(0, allFilteredSkills.length);
    
    if (startIndex >= allFilteredSkills.length) {
      return [];
    }
    
    return allFilteredSkills.sublist(startIndex, endIndex);
  }
  
  // 総ページ数を計算
  int _getTotalPages() {
    final totalSkills = _getFilteredSkillList().length;
    return (totalSkills / _skillsPerPage).ceil();
  }
  
  // ページリセット（検索やフィルタ変更時に使用）
  void _resetSkillPagination() {
    setState(() {
      _currentSkillPage = 0;
    });
  }
  
  // 技のバッジを作成
  Widget _buildSkillBadge(String text, MaterialColor color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 8, 
        vertical: isMobile ? 2 : 4
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 10 : 12,
          fontWeight: FontWeight.w500,
          color: color[700],
        ),
      ),
    );
  }

  // コンパクトなスキルバッジ（技選択画面用）
  Widget _buildCompactSkillBadge(String text, MaterialColor color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 5, 
        vertical: 1
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 9 : 10,
          fontWeight: FontWeight.w500,
          color: color[600],
        ),
      ),
    );
  }
  
  // 難度に応じた色を取得
  MaterialColor _getDifficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'A':
      case 'B':
        return Colors.green;
      case 'C':
      case 'D':
        return Colors.blue;
      case 'E':
      case 'F':
        return Colors.orange;
      case 'G':
      case 'H':
        return Colors.red;
      case 'I':
      case 'J':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  // ひらがな・カタカナ入力に対応した技検索
  bool _matchesSearchQuery(String skillName, String query) {
    if (query.isEmpty) return true;
    
    final lowerQuery = query.toLowerCase();
    final lowerSkillName = skillName.toLowerCase();
    
    // 直接マッチング
    if (lowerSkillName.contains(lowerQuery)) {
      return true;
    }
    
    // ひらがな・カタカナ変換マッチング
    final convertedQuery = _convertHiraganaKatakana(lowerQuery);
    if (lowerSkillName.contains(convertedQuery)) {
      return true;
    }
    
    // 逆変換（漢字技名をひらがな読みで検索）
    final skillNameReading = _convertToHiraganaReading(lowerSkillName);
    if (skillNameReading.contains(lowerQuery)) {
      return true;
    }
    
    return false;
  }
  
  // ひらがな↔カタカナ変換
  String _convertHiraganaKatakana(String input) {
    String result = input;
    
    // ひらがな→カタカナ
    for (int i = 0; i < input.length; i++) {
      int codeUnit = input.codeUnitAt(i);
      if (codeUnit >= 0x3041 && codeUnit <= 0x3096) {
        result = result.replaceRange(i, i + 1, String.fromCharCode(codeUnit + 0x60));
      }
    }
    
    // カタカナ→ひらがな
    for (int i = 0; i < input.length; i++) {
      int codeUnit = input.codeUnitAt(i);
      if (codeUnit >= 0x30A1 && codeUnit <= 0x30F6) {
        result = result.replaceRange(i, i + 1, String.fromCharCode(codeUnit - 0x60));
      }
    }
    
    return result;
  }
  
  // 漢字技名をひらがな読みに変換（主要な体操技の読み）
  String _convertToHiraganaReading(String skillName) {
    final Map<String, String> readings = {
      // 基本的な体操技の読み
      '伸身': 'しんしん',
      '屈身': 'くっしん',
      '抱え込み': 'かかえこみ',
      '前宙': 'まえちゅう',
      '後宙': 'うしろちゅう',
      '側宙': 'そくちゅう',
      '前転': 'まえてん',
      '後転': 'うしろてん',
      '側転': 'そくてん',
      '前方倒立回転': 'ぜんぽうとうりつかいてん',
      '後方倒立回転': 'こうほうとうりつかいてん',
      '倒立': 'とうりつ',
      '逆立ち': 'さかだち',
      '支持': 'しじ',
      '懸垂': 'けんすい',
      '上水平': 'じょうすいへい',
      '中水平': 'ちゅうすいへい',
      '下水平': 'かすいへい',
      '十字': 'じゅうじ',
      '鉄十字': 'てつじゅうじ',
      '車輪': 'しゃりん',
      'かかえ込み': 'かかえこみ',
      'ひねり': 'ひねり',
      '片足': 'かたあし',
      '両足': 'りょうあし',
      '開脚': 'かいきゃく',
      '閉脚': 'へいきゃく',
      '旋回': 'せんかい',
      '移行': 'いこう',
      '終末技': 'しゅうまつぎ',
      '着地': 'ちゃくち',
      '跳躍': 'ちょうやく',
      '回転': 'かいてん',
      '宙返り': 'ちゅうがえり',
      'ひっかけ': 'ひっかけ',
      '振り': 'ふり',
      '振り上がり': 'ふりあがり',
      '振り下ろし': 'ふりおろし',
      '大車輪': 'だいしゃりん',
      'とび': 'とび',
      '跳び': 'とび',
      'ゆか': 'ゆか',
      '床': 'ゆか',
      'あん馬': 'あんば',
      'つり輪': 'つりわ',
      '跳馬': 'とびうま',
      '平行棒': 'へいこうぼう',
      '鉄棒': 'てつぼう',
      // 追加の体操技
      'ムーンサルト': 'むーんさると',
      'バックフリップ': 'ばっくふりっぷ',
      'フロントフリップ': 'ふろんとふりっぷ',
      'ツイスト': 'ついすと',
      'ダブル': 'だぶる',
      'トリプル': 'とりぷる',
      'バック': 'ばっく',
      'フロント': 'ふろんと',
      'サイド': 'さいど',
      'レイアウト': 'れいあうと',
      'パイク': 'ぱいく',
      'タック': 'たっく',
      'ハーフ': 'はーふ',
      'フル': 'ふる',
      'アラビアン': 'あらびあん',
      'ランディ': 'らんでぃ',
      'ルドルフ': 'るどるふ',
      'バラニー': 'ばらにー',
      'リューキン': 'りゅーきん',
      'ユルチェンコ': 'ゆるちぇんこ',
      'アマナール': 'あまなーる',
      'プロドゥノワ': 'ぷろどぅのわ',
      'チュソビチナ': 'ちゅそびちな',
    };
    
    String result = skillName;
    readings.forEach((kanji, reading) {
      result = result.replaceAll(kanji, reading);
    });
    
    return result;
  }

  // 種目編集画面への遷移
  void _navigateToApparatusEdit(String apparatus) {
    setState(() {
      // 現在のデータを保存
      if (_selectedApparatus != null) {
        _allRoutines[_selectedApparatus!] = List.from(_routine);
        _allConnectionGroups[_selectedApparatus!] = List.from(_connectionGroups);
        _allNextConnectionGroupIds[_selectedApparatus!] = _nextConnectionGroupId;
        _allDScoreResults[_selectedApparatus!] = _dScoreResult;
      }
      
      // 新しい種目のデータを読み込み
      _selectedApparatus = apparatus;
      _routine = List.from(_allRoutines[apparatus] ?? []);
      _connectionGroups = List.from(_allConnectionGroups[apparatus] ?? []);
      _nextConnectionGroupId = _allNextConnectionGroupIds[apparatus] ?? 1;
      _dScoreResult = _allDScoreResults[apparatus];
      _selectedSkill = null;
      _selectedSkillIndex = null;
      
    });
    
    // プレミアムチェック付きでDスコア計算モードに切り替え
    if (_safeSwitchToMode(AppMode.dScore)) {
      _loadSkills(apparatus);
    }
  }

  // 管理者インターフェイス構築
  Widget _buildAdminInterface() {
    if (_isLoadingAdminData) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getText('adminPanel'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 20),
          
          // 統計カード
          if (_adminAnalytics != null) ...[
            Text(
              'システム統計',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 10),
            _buildStatsCards(),
            SizedBox(height: 30),
          ],
          
          // ユーザー管理
          if (_adminUsers != null) ...[
            Text(
              'ユーザー管理',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 10),
            _buildUsersTable(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final analytics = _adminAnalytics!;
    return Row(
      children: [
        _buildStatCard('総ユーザー数', '${analytics['total_users']}', Icons.people),
        SizedBox(width: 10),
        _buildStatCard('無料ユーザー', '${analytics['free_users']}', Icons.person),
        SizedBox(width: 10),
        _buildStatCard('プレミアム', '${analytics['premium_users']}', Icons.star),
        SizedBox(width: 10),
        _buildStatCard('転換率', '${analytics['conversion_rate'].toStringAsFixed(1)}%', Icons.trending_up),
      ],
    );
  }


  Widget _buildUsersTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: Column(
        children: [
          // ヘッダー
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('ユーザー名', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('メール', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('プラン', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('状態', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          // ユーザーリスト
          ...(_adminUsers!.take(10).map((user) => _buildUserRow(user)).toList()),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final isDisabled = user['disabled'] ?? false;
    final tier = user['subscription_tier'] ?? 'free';
    final role = user['role'] ?? 'free';
    
    Color tierColor = tier == 'premium' ? Colors.amber : Colors.grey[400]!;
    if (role == 'admin') tierColor = Colors.red[400]!;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[600]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              user['username'] ?? '',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user['email'] ?? '',
              style: TextStyle(color: Colors.grey[300]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tierColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tierColor),
              ),
              child: Text(
                role == 'admin' ? '管理者' : (tier == 'premium' ? 'Premium' : 'Free'),
                style: TextStyle(color: tierColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDisabled ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDisabled ? Colors.red : Colors.green),
              ),
              child: Text(
                isDisabled ? '無効' : '有効',
                style: TextStyle(color: isDisabled ? Colors.red : Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // アプリライフサイクル監視を停止
    WidgetsBinding.instance.removeObserver(this);
    
    // 定期チェックタイマーを停止
    _subscriptionCheckTimer?.cancel();
    
    // コントローラーをクリーンアップ
    _textController.dispose();
    _analyticsController.dispose();
    _skillSearchController.dispose();
    
    super.dispose();
  }
}

// 技選択ダイアログ（シンプルで安全な実装）
class _SkillSelectionDialog extends StatefulWidget {
  final Skill currentSkill;
  final List<Skill> skillList;
  final Function(Skill) onSkillSelected;
  final String currentLang;
  final String? apparatus;

  const _SkillSelectionDialog({
    required this.currentSkill,
    required this.skillList,
    required this.onSkillSelected,
    required this.currentLang,
    this.apparatus,
  });

  @override
  _SkillSelectionDialogState createState() => _SkillSelectionDialogState();
}

class _SkillSelectionDialogState extends State<_SkillSelectionDialog> {
  String _searchText = '';
  List<Skill> _filteredSkills = [];
  int? _selectedGroupFilter;
  String? _selectedDifficultyFilter;

  @override
  void initState() {
    super.initState();
    _filteredSkills = widget.skillList;
  }

  void _filterSkills(String query) {
    setState(() {
      _searchText = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredSkills = widget.skillList.where((skill) {
      // テキスト検索フィルター
      bool textMatch = _searchText.isEmpty || _matchesSearchQuery(skill.name, _searchText);
      
      // グループフィルター
      bool groupMatch = _selectedGroupFilter == null || skill.group == _selectedGroupFilter;
      
      // 難度フィルター
      bool difficultyMatch = _selectedDifficultyFilter == null || skill.valueLetter == _selectedDifficultyFilter;
      
      return textMatch && groupMatch && difficultyMatch;
    }).toList();
  }
  
  // ひらがな・カタカナ入力に対応した技検索（ダイアログ用）
  bool _matchesSearchQuery(String skillName, String query) {
    if (query.isEmpty) return true;
    
    final lowerQuery = query.toLowerCase();
    final lowerSkillName = skillName.toLowerCase();
    
    // 直接マッチング
    if (lowerSkillName.contains(lowerQuery)) {
      return true;
    }
    
    // ひらがな・カタカナ変換マッチング
    final convertedQuery = _convertHiraganaKatakana(lowerQuery);
    if (lowerSkillName.contains(convertedQuery)) {
      return true;
    }
    
    // 逆変換（漢字技名をひらがな読みで検索）
    final skillNameReading = _convertToHiraganaReading(lowerSkillName);
    if (skillNameReading.contains(lowerQuery)) {
      return true;
    }
    
    return false;
  }
  
  // ひらがな↔カタカナ変換
  String _convertHiraganaKatakana(String input) {
    String result = input;
    
    // ひらがな→カタカナ
    for (int i = 0; i < input.length; i++) {
      int codeUnit = input.codeUnitAt(i);
      if (codeUnit >= 0x3041 && codeUnit <= 0x3096) {
        result = result.replaceRange(i, i + 1, String.fromCharCode(codeUnit + 0x60));
      }
    }
    
    // カタカナ→ひらがな
    for (int i = 0; i < input.length; i++) {
      int codeUnit = input.codeUnitAt(i);
      if (codeUnit >= 0x30A1 && codeUnit <= 0x30F6) {
        result = result.replaceRange(i, i + 1, String.fromCharCode(codeUnit - 0x60));
      }
    }
    
    return result;
  }
  
  // 漢字技名をひらがな読みに変換（主要な体操技の読み）
  String _convertToHiraganaReading(String skillName) {
    final Map<String, String> readings = {
      // 基本的な体操技の読み
      '伸身': 'しんしん',
      '屈身': 'くっしん',
      '抱え込み': 'かかえこみ',
      '前宙': 'まえちゅう',
      '後宙': 'うしろちゅう',
      '側宙': 'そくちゅう',
      '前転': 'まえてん',
      '後転': 'うしろてん',
      '側転': 'そくてん',
      '前方倒立回転': 'ぜんぽうとうりつかいてん',
      '後方倒立回転': 'こうほうとうりつかいてん',
      '倒立': 'とうりつ',
      '逆立ち': 'さかだち',
      '支持': 'しじ',
      '懸垂': 'けんすい',
      '上水平': 'じょうすいへい',
      '中水平': 'ちゅうすいへい',
      '下水平': 'かすいへい',
      '十字': 'じゅうじ',
      '鉄十字': 'てつじゅうじ',
      '車輪': 'しゃりん',
      'かかえ込み': 'かかえこみ',
      'ひねり': 'ひねり',
      '片足': 'かたあし',
      '両足': 'りょうあし',
      '開脚': 'かいきゃく',
      '閉脚': 'へいきゃく',
      '旋回': 'せんかい',
      '移行': 'いこう',
      '終末技': 'しゅうまつぎ',
      '着地': 'ちゃくち',
      '跳躍': 'ちょうやく',
      '回転': 'かいてん',
      '宙返り': 'ちゅうがえり',
      'ひっかけ': 'ひっかけ',
      '振り': 'ふり',
      '振り上がり': 'ふりあがり',
      '振り下ろし': 'ふりおろし',
      '大車輪': 'だいしゃりん',
      'とび': 'とび',
      '跳び': 'とび',
      'ゆか': 'ゆか',
      '床': 'ゆか',
      'あん馬': 'あんば',
      'つり輪': 'つりわ',
      '跳馬': 'とびうま',
      '平行棒': 'へいこうぼう',
      '鉄棒': 'てつぼう',
      // 追加の体操技
      'ムーンサルト': 'むーんさると',
      'バックフリップ': 'ばっくふりっぷ',
      'フロントフリップ': 'ふろんとふりっぷ',
      'ツイスト': 'ついすと',
      'ダブル': 'だぶる',
      'トリプル': 'とりぷる',
      'バック': 'ばっく',
      'フロント': 'ふろんと',
      'サイド': 'さいど',
      'レイアウト': 'れいあうと',
      'パイク': 'ぱいく',
      'タック': 'たっく',
      'ハーフ': 'はーふ',
      'フル': 'ふる',
      'アラビアン': 'あらびあん',
      'ランディ': 'らんでぃ',
      'ルドルフ': 'るどるふ',
      'バラニー': 'ばらにー',
      'リューキン': 'りゅーきん',
      'ユルチェンコ': 'ゆるちぇんこ',
      'アマナール': 'あまなーる',
      'プロドゥノワ': 'ぷろどぅのわ',
      'チュソビチナ': 'ちゅそびちな',
    };
    
    String result = skillName;
    readings.forEach((kanji, reading) {
      result = result.replaceAll(kanji, reading);
    });
    
    return result;
  }

  void _showGroupFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('グループフィルタ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('全て'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: _selectedGroupFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupFilter = value;
                      _applyFilters();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ...List.generate(_getMaxGroupsForApparatus(widget.apparatus), (index) => index + 1).map((group) =>
                ListTile(
                  title: Text('グループ $group'),
                  leading: Radio<int?>(
                    value: group,
                    groupValue: _selectedGroupFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedGroupFilter = value;
                        _applyFilters();
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDifficultyFilterDialog() {
    final difficulties = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('難度フィルタ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('全て'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedDifficultyFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedDifficultyFilter = value;
                      _applyFilters();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ...difficulties.map((difficulty) =>
                ListTile(
                  title: Text('$difficulty難度'),
                  leading: Radio<String?>(
                    value: difficulty,
                    groupValue: _selectedDifficultyFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedDifficultyFilter = value;
                        _applyFilters();
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('技を変更 (現在: ${widget.currentSkill.name})'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // 検索フィールド
            TextField(
              decoration: const InputDecoration(
                hintText: '技を検索...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterSkills,
            ),
            const SizedBox(height: 12),
            // フィルターチップ
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilterChip(
                  label: Text('グループ: ${_selectedGroupFilter ?? "全て"}'),
                  selected: _selectedGroupFilter != null,
                  onSelected: (selected) => _showGroupFilterDialog(),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                ),
                FilterChip(
                  label: Text('難度: ${_selectedDifficultyFilter ?? "全て"}'),
                  selected: _selectedDifficultyFilter != null,
                  onSelected: (selected) => _showDifficultyFilterDialog(),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.orange[100],
                ),
                if (_selectedGroupFilter != null || _selectedDifficultyFilter != null)
                  ActionChip(
                    label: const Text('クリア'),
                    onPressed: () {
                      setState(() {
                        _selectedGroupFilter = null;
                        _selectedDifficultyFilter = null;
                        _applyFilters();
                      });
                    },
                    backgroundColor: Colors.red[50],
                    labelStyle: TextStyle(color: Colors.red[700]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 技リスト（技選択画面と同じスタイル）
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _filteredSkills.length,
                  itemBuilder: (context, index) {
                    final skill = _filteredSkills[index];
                    final isCurrentSkill = skill.name == widget.currentSkill.name &&
                        skill.group == widget.currentSkill.group &&
                        skill.valueLetter == widget.currentSkill.valueLetter;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCurrentSkill ? Colors.blue.withOpacity(0.1) : null,
                        border: index > 0 ? Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))) : null,
                      ),
                      child: InkWell(
                        onTap: () {
                          if (!isCurrentSkill) {
                            widget.onSkillSelected(skill);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    skill.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isCurrentSkill ? Colors.blue.shade300 : Colors.white,
                                    ),
                                  ),
                                ),
                                if (isCurrentSkill)
                                  const Icon(Icons.check, color: Colors.blue, size: 20),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Group ${skill.group}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'D値: ${skill.valueLetter} (${skill.value.toStringAsFixed(1)})',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(widget.currentLang == 'English' ? 'Cancel' : 'キャンセル'),
        ),
      ],
    );
  }
}

// 分析チャット用のメッセージクラス
class AnalyticsMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  AnalyticsMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({super.key, required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(child: Text(isUser ? 'You' : 'AI')),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isUser ? 'You' : 'AI', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Text(text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // dispose method removed - not needed in this class
}

// 演技構成保存ダイアログ
class _SaveRoutineDialog extends StatefulWidget {
  final Function(String) onSave;
  final String currentLang;

  const _SaveRoutineDialog({
    required this.onSave,
    required this.currentLang,
  });

  @override
  _SaveRoutineDialogState createState() => _SaveRoutineDialogState();
}

class _SaveRoutineDialogState extends State<_SaveRoutineDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('演技構成を保存'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('構成に名前を付けて保存してください'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '構成名',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                widget.onSave(value.trim());
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.currentLang == 'English' ? 'Cancel' : 'キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.trim().isNotEmpty) {
              widget.onSave(_controller.text.trim());
              Navigator.of(context).pop();
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// 保存済み演技構成一覧ダイアログ
class _SavedRoutinesDialog extends StatelessWidget {
  final Map<String, Map<String, dynamic>> savedRoutines;
  final Function(String) onLoad;
  final Function(String) onDelete;
  final String currentLang;

  const _SavedRoutinesDialog({
    required this.savedRoutines,
    required this.onLoad,
    required this.onDelete,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final sortedKeys = savedRoutines.keys.toList()
      ..sort((a, b) => DateTime.parse(savedRoutines[b]!['savedAt'])
          .compareTo(DateTime.parse(savedRoutines[a]!['savedAt'])));

    return AlertDialog(
      title: const Text('保存済み演技構成'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: savedRoutines.isEmpty
            ? const Center(
                child: Text('保存済みの構成はありません'),
              )
            : ListView.builder(
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final key = sortedKeys[index];
                  final routine = savedRoutines[key]!;
                  final savedAt = DateTime.parse(routine['savedAt']);
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(routine['apparatus']),
                      ),
                      title: Text(routine['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('種目: ${routine['apparatus']}'),
                          Text('技数: ${routine['routine'].length}'),
                          Text('保存日: ${savedAt.month}/${savedAt.day} ${savedAt.hour}:${savedAt.minute.toString().padLeft(2, '0')}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.file_download),
                            onPressed: () {
                              onLoad(key);
                              Navigator.of(context).pop();
                            },
                            tooltip: '読み込み',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('削除確認'),
                                  content: Text('「${routine['name']}」を削除しますか？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: Text(currentLang == 'English' ? 'Cancel' : 'キャンセル'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        onDelete(key);
                                        Navigator.of(context).pop();
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('削除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            tooltip: '削除',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(currentLang == 'English' ? 'Close' : '閉じる'),
        ),
      ],
    );
  }
}


// DScoreResult class definition  
class DScoreResult {
  final double dScore;
  final double difficultyValue;
  final double groupBonus;
  final double connectionBonus;
  final int fulfilledGroups;
  final int requiredGroups;
  final double totalDScore;

  DScoreResult({
    required this.dScore,
    required this.difficultyValue,
    required this.groupBonus,
    required this.connectionBonus,
    required this.fulfilledGroups,
    required this.requiredGroups,
  }) : totalDScore = dScore;
}

// Global function for D-score calculation
// 種目別要求グループを取得
Set<int> _getRequiredGroupsForApparatus(String apparatus) {
  switch (apparatus.toLowerCase()) {
    case 'floor':
    case 'fx':
      return {1, 2, 3, 4}; // 床：全4グループ要求
    case 'pommel':
    case 'ph':
      return {1, 2, 3, 4}; // あん馬：全4グループ要求  
    case 'rings':
    case 'sr':
      return {1, 2, 3, 4}; // つり輪：全4グループ要求
    case 'vault':
    case 'vt':
      return {1, 2, 3, 4, 5}; // 跳馬：5グループ存在
    case 'parallel':
    case 'pb':
      return {1, 2, 3, 4}; // 平行棒：全4グループ要求
    case 'horizontal':
    case 'hb':
      return {1, 2, 3, 4}; // 鉄棒：全4グループ要求
    default:
      return {1, 2, 3, 4}; // デフォルト
  }
}

// 種目別最大グループ数を取得
int _getMaxGroupsForApparatus(String? apparatus) {
  if (apparatus == null) return 4; // デフォルトは4グループ
  
  switch (apparatus.toLowerCase()) {
    case 'vault':
    case 'vt':
      return 5; // 跳馬：5グループ
    default:
      return 4; // その他の種目：4グループ
  }
}

// 体操専門知識データベース
class GymnasticsKnowledgeBase {
  // 技データベース（skills_ja.csvから読み込み）
  static List<Map<String, dynamic>> _skillsDatabase = [];
  static bool _isSkillsLoaded = false;
  
  // 外部からリセットできるようにする
  static void resetSkillsDatabase() {
    _isSkillsLoaded = false;
    _skillsDatabase.clear();
  }
  
  // 技データベースの読み込み
  static Future<void> loadSkillsDatabase() async {
    if (_isSkillsLoaded) return;
    
    try {
      final String data = await rootBundle.loadString('data/skills_ja.csv');
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(data);
      
      // ヘッダーを除いて処理
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= 4) {
          _skillsDatabase.add({
            'apparatus': row[0].toString(),
            'name': row[1].toString(),
            'group': row[2].toString(),
            'value_letter': row[3].toString(),
          });
        }
      }
      
      _isSkillsLoaded = true;
      print('Skills database loaded: ${_skillsDatabase.length} skills');
    } catch (e) {
      print('Error loading skills database: $e');
    }
  }
  
  // 技の検索
  static List<Map<String, dynamic>> searchSkills({
    String? apparatus,
    String? group,
    String? difficulty,
    String? namePattern,
  }) {
    if (!_isSkillsLoaded) return [];
    
    return _skillsDatabase.where((skill) {
      bool matches = true;
      
      if (apparatus != null) {
        matches = matches && skill['apparatus'] == apparatus;
      }
      
      if (group != null) {
        matches = matches && skill['group'] == group;
      }
      
      if (difficulty != null) {
        matches = matches && skill['value_letter'] == difficulty;
      }
      
      if (namePattern != null) {
        matches = matches && skill['name'].toString().contains(namePattern);
      }
      
      return matches;
    }).toList();
  }
  
  // 難度別技数の取得
  static Map<String, int> getDifficultyCount({String? apparatus}) {
    if (!_isSkillsLoaded) return {};
    
    final skills = apparatus != null 
      ? searchSkills(apparatus: apparatus)
      : _skillsDatabase;
    
    final Map<String, int> count = {};
    for (final skill in skills) {
      final difficulty = skill['value_letter'];
      count[difficulty] = (count[difficulty] ?? 0) + 1;
    }
    
    return count;
  }
  
  // グループ別技数の取得
  static Map<String, int> getGroupCount({String? apparatus}) {
    if (!_isSkillsLoaded) return {};
    
    final skills = apparatus != null 
      ? searchSkills(apparatus: apparatus)
      : _skillsDatabase;
    
    final Map<String, int> count = {};
    for (final skill in skills) {
      final group = skill['group'];
      count[group] = (count[group] ?? 0) + 1;
    }
    
    return count;
  }
  // 種目別基本情報
  static Map<String, Map<String, dynamic>> apparatusInfo = {
    'vault': {
      'name_ja': '跳馬',
      'name_en': 'Vault',
      'groups': 5,
      'groupBonus': 0.0,
      'skillLimit': 1,
      'description_ja': '跳馬は1技のみ実施する種目で、5つのグループが存在します。',
      'groups_detail': {
        1: '前転系跳躍',
        2: '後転系跳躍', 
        3: '前転系跳躍（1/2〜1/1ひねり）',
        4: '後転系跳躍（1/2〜1/1ひねり）',
        5: '前転系・後転系跳躍（1.5ひねり以上）'
      }
    },
    'floor': {
      'name_ja': '床',
      'name_en': 'Floor Exercise',
      'groups': 4,
      'groupBonus': 0.5,
      'skillLimit': null,
      'description_ja': '床運動は最大90秒の演技で、4つのグループすべてから技を実施する必要があります。',
      'groups_detail': {
        1: '前方系統の非宙返り技および前方宙返り技',
        2: '後方系統の非宙返り技および後方宙返り技',
        3: '側方系統の非宙返り技および側方宙返り技',
        4: '静止系技'
      }
    },
    'pommel': {
      'name_ja': 'あん馬',
      'name_en': 'Pommel Horse',
      'groups': 4,
      'groupBonus': 0.5,
      'skillLimit': null,
      'description_ja': 'あん馬は4つのグループすべてから技を実施する必要があります。',
      'groups_detail': {
        1: 'シザーズ系およびフレア系技',
        2: '円形転向系技',
        3: '移動系技',
        4: '終末技'
      }
    },
    'rings': {
      'name_ja': 'つり輪',
      'name_en': 'Still Rings',
      'groups': 4,
      'groupBonus': 0.5,
      'skillLimit': null,
      'description_ja': 'つり輪は4つのグループすべてから技を実施する必要があります。',
      'groups_detail': {
        1: '引き上げ系および懸垂系技',
        2: '静止系技（力技）',
        3: 'スイング系技',
        4: '終末技'
      }
    },
    'parallel': {
      'name_ja': '平行棒',
      'name_en': 'Parallel Bars',
      'groups': 4,
      'groupBonus': 0.5,
      'skillLimit': null,
      'description_ja': '平行棒は4つのグループすべてから技を実施する必要があります。',
      'groups_detail': {
        1: '支持系および懸垂系技',
        2: '上腕支持系技',
        3: '長懸垂系および振動系技',
        4: '終末技'
      }
    },
    'horizontal': {
      'name_ja': '鉄棒',
      'name_en': 'Horizontal Bar',
      'groups': 4,
      'groupBonus': 0.5,
      'skillLimit': null,
      'description_ja': '鉄棒は4つのグループすべてから技を実施する必要があります。',
      'groups_detail': {
        1: '長懸垂系および振動系技',
        2: '回転系技',
        3: '飛行系技',
        4: '終末技'
      }
    }
  };

  // 採点規則に関する基本知識
  static Map<String, dynamic> scoringRules = {
    'dScore': {
      'description_ja': 'Dスコアは難度点とも呼ばれ、演技の難易度を評価します。',
      'components': ['技の難度値', 'グループ要求ボーナス', '組み合わせボーナス'],
      'groupRequirement': '各種目で指定されたグループから技を実施することでボーナスを獲得'
    },
    'eScore': {
      'description_ja': 'Eスコアは実施点とも呼ばれ、演技の美しさや正確性を評価します。',
      'startValue': 10.0,
      'deductions': '技術的ミス、姿勢不良、着地ミスなどで減点'
    }
  };

  // よくある質問への回答
  static Map<String, String> faqResponses = {
    '跳馬_グループ数': '跳馬には5つのグループが存在します。\n'
        'グループ1: 前転系跳躍\n'
        'グループ2: 後転系跳躍\n'
        'グループ3: 前転系跳躍（1/2〜1/1ひねり）\n'
        'グループ4: 後転系跳躍（1/2〜1/1ひねり）\n'
        'グループ5: 前転系・後転系跳躍（1.5ひねり以上）',
    
    '跳馬_グループボーナス': '跳馬はグループボーナスがありません。跳馬は1技のみ実施する種目のため、その技の難度値がそのままDスコアとなります。',
    
    'グループ要求_床': '床運動では4つのグループすべてから最低1技ずつ実施する必要があります。また、必ずバランス技を含める必要があります。\n'
        '• 各グループから最低1技（最大2.0点のグループ点）\n'
        '• バランス技（必須要件）\n'
        '• 最大90秒の演技時間',
    
    'Dスコア_計算': '【跳馬】Dスコア = 選択した1技の難度値（ボーナス等なし）\n'
        '【その他種目】Dスコア = 技の難度値の合計 + グループ点 + 組み合わせボーナス\n\n'
        '【グループ点の詳細】\n'
        '• グループ1: 無条件で0.5点\n'
        '• グループ2,3: D難度以上=0.5点、C難度以下=0.3点\n'
        '• グループ4(終末技): 技の難度値がそのまま加算（D=0.4, E=0.5, F=0.6...）\n'
        '• 床のグループ4: 通常ルール（D難度以上=0.5点、C難度以下=0.3点）',
    
    'グループ点_詳細': 'グループ点は各グループの最高難度技に基づいて計算されます：\n\n'
        '【グループ1】\n'
        '• 無条件で0.5点が加算されます\n\n'
        '【グループ2,3】\n'
        '• D難度以上の技を実施: 0.5点\n'
        '• C難度以下の技のみ: 0.3点\n\n'
        '【グループ4（終末技）】\n'
        '• 床以外: 技の難度値がそのまま加算（D=0.4, E=0.5...）\n'
        '• 床: 通常ルール（D難度以上=0.5点、C難度以下=0.3点）\n\n'
        '※跳馬はグループ点なし（1技の難度値のみ）',
    
    '演技構成_制限': '体操競技の演技構成には以下の制限があります：\n\n'
        '【技数制限】\n'
        '• 跳馬: 1技のみ\n'
        '• その他種目: 最大8技まで\n\n'
        '【グループ別技数制限】\n'
        '• グループ1-3: 各最大4技まで\n'
        '• グループ4（終末技）: 制限なし（全体8技の範囲内）\n\n'
        'これらの制限は体操競技の公式ルールに基づいています。',
    
    '連続技ボーナス': '連続技ボーナスは種目によって異なるルールが適用されます。\n\n'
        '【床・あん馬・つり輪・平行棒】\n'
        '• 対象：グループ2, 3, 4の技\n'
        '• グループ2同士、グループ3同士は加点あり\n'
        '• グループ4同士は加点なし\n'
        '• D以上 + B or C = +0.1点\n'
        '• D以上 + D以上 = +0.2点\n\n'
        '【鉄棒】\n'
        '• 対象：グループ1, 2, 3の技（グループ4は対象外）\n\n'
        '手放し技同士（グループ2同士）：\n'
        '• C難度 + D難度以上 = +0.1点（順不同）\n'
        '• D難度 + D難度 = +0.1点\n'
        '• D難度以上 + E難度以上 = +0.2点（順不同）\n\n'
        'グループ1,3 + グループ2：\n'
        '• グループ1,3のD以上 + グループ2のD = +0.1点\n'
        '• グループ1,3のD以上 + グループ2のE以上 = +0.2点\n'
        '• 例：リバルコ→ウインクラー = +0.2点\n\n'
        '【跳馬】\n'
        '• 連続技ボーナスなし（1技のみ実施）\n\n'
        '※現在のシステムでは簡易計算を使用',
    
    '床_バランス技': '床運動では必ずバランス技を含める必要があります。\n\n'
        '【必須要件】\n'
        '• 技名に「（バランス）」が付いた技を最低1技実施\n'
        '• この要件を満たさない場合、D-Score計算ができません\n\n'
        '【バランス技の例】\n'
        '• V字バランス（バランス）\n'
        '• シュタルダー（バランス）\n'
        '• その他静止系技（バランス）\n\n'
        'バランス技は床運動の重要な構成要素です。'
  };

  // 質問を分析して適切な回答を生成
  static String? getKnowledgeResponse(String question) {
    final q = question.toLowerCase();
    
    // 跳馬に関する質問
    if (q.contains('跳馬') || q.contains('vault')) {
      if (q.contains('グループ') && (q.contains('数') || q.contains('いくつ'))) {
        return faqResponses['跳馬_グループ数'];
      }
      if (q.contains('グループ') && q.contains('ボーナス')) {
        return faqResponses['跳馬_グループボーナス'];
      }
      if (q.contains('何') && q.contains('グループ')) {
        return faqResponses['跳馬_グループ数'];
      }
    }
    
    // グループ要求に関する質問
    if (q.contains('グループ') && q.contains('要求')) {
      if (q.contains('床') || q.contains('floor')) {
        return faqResponses['グループ要求_床'];
      }
    }
    
    // Dスコアに関する質問
    if (q.contains('dスコア') || q.contains('d-スコア') || q.contains('難度')) {
      if (q.contains('計算') || q.contains('どう')) {
        return faqResponses['Dスコア_計算'];
      }
    }
    
    // グループ点に関する質問
    if (q.contains('グループ点') || q.contains('グループボーナス')) {
      return faqResponses['グループ点_詳細'];
    }
    
    // 終末技に関する質問
    if (q.contains('終末技') || q.contains('グループ4')) {
      return faqResponses['グループ点_詳細'];
    }
    
    // 演技構成制限に関する質問
    if (q.contains('8技') || q.contains('技数') || q.contains('何技') || 
        q.contains('制限') || q.contains('最大')) {
      return faqResponses['演技構成_制限'];
    }
    
    // 連続技に関する質問
    if (q.contains('連続技') || q.contains('コネクション') || q.contains('組み合わせ') ||
        q.contains('リバルコ') || q.contains('ウインクラー')) {
      return faqResponses['連続技ボーナス'];
    }
    
    // 床運動のバランス技に関する質問
    if ((q.contains('床') || q.contains('floor')) && 
        (q.contains('バランス') || q.contains('必須') || q.contains('必要'))) {
      return faqResponses['床_バランス技'];
    }
    
    // 技の検索（J難度の技など）
    if (q.contains('j難度') || q.contains('j級') || (q.contains('j') && q.contains('難度'))) {
      final jSkills = searchSkills(difficulty: 'J');
      if (jSkills.isNotEmpty) {
        final skillList = jSkills.map((skill) => 
          '${skill['apparatus']} ${skill['name']} (グループ${skill['group']})').join('\n');
        return 'J難度の技は以下の通りです：\n\n$skillList';
      } else {
        return 'J難度の技は見つかりませんでした。';
      }
    }
    
    // 特定の難度の技を検索
    final difficultyMatch = RegExp(r'([A-J])難度.*技').firstMatch(q);
    if (difficultyMatch != null) {
      final difficulty = difficultyMatch.group(1);
      final skills = searchSkills(difficulty: difficulty);
      if (skills.isNotEmpty) {
        final skillList = skills.take(10).map((skill) => 
          '${skill['apparatus']} ${skill['name']} (グループ${skill['group']})').join('\n');
        final moreText = skills.length > 10 ? '\n\n他にも${skills.length - 10}技あります。' : '';
        return '$difficulty難度の技は以下の通りです：\n\n$skillList$moreText';
      } else {
        return '$difficulty難度の技は見つかりませんでした。';
      }
    }
    
    // 床のグループ別技検索
    if (q.contains('床') && q.contains('グループ')) {
      final groupMatch = RegExp(r'グループ([1-4ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ])').firstMatch(q);
      if (groupMatch != null) {
        String group = groupMatch.group(1)!;
        // 数字をローマ数字に変換
        final groupMapping = {'1': 'Ⅰ', '2': 'Ⅱ', '3': 'Ⅲ', '4': 'Ⅳ'};
        if (groupMapping.containsKey(group)) {
          group = groupMapping[group]!;
        }
        
        final skills = searchSkills(apparatus: 'FX', group: group);
        if (skills.isNotEmpty) {
          final skillList = skills.take(15).map((skill) => 
            '${skill['name']} (${skill['value_letter']}難度)').join('\n');
          final moreText = skills.length > 15 ? '\n\n他にも${skills.length - 15}技あります。' : '';
          return '床のグループ${groupMatch.group(1)}の技は以下の通りです：\n\n$skillList$moreText';
        } else {
          return '床のグループ${groupMatch.group(1)}の技は見つかりませんでした。';
        }
      }
    }
    
    // 種目別グループ検索（一般的）
    final apparatusMapping = {
      '床': 'FX',
      'floor': 'FX',
      '跳馬': 'VT',
      'vault': 'VT',
      'あん馬': 'PH',
      'pommel': 'PH',
      'つり輪': 'SR',
      'rings': 'SR',
      '平行棒': 'PB',
      'parallel': 'PB',
      '鉄棒': 'HB',
      'horizontal': 'HB'
    };
    
    for (final entry in apparatusMapping.entries) {
      if (q.contains(entry.key) && q.contains('グループ')) {
        final groupMatch = RegExp(r'グループ([1-5ⅠⅡⅢⅣⅤⅥⅦⅧⅨⅩ])').firstMatch(q);
        if (groupMatch != null) {
          String group = groupMatch.group(1)!;
          // 数字をローマ数字に変換
          final groupMapping = {'1': 'Ⅰ', '2': 'Ⅱ', '3': 'Ⅲ', '4': 'Ⅳ', '5': 'Ⅴ'};
          if (groupMapping.containsKey(group)) {
            group = groupMapping[group]!;
          }
          
          final skills = searchSkills(apparatus: entry.value, group: group);
          if (skills.isNotEmpty) {
            final skillList = skills.take(10).map((skill) => 
              '${skill['name']} (${skill['value_letter']}難度)').join('\n');
            final moreText = skills.length > 10 ? '\n\n他にも${skills.length - 10}技あります。' : '';
            return '${entry.key}のグループ${groupMatch.group(1)}の技は以下の通りです：\n\n$skillList$moreText';
          } else {
            return '${entry.key}のグループ${groupMatch.group(1)}の技は見つかりませんでした。';
          }
        }
      }
    }
    
    // 技の統計情報
    if (q.contains('技数') || q.contains('何技') || q.contains('統計')) {
      final difficultyStats = getDifficultyCount();
      if (difficultyStats.isNotEmpty) {
        final statsList = difficultyStats.entries
          .where((entry) => entry.key.isNotEmpty)
          .map((entry) => '${entry.key}難度: ${entry.value}技')
          .join('\n');
        return '技数統計：\n\n$statsList';
      }
    }
    
    return null; // 専門知識データベースに該当する回答がない場合
  }
  
  // 種目情報を取得
  static Map<String, dynamic>? getApparatusInfo(String apparatus) {
    // 種目コードを内部キーにマッピング
    final String internalKey;
    switch (apparatus.toLowerCase()) {
      case 'fx':
        internalKey = 'floor';
        break;
      case 'ph':
        internalKey = 'pommel';
        break;
      case 'sr':
        internalKey = 'rings';
        break;
      case 'vt':
        internalKey = 'vault';
        break;
      case 'pb':
        internalKey = 'parallel';
        break;
      case 'hb':
        internalKey = 'horizontal';
        break;
      default:
        // 既に内部キー形式の場合はそのまま使用
        internalKey = apparatus.toLowerCase();
        break;
    }
    
    return apparatusInfo[internalKey];
  }

  // 演技分析に基づく改善案を生成
  static String generateImprovementSuggestions(String apparatus, RoutineAnalysis analysis) {
    final apparatusData = getApparatusInfo(apparatus);
    if (apparatusData == null) return '改善案を生成できませんでした。';

    String suggestions = '🎯 **専門的な改善案**\n\n';
    
    // 基本情報表示
    suggestions += '【${apparatusData['name_ja']}の特徴】\n';
    suggestions += '${apparatusData['description_ja']}\n\n';
    
    // グループ要求分析
    if (analysis.missingGroups.isNotEmpty) {
      suggestions += '【不足グループの対策】\n';
      for (String missingGroup in analysis.missingGroups) {
        final groupNum = int.tryParse(missingGroup.replaceAll('グループ', ''));
        if (groupNum != null && apparatusData['groups_detail'][groupNum] != null) {
          suggestions += '• **グループ$groupNum**: ${apparatusData['groups_detail'][groupNum]}\n';
          suggestions += '  この系統から技を追加することをお勧めします。\n';
        }
      }
      suggestions += '\n';
    }
    
    // 種目別の具体的アドバイス
    final String apparatusKey = apparatus.toLowerCase();
    switch (apparatusKey) {
      case 'vault':
      case 'vt':
        suggestions += '【跳馬のアドバイス】\n';
        suggestions += '• 1技のみの実施のため、最高難度の技を選択することが重要\n';
        suggestions += '• グループボーナスはないため、個々の技の難度値が決定的\n';
        suggestions += '• 着地の安定性も含めて技を選択しましょう\n';
        break;
      case 'floor':
      case 'fx':
        suggestions += '【床運動のアドバイス】\n';
        suggestions += '• 4グループすべてから技を実施してボーナス0.5点を確実に獲得\n';
        suggestions += '• 90秒の時間制限内での構成を考慮\n';
        suggestions += '• 音楽との調和も重要な要素です\n';
        break;
      default:
        suggestions += '【${apparatusData['name_ja']}のアドバイス】\n';
        suggestions += '• 4グループすべてから技を実施してボーナス0.5点を獲得\n';
        suggestions += '• バランスの良い構成を心がけましょう\n';
    }
    
    suggestions += '\n💡 具体的な技について相談したい場合は、お気軽にお聞きください！';
    
    return suggestions;
  }
}

// 技の難度レベルを数値に変換
double _getSkillDifficultyValue(String valueLetter) {
  switch (valueLetter.toUpperCase()) {
    case 'A': return 0.1;
    case 'B': return 0.2;
    case 'C': return 0.3;
    case 'D': return 0.4;
    case 'E': return 0.5;
    case 'F': return 0.6;
    case 'G': return 0.7;
    case 'H': return 0.8;
    case 'I': return 0.9;
    case 'J': return 1.0;
    default: return 0.0;
  }
}

// D難度以上かを判定
bool _isHighDifficulty(String valueLetter) {
  return ['D', 'E', 'F', 'G', 'H', 'I', 'J'].contains(valueLetter.toUpperCase());
}

// グループ内の最高難度技を取得
Skill? _getHighestSkillInGroup(List<Skill> routine, int group) {
  final groupSkills = routine.where((skill) => skill.group == group).toList();
  if (groupSkills.isEmpty) return null;
  
  groupSkills.sort((a, b) => b.value.compareTo(a.value));
  return groupSkills.first;
}

// グループごとの技数をカウント
Map<int, int> _countSkillsPerGroup(List<Skill> routine) {
  final counts = <int, int>{};
  for (var skill in routine) {
    counts[skill.group] = (counts[skill.group] ?? 0) + 1;
  }
  return counts;
}

// 床運動にバランス技が含まれているかチェック
bool _hasBalanceSkill(List<Skill> routine) {
  return routine.any((skill) => skill.name.contains('（バランス）') || skill.name.contains('(バランス)'));
}

// 床運動の必須要件をチェック
String? _checkFloorRequirements(List<Skill> routine) {
  if (!_hasBalanceSkill(routine)) {
    return 'バランス技が含まれていません。床運動では必ずバランス技を入れてください。';
  }
  return null; // 問題なし
}

// グループボーナスを計算（正確なルールに基づく）
double _calculateGroupBonus(String apparatus, List<Skill> routine) {
  // 跳馬は1技のみ実施、グループボーナスなし
  if (apparatus.toLowerCase() == 'vault' || apparatus.toLowerCase() == 'vt') {
    return 0.0;
  }
  
  double totalGroupBonus = 0.0;
  
  // グループ1-4の処理
  for (int groupNum = 1; groupNum <= 4; groupNum++) {
    final highestSkill = _getHighestSkillInGroup(routine, groupNum);
    if (highestSkill == null) continue; // グループに技がない場合
    
    // グループ1：無条件で0.5点
    if (groupNum == 1) {
      totalGroupBonus += 0.5;
    }
    // グループ2,3：D難度以上=0.5点、C難度以下=0.3点
    else if (groupNum == 2 || groupNum == 3) {
      if (_isHighDifficulty(highestSkill.valueLetter)) {
        totalGroupBonus += 0.5;
      } else {
        totalGroupBonus += 0.3;
      }
    }
    // グループ4（終末技）：床以外は技の難度値をそのまま使用
    else if (groupNum == 4) {
      if (apparatus.toLowerCase() == 'floor' || apparatus.toLowerCase() == 'fx') {
        // 床はグループ4も通常ルール
        if (_isHighDifficulty(highestSkill.valueLetter)) {
          totalGroupBonus += 0.5;
        } else {
          totalGroupBonus += 0.3;
        }
      } else {
        // その他種目：終末技の難度値をそのまま使用
        totalGroupBonus += highestSkill.value;
      }
    }
  }
  
  return totalGroupBonus;
}

DScoreResult calculateDScore(String apparatus, List<List<Skill>> routine) {
  double difficultyValue = 0.0;
  double connectionBonus = 0.0;
  
  // 跳馬の特殊処理：1技のみでその技の難度値がDスコア
  if (apparatus.toLowerCase() == 'vault' || apparatus.toLowerCase() == 'vt') {
    // 跳馬は1技のみ、最初に見つかった技の難度値がDスコア
    for (var group in routine) {
      for (var skill in group) {
        difficultyValue = skill.value; // 跳馬は1技のみなので、その技の難度値がDスコア
        break; // 1技のみなので即座に終了
      }
      if (difficultyValue > 0) break; // 技が見つかったら終了
    }
    
    return DScoreResult(
      dScore: difficultyValue, // 跳馬はボーナス等なし、技の難度値のみ
      difficultyValue: difficultyValue,
      groupBonus: 0.0, // 跳馬はグループボーナスなし
      connectionBonus: 0.0, // 跳馬は連続技ボーナスなし
      fulfilledGroups: 1, // 技があれば1グループ充足
      requiredGroups: 1, // 跳馬は1技のみ要求
    );
  }
  
  // その他の種目の通常処理
  final requiredGroups = _getRequiredGroupsForApparatus(apparatus);
  final presentGroups = <int>{};
  
  // フラットなスキルリストを作成
  final flatRoutine = <Skill>[];
  
  // 技の難度値とグループを収集
  for (var group in routine) {
    for (var skill in group) {
      difficultyValue += skill.value;
      presentGroups.add(skill.group);
      flatRoutine.add(skill);
    }
    
    // 連続技ボーナスの計算（2技以上の場合）
    if (group.length >= 2) {
      connectionBonus += 0.1 * (group.length - 1); // 簡易的な連続技ボーナス
    }
  }
  
  // グループ要求充足率とボーナスの計算
  final fulfilledGroups = requiredGroups.intersection(presentGroups).length;
  final groupBonus = _calculateGroupBonus(apparatus, flatRoutine);
  
  double totalScore = difficultyValue + groupBonus + connectionBonus;
  
  return DScoreResult(
    dScore: totalScore,
    difficultyValue: difficultyValue,
    groupBonus: groupBonus,
    connectionBonus: connectionBonus,
    fulfilledGroups: fulfilledGroups,
    requiredGroups: requiredGroups.length,
  );
}
