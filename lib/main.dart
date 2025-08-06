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
// import 'ad_widget.dart'; // 未使用のためコメントアウト // ユニバーサル広告ウィジェット
import 'platform_ui_config.dart'; // プラットフォーム別UI設定
// import 'auth_screen.dart'; // 認証画面（現在未使用）
// import 'social_auth_manager.dart'; // ソーシャル認証（現在未使用）
// Web版広告システムは廃止

// デバッグ用ヘルパー関数（本番では出力しない）
void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}

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
    
    // 難度改善提案（詳細版）
    if (averageDifficulty < 0.3) {
      suggestions.add('【難度改善】平均難度が${(averageDifficulty * 10).toStringAsFixed(1)}点と低めです。現在の構成では高得点が望めません。\n' +
        '具体的な改善策：\n' +
        '• C難度（0.3点）以上の技を3-4個追加しましょう\n' +
        '• 各グループから最低1つはC難度以上を選択してください\n' +
        '• 難度の高い技は徐々に習得し、安全に練習してください');
    } else if (averageDifficulty < 0.4) {
      suggestions.add('【難度向上の余地あり】平均難度${(averageDifficulty * 10).toStringAsFixed(1)}点は中級レベルです。\n' +
        '改善のポイント：\n' +
        '• D難度（0.4点）の技を1-2個追加すると効果的です\n' +
        '• 連続技で難度を上げることも検討してください\n' +
        '• 現在の技の発展系を練習することから始めましょう');
    } else if (averageDifficulty >= 0.5) {
      suggestions.add('【優秀な難度構成】平均難度${(averageDifficulty * 10).toStringAsFixed(1)}点は高水準です。\n' +
        '注意点：\n' +
        '• 実施の確実性を重視してください\n' +
        '• 高難度技の成功率を上げる練習に集中しましょう\n' +
        '• 必要に応じて難度を下げて安定性を確保することも重要です');
    }
    
    // 技数最適化（詳細版）- 跳馬は除外
    if (apparatus != 'VT') {
      if (totalSkills < 8) {
        suggestions.add('【技数不足】現在${totalSkills}技しかありません。\n' +
          '改善方法：\n' +
          '• 推奨技数は8-10技です（${8 - totalSkills}技以上追加が必要）\n' +
          '• 各グループから均等に技を選択してください\n' +
          '• 簡単な技から始めて、徐々に難度を上げていきましょう\n' +
          '• 連続技を活用して効率的に技数を増やすことも可能です');
      } else if (totalSkills > 12) {
        suggestions.add('【技数過多によるリスク】${totalSkills}技は多すぎます。\n' +
          'リスクと対策：\n' +
          '• 体力消耗により後半の実施が乱れる可能性があります\n' +
          '• 各技の精度が低下し、減点が増える恐れがあります\n' +
          '• 重要度の低い技を${totalSkills - 10}個程度削減しましょう\n' +
          '• 高得点が期待できる技に絞って練習時間を確保してください');
      } else {
        suggestions.add('【適切な技数】${totalSkills}技は理想的な構成です。\n' +
          '今後の方針：\n' +
          '• 各技の実施精度を高めることに集中しましょう\n' +
          '• 技の順序を工夫して体力配分を最適化してください');
      }
    }
    
    // グループバランス改善（詳細版）
    final requiredGroups = {1, 2, 3, 4, 5}; // すべてのグループをチェック
    final missingGroups = requiredGroups.difference(groupDistribution.keys.toSet());
    if (missingGroups.isNotEmpty) {
      final groupNames = {
        1: '非アクロバット系要素',
        2: '前方系アクロバット要素',
        3: '後方系アクロバット要素',
        4: '終末技',
        5: '力技・バランス系要素'
      };
      
      String missingGroupDetails = missingGroups.map((g) => 
        'グループ$g（${groupNames[g] ?? "特殊要素"}）').join('、');
      
      suggestions.add('【必須グループ不足】以下のグループが不足しています：\n' +
        '$missingGroupDetails\n' +
        '影響と対策：\n' +
        '• 各グループから最低1技は必須です（競技規則要件）\n' +
        '• 不足グループ1つにつき大幅な減点があります\n' +
        '• 早急に各グループの基本技から練習を始めてください\n' +
        '• コーチと相談して、習得しやすい技から選択しましょう');
    } else {
      // グループバランスの詳細分析
      final List<String> balanceIssues = [];
      groupDistribution.forEach((group, count) {
        if (count > 4) {
          balanceIssues.add('グループ$groupに偏りすぎています（${count}技）');
        }
      });
      
      if (balanceIssues.isNotEmpty) {
        suggestions.add('【グループバランス要改善】\n' +
          balanceIssues.join('\n') + '\n' +
          '改善案：\n' +
          '• 各グループ2-3技程度が理想的なバランスです\n' +
          '• 偏りのあるグループから技を削減し、他グループに振り分けましょう');
      }
    }
    
    // 難度バランス改善（詳細版）
    final hasOnlyEasySkills = difficultyDistribution.keys.every((key) => 
      ['A', 'B'].contains(key));
    if (hasOnlyEasySkills && totalSkills > 0) {
      suggestions.add('【難度構成が低すぎます】A・B難度のみの構成です。\n' +
        '問題点：\n' +
        '• Dスコアが極端に低く、競技力が不足します\n' +
        '• 上級大会では通用しないレベルです\n' +
        '改善策：\n' +
        '• まずC難度（0.3点）の技を2-3個追加しましょう\n' +
        '• 次に、徐々にD難度（0.4点）の技に挑戦してください\n' +
        '• 各グループから高難度技を選ぶことでバランスよく強化できます');
    } else {
      // 難度分布の詳細分析
      int highDifficultyCount = 0;
      difficultyDistribution.forEach((diff, count) {
        if (['D', 'E', 'F', 'G', 'H', 'I'].contains(diff)) {
          highDifficultyCount += count;
        }
      });
      
      if (highDifficultyCount > totalSkills * 0.7) {
        suggestions.add('【高難度偏重のリスク】高難度技が${highDifficultyCount}個（${(highDifficultyCount * 100 / totalSkills).toStringAsFixed(0)}%）を占めています。\n' +
          'リスク：\n' +
          '• 失敗リスクが高く、大きな減点につながる可能性があります\n' +
          '• 体力的負担が大きく、完遌が困難です\n' +
          '対策：\n' +
          '• 成功率の高い技を優先して構成しましょう\n' +
          '• 必要に応じてB・C難度の確実な技を加えてください');
      }
    }
    
    // 特定の種目に対する詳細提案
    switch (apparatus) {
      case 'FX':
        if (!groupDistribution.containsKey(4)) {
          suggestions.add('【フロア種目固有の要件】終末技（グループ4）がありません。\n' +
            '必須要件：\n' +
            '• フロアでは必ず終末技で終わる必要があります\n' +
            '• ダブルサルト、伸身2回宙返りなどが一般的です\n' +
            '• 難度と着地の安定性を両立させる技を選びましょう');
        }
        // フロア特有の追加アドバイス
        if ((groupDistribution[2] ?? 0) < 2) {
          suggestions.add('【フロア構成のバランス】前方系アクロバット（グループ2）が少ないです。\n' +
            '• 前方宙返り、前方伸身宙返りなどを追加しましょう\n' +
            '• コンビネーションで連続ボーナスも狙えます');
        }
        break;
        
      case 'HB':
        if (!groupDistribution.containsKey(5)) {
          suggestions.add('【鉄棒種目固有の要件】終末技（グループ5）がありません。\n' +
            '必須要件：\n' +
            '• 鉄棒では必ず終末技で降りる必要があります\n' +
            '• 伸身ムーンサルト、ダブルツォイストなどが高評価\n' +
            '• D難度以上の終末技を目指しましょう');
        }
        // 鉄棒特有の追加アドバイス
        if ((groupDistribution[1] ?? 0) < 2) {
          suggestions.add('【鉄棒の手放し技不足】手放し技（グループ1の一部）が少ないです。\n' +
            '• トカチェフ、コールマンなどの手放し技を追加\n' +
            '• 鉄棒では手放し技が高評価されます');
        }
        break;
        
      case 'VT':
        if (totalSkills < 1) {
          suggestions.add('【跳馬種目の特性】跳馬では1技のみ選択します。\n' +
            '要件：\n' +
            '• 最も得意で確実な技を1つ選択してください\n' +
            '• 実施の完成度が直接得点に反映されます\n' +
            '推奨：\n' +
            '• 難度と実施のバランスを考慮\n' +
            '• 着地の安定性を最重視\n' +
            '• 技の美しさと正確性を重視しましょう');
        } else if (totalSkills > 1) {
          suggestions.add('【跳馬の技数過多】跳馬は1技のみ選択してください。\n' +
            '現在${totalSkills}技が選択されています。\n' +
            '• 最も得意な技1つに絞ってください\n' +
            '• 複数技の練習よりも1技の完成度向上に集中');
        }
        break;
        
      case 'PH':
        // あん馬特有のアドバイス
        if ((groupDistribution[3] ?? 0) < 2) {
          suggestions.add('【あん馬の旋回技不足】旋回系技（グループ3）が少ないです。\n' +
            '• シュピンデル、マジャールなどの旋回技は必須\n' +
            '• あん馬では旋回技の連続が重要です');
        }
        break;
        
      case 'SR':
        // 吊り輪特有のアドバイス
        if ((groupDistribution[4] ?? 0) < 1) {
          suggestions.add('【吊り輪の力技不足】力技（グループ4の一部）が少ないです。\n' +
            '• 十字懸垂、脱力、倒立などの力技は重要\n' +
            '• 2秒以上の静止が必要です');
        }
        break;
        
      case 'PB':
        // 平行棒特有のアドバイス
        if ((groupDistribution[2] ?? 0) < 2) {
          suggestions.add('【平行棒の支持振動技不足】支持振動技が少ないです。\n' +
            '• ヒーリー、ディアミドフなどを追加\n' +
            '• 振動から力技への移行をスムーズに');
        }
        break;
    }
    
    // 総合的な評価とアドバイスの追加
    if (suggestions.isEmpty && totalSkills > 0) {
      // 基本的な構成は整っている場合の発展的アドバイス
      suggestions.add('【基本構成は良好】現在の構成は基本要件を満たしています。\n' +
        '次のステップ：\n' +
        '• 各技の実施精度を向上させましょう\n' +
        '• 連続技でボーナス点を狙いましょう\n' +
        '• より高難度の技への挑戦を検討してください');
    }
    
    // カテゴリー別の整理とプライオリティ付け
    final categorizedSuggestions = _categorizeSuggestions(suggestions);
    
    return categorizedSuggestions;
  }
  
  // 提案をカテゴリー別に整理
  static List<String> _categorizeSuggestions(List<String> suggestions) {
    final List<String> critical = [];
    final List<String> important = [];
    final List<String> recommended = [];
    
    for (final suggestion in suggestions) {
      if (suggestion.contains('【緊急') || suggestion.contains('必須') || suggestion.contains('不足】')) {
        critical.add(suggestion);
      } else if (suggestion.contains('【') && (suggestion.contains('改善】') || suggestion.contains('不足】'))) {
        important.add(suggestion);
      } else {
        recommended.add(suggestion);
      }
    }
    
    // 優先度順に並べ替え
    final sortedSuggestions = <String>[];
    
    if (critical.isNotEmpty) {
      sortedSuggestions.add('=== 緊急対応が必要な項目 ===');
      sortedSuggestions.addAll(critical);
      sortedSuggestions.add('');
    }
    
    if (important.isNotEmpty) {
      sortedSuggestions.add('=== 重要な改善項目 ===');
      sortedSuggestions.addAll(important);
      sortedSuggestions.add('');
    }
    
    if (recommended.isNotEmpty) {
      sortedSuggestions.add('=== 推奨される改善項目 ===');
      sortedSuggestions.addAll(recommended);
    }
    
    return sortedSuggestions.isEmpty ? suggestions : sortedSuggestions;
  }
  
  
  // 要求充足率の計算
  static double calculateCompletenessScore(String apparatus, Map<int, int> groupDistribution) {
    final requiredGroups = {1, 2, 3, 4, 5}; // すべてのグループをチェック
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

// Cache busting timestamp: ${DateTime.now().millisecondsSinceEpoch}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Debug: Cache clear confirmation
  print('🚀 App started at ${DateTime.now().toIso8601String()} - Cache cleared for HB skills fix');
  
  // Web広告システムの初期化
  if (kIsWeb) {
    // Web広告システムは廃止済み
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gymnastics AI',
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    
    // Navigate to main app after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Gymnastics logo（大きなサイズ）
              Image.asset(
                'assets/logo.png',
                width: 280,
                height: 280,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              // App title
              const Text(
                'Gymnastics AI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
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
  bool canAccessAllApparatus() => isPremium; // モバイルプレミアムのみ
  bool canAccessAnalytics() => isPremium; // モバイルプレミアムのみ
  bool canAccessUnlimitedChat() => isPremium; // モバイルプレミアムのみ
  bool shouldShowAds() => isFree;
}

// D-Score計算使用量追跡クラス
class DScoreUsageTracker {
  // プラットフォーム別の制限を使用
  static int get dailyFreeLimit => PlatformConfig.maxDailyDScoreCalculations;
  static int get dailyBonusLimit => dailyFreeLimit + 1; // ボーナス含めて+1回
  
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
    return true; // 無料版では制限なし
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
    await prefs.setInt(_bonusCreditsKey, currentBonus + 1); // +1回ボーナス
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
    final adUnitId = _getBannerAdId();
    if (kDebugMode) {
      print('🔄 バナー広告読み込み開始 (retry: $retryCount): $adUnitId');
    }
    
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) {
            print('✅ バナー広告読み込み成功');
          }
          _isBannerAdReady = true;
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) {
            print('❌ バナー広告読み込み失敗: $error');
          }
          ad.dispose();
          _isBannerAdReady = false;
          
          // Retry logic with exponential backoff
          if (retryCount < 5) {
            final delaySeconds = (retryCount + 1) * 2;
            if (kDebugMode) {
              print('⏳ ${delaySeconds}秒後にリトライします...');
            }
            Timer(Duration(seconds: delaySeconds), () {
              _loadBannerAd(retryCount: retryCount + 1);
            });
          } else {
            if (kDebugMode) {
              print('❌ バナー広告読み込み最終失敗 - リトライ上限に達しました');
            }
          }
        },
        onAdOpened: (ad) {
          if (kDebugMode) print('📱 バナー広告が開かれました');
        },
        onAdClosed: (ad) {
          if (kDebugMode) print('🔒 バナー広告が閉じられました');
        },
        onAdImpression: (ad) {
          if (kDebugMode) print('👀 バナー広告インプレッション');
        },
      ),
    );
    
    _bannerAd?.load();
    
    // タイムアウト処理
    Timer(Duration(seconds: 30), () {
      if (!_isBannerAdReady && _bannerAd != null) {
        if (kDebugMode) {
          print('⏰ バナー広告読み込みタイムアウト (30秒)');
        }
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
    print('🔍 createBannerAdWidget呼び出し: _isBannerAdReady=$_isBannerAdReady, _bannerAd!=null=${_bannerAd != null}');
    
    if (_isBannerAdReady && _bannerAd != null) {
      print('✅ バナー広告ウィジェット作成成功');
      return Container(
        height: _bannerAd!.size.height.toDouble(),
        width: _bannerAd!.size.width.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    print('❌ バナー広告ウィジェット作成失敗 - 広告準備未完了');
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
  
  // デバッグ機能
  void diagnoseBannerAdStatus() {
    print('=== Banner Ad診断 ===');
    print('_isBannerAdReady: $_isBannerAdReady');
    print('_bannerAd != null: ${_bannerAd != null}');
    print('AdMobConfig.bannerAdUnitId: ${AdMobConfig.bannerAdUnitId}');
    print('kDebugMode: ${kDebugMode}');
    
    if (_bannerAd != null) {
      print('Banner ad size: ${_bannerAd!.size}');
    } else {
      print('Banner ad is null - attempting reload...');
      _loadBannerAd();
    }
  }
  
  // ゲッター
  bool get isBannerAdReady => _isBannerAdReady;
  bool get isInterstitialAdReady => _isInterstitialAdReady;
  bool get isRewardedAdReady => _isRewardedAdReady;
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  AppMode _currentMode = AppMode.chat; // AIチャットを初期画面に設定
  
  // ユーザーサブスクリプション管理
  UserSubscription _userSubscription = UserSubscription(tier: UserTier.free);
  bool _isLoadingSubscription = false;
  bool _isAdmin = false;
  Timer? _subscriptionCheckTimer; // 定期的なサブスクリプション状態チェック用
  
  // 課金システム管理
  PurchaseManager? _purchaseManager;
  bool _isPurchaseManagerInitialized = false;
  
  // 広告システム管理（審査通過まで無効化）
  // late AdManager _adManager;
  // bool _isAdManagerInitialized = false;
  // 広告審査通過まで一時的にダミー変数を定義
  final dynamic _adManager = null;
  final bool _isAdManagerInitialized = false;
  
  // サーバー接続状態
  bool _isServerOnline = false;
  
  // バックグラウンド初期化状態
  bool _isBackgroundInitComplete = false;
  
  // AIチャット関連の状態
  List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isSendingMessage = false;
  
  // 管理者パネル用データ
  Map<String, dynamic>? _adminAnalytics;
  List<dynamic>? _adminUsers;
  bool _isLoadingAdminData = false;

  // プレミアム機能アクセス制御
  bool _checkPremiumAccess(AppMode mode) {
    return true; // 一時的にプレミアム機能を無効化
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
        return true; // モバイル版のみで無料アクセス
    }
  }

  // 安全にモード切り替えを行うメソッド（プレミアムチェックを無効化）
  bool _safeSwitchToMode(AppMode targetMode, {String? featureName}) {
    setState(() {
      _currentMode = targetMode;
    });
    _saveCurrentViewMode(); // タブ切り替えを自動保存
    
    // 特殊処理
    if (targetMode == AppMode.admin) {
      _loadAdminData();
    }
    return true;
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

  // アップグレード促進ダイアログ（無効化）
  void _showUpgradeDialog(String featureName) {
    return; // 無料版では表示しない
    // モバイルアプリ版でプレミアムアップグレードダイアログを表示
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
              if (_purchaseManager?.purchasePending == true)
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
      // モバイルアプリ版のみで購入機能を提供
      
      // PurchaseManagerの初期化確認
      if (_purchaseManager == null || !_isPurchaseManagerInitialized) {
        print('⚠️ 購入システム未初期化 - 初期化を試行します');
        _showMessage('購入システムを初期化しています...');
        
        // 初期化を再試行
        await _initializePurchaseManager();
        
        // 少し待機して状態を更新
        await Future.delayed(Duration(milliseconds: 500));
        
        if (_purchaseManager == null || !_isPurchaseManagerInitialized) {
          print('❌ 購入システムの初期化に失敗');
          _showMessage('購入システムの初期化に失敗しました。アプリを再起動してください。');
          return;
        }
        
        print('✅ 購入システムの初期化成功');
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
      // モバイルアプリ版のみで購入復元機能を提供
      
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

  String _session_id = Uuid().v4(); // 型定義のため保持（使用しない）
  bool _isLoading = false; // 型定義のため保持（使用しない）
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
    if (key == 'ruleBookChat') return 'Gymnastics AI';
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
        return 'Gymnastics AI';
      default:
        return 'Gymnastics AI';
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
    
    // モバイルアプリ版のみ（Web版広告機能は廃止）
    
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

  // Dスコア計算用
  String? _selectedApparatus; // 初期値はnull、復元処理で設定される
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
  
  /// D-Score計算用リワード広告ボタンを表示するかチェック（無効化）
  Future<bool> _canShowDScoreRewardedAd() async {
    return false; // 無料版では広告表示なし
  }
  
  /// D-Score計算用リワード広告を表示（審査通過まで無効化）
  void _showDScoreRewardedAd() async {
    // 広告機能を無効化し、直接ボーナスを付与
    await DScoreUsageTracker.grantCalculationBonus();
    _showSuccessSnackBar('🎉 D-Score計算回数が+1回追加されました！');
    
    // UI更新のため画面をリフレッシュ
    if (mounted) {
      setState(() {});
    }
    
    /*
    // 広告機能一時無効化
    bool success = false; // await _adManager.showRewardedAd();
    
    if (success) {
      await DScoreUsageTracker.grantCalculationBonus();
      _showSuccessSnackBar('🎉 D-Score計算回数が+1回追加されました！');
      
      // UI更新のため画面をリフレッシュ
      if (mounted) {
        setState(() {});
      }
    } else {
      _showErrorDialog('エラー', '広告の読み込みに失敗しました。しばらく時間をおいて再度お試しください。');
    }
    */
  }

  // === ERROR HANDLING METHODS ===
  
  /// Check if device has internet connectivity
  Future<bool> _hasInternetConnection() async {
    final String healthUrl = '${Config.apiBaseUrl}/health';
    print('  └─ 実際のURL: $healthUrl');
    
    try {
      print('  └─ HTTPリクエスト送信中...');
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('  └─ ❌ HTTPタイムアウト（10秒）');
          throw TimeoutException('Connection timeout');
        },
      );
      
      print('  └─ HTTPレスポンス受信: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('  └─ ✅ 正常なレスポンス');
        print('  └─ ボディ: ${response.body}');
        return true;
      } else {
        print('  └─ ❌ エラーレスポンス: ${response.statusCode}');
        print('  └─ ボディ: ${response.body}');
        return false;
      }
    } catch (e) {
      print('  └─ ❌ 例外発生: ${e.runtimeType}');
      print('  └─ エラー詳細: $e');
      return false;
    }
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
      // デバッグ情報の定期出力を無効化（ログが多すぎるため）
      // Timer.periodic(Duration(seconds: 5), (timer) {
      //   _debugAppState();
      // });
    }
    _initializeApp(); // アプリの初期化を開始
    
    // モバイルアプリ版のみ（Web版広告管理は廃止）
    
    // 定期的なサブスクリプション状態チェックを開始
    _startPeriodicSubscriptionCheck();
    
    // データ永続化の読み込み（種目復元を優先）
    print('🔧 INIT: initState開始');
    _loadChatMessages();
    _loadDScoreResults();
    _loadSkillDataCache();
    print('🔧 INIT: _initializeStateAndSkills呼び出し前');
    _initializeStateAndSkills(); // 種目復元と技読み込みを適切な順序で実行
    print('🔧 INIT: initState完了');
  }

  // 種目復元と技読み込みを適切な順序で実行
  void _initializeStateAndSkills() async {
    try {
      print('🔧 DEBUG: _initializeStateAndSkills開始');
      
      // 演技構成状態を復元（種目選択を含む）
      print('🔧 DEBUG: _loadCurrentRoutineState呼び出し前');
      await _loadCurrentRoutineState();
      print('🔧 DEBUG: _loadCurrentRoutineState完了後、_selectedApparatus = $_selectedApparatus');
      
      // 画面状態を復元
      await _loadCurrentViewMode();
      
      // 種目復元後に正しい種目の技データを読み込み
      if (_selectedApparatus != null) {
        print('🔧 DEBUG: _ensureSkillsLoaded呼び出し（種目: $_selectedApparatus）');
        
        // 既存のスキルリストを強制的にクリア
        setState(() {
          _skillList = [];
          _isSkillLoading = true;
        });
        print('🔧 DEBUG: 既存のスキルリストをクリア');
        
        // スキルキャッシュからも削除（強制的に再読み込み）
        final lang = _currentLang == '日本語' ? 'ja' : 'en';
        final wrongCacheKey = 'FX_$lang';
        if (_skillDataCache.containsKey(wrongCacheKey)) {
          _skillDataCache.remove(wrongCacheKey);
          print('🔧 DEBUG: FXのキャッシュを削除');
        }
        
        await _ensureSkillsLoaded(_selectedApparatus!);
        print('🔧 DEBUG: _ensureSkillsLoaded完了');
      } else {
        print('🔧 DEBUG: _selectedApparatusがnullのため技読み込みをスキップ');
      }
    } catch (e) {
      print('状態初期化エラー: $e');
      // エラーの場合はデフォルト状態で続行
      if (_selectedApparatus != null) {
        _ensureSkillsLoaded(_selectedApparatus!);
      }
    }
  }

  // アプリの初期化を非同期で実行（認証不要版）
  void _initializeApp() async {
    try {
      print('アプリ初期化開始（認証不要モード）');
      
      // 即座にUIを表示
      setState(() {
        _isAuthLoading = false;
      });
      
      print('初期UI表示完了');
      
      // バックグラウンド初期化を開始
      _initializeCriticalDataInBackground();
      _initializeAppInBackground();
      
      // 広告初期化を確実に実行（審査通過まで無効化）
      // _initializeAdManager();
      
    } catch (e) {
      print('アプリ初期化エラー: $e');
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
      
      // 一時的に既存のトークンをクリア（新しい形式で生成するため）
      // String? storedToken = prefs.getString('device_auth_token');
      // if (storedToken != null && storedToken.isNotEmpty) {
      //   _token = storedToken;
      //   return; // 早期リターンで高速化
      // }
      
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
      
      // デバイス認証用の固定トークン生成（サーバー互換）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final deviceToken = 'device_${deviceId.substring(0, 8)}_$timestamp';
      _token = deviceToken;
      
      // バックグラウンドで保存（ノンブロッキング）
      prefs.setString('device_auth_token', deviceToken).catchError((e) {
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
        // _initializeAdManager().catchError((e) {
        //   print('広告マネージャー初期化エラー: $e');
        //   return null;
        // }),
      ];
      
      // Skills data loading deferred until needed - 一時的に無効化
      // try {
      //   _initializeSkillsDataLazily();
      // } catch (e) {
      //   print('技データ初期化エラー: $e');
      // }
      
      // Wait for all background tasks with timeout
      await Future.wait(futures, eagerError: false)
          .timeout(Duration(seconds: 15), onTimeout: () {
        print('⚠️ バックグラウンド初期化タイムアウト（15秒）');
        return [];
      });
      
      print('✅ バックグラウンド初期化完了');
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
      print('');
      print('==================================================');
      print('🌐 サーバー接続テスト開始');
      print('==================================================');
      print('📡 URL: ${Config.apiBaseUrl}/health');
      print('🕐 時刻: ${DateTime.now()}');
      
      // Timeout to prevent long delays
      final isConnected = await _hasInternetConnection()
          .timeout(Duration(seconds: 5), onTimeout: () {
            print('⏱️ タイムアウト（5秒）');
            return false;
          });
      
      print('==================================================');
      print('🔍 結果: ${isConnected ? "✅ 接続成功" : "❌ 接続失敗"}');
      print('==================================================');
      print('');
      
      if (mounted) {
        print('  └─ UI更新前: _isServerOnline = $_isServerOnline');
        setState(() {
          _isServerOnline = isConnected;
          print('  └─ setState内: _isServerOnline = $_isServerOnline');
        });
        print('  └─ UI更新後: _isServerOnline = $_isServerOnline');
        
        if (isConnected) {
          print('✅ サーバー接続確認完了: オンライン');
          
          // 確実に状態を更新
          if (!_isServerOnline) {
            print('  └─ 🔄 強制的に状態を更新します');
            setState(() {
              _isServerOnline = true;
            });
            
            // チャットモードの場合、強制的に再描画
            if (_currentMode == AppMode.chat) {
              print('  └─ 🎨 チャット画面を強制再描画');
              Future.delayed(Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {
                    // 強制的に再描画をトリガー
                  });
                }
              });
            }
          }
          
          // 接続成功時はSnackBarを表示しない（静かに接続）
          
          // チャットAPI機能テストを実行 (一時的に無効化 - 基本接続のみで判定)
          // _testChatAPIFunctionality();
        } else {
          print('⚠️ サーバー接続確認完了: オフライン');
          
          // チャットモードの場合のみ軽微な通知を表示
          if (_currentMode == AppMode.chat && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('オフラインモードで動作中'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // 詳細な警告は表示しない（状態インジケーターで十分）
        }
      }
    } catch (e) {
      print('❌ サーバー接続確認エラー: $e');
      print('📋 エラー詳細: ${e.runtimeType}');
      
      if (mounted) {
        setState(() {
          _isServerOnline = false;
        });
        
        // チャットモードの場合のみエラーを表示
        if (_currentMode == AppMode.chat) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('接続に問題があります'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
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
    
    print('🔧 DEBUG: _ensureSkillsLoaded called for $apparatus ($lang)');
    print('🔧 DEBUG: Current _selectedApparatus = $_selectedApparatus');
    print('🔧 DEBUG: Cache keys available: ${_skillDataCache.keys.toList()}');
    print('🔧 DEBUG: Current _skillList length: ${_skillList.length}');
    if (_skillList.isNotEmpty) {
      print('🔧 DEBUG: First skill apparatus: ${_skillList.first.apparatus}');
    }
    
    // 全ての種目で古いキャッシュを強制的にクリア（一度限りの修正）
    print('🔧 DEBUG: ${apparatus}キャッシュを強制的にクリアして再読み込み');
    _skillDataCache.remove(cacheKey);
    
    // Return immediately if already cached
    if (_skillDataCache.containsKey(cacheKey)) {
      print('🔧 DEBUG: Using cached skills for $cacheKey (${_skillDataCache[cacheKey]!.length} skills)');
      setState(() {
        _skillList = _skillDataCache[cacheKey]!;
        _isSkillLoading = false;
      });
      return;
    }
    
    print('DEBUG: Loading skills for $apparatus...');
    // Load skills for this apparatus
    await _loadSkills(apparatus);
    print('DEBUG: Skills loaded for $apparatus (${_skillList.length} skills)');
  }
  
  // 課金システム初期化
  Future<void> _initializePurchaseManager() async {
    // モバイルアプリ版のみで課金システムを初期化
    print('🔥🔥🔥 PURCHASE MANAGER 初期化開始 🔥🔥🔥');
    
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
      final initialized = await _purchaseManager!.initialize();
      if (initialized) {
        setState(() {
          _isPurchaseManagerInitialized = true;
        });
        print('🔥🔥🔥 PURCHASE MANAGER 初期化成功！ 🔥🔥🔥');
      } else {
        print('🔴 PurchaseManager initialization returned false');
        _showMessage('課金システムの初期化に失敗しました。');
      }
    } catch (e) {
      print('🔥🔥🔥 PURCHASE MANAGER 初期化エラー: $e 🔥🔥🔥');
      _showMessage('課金システムの初期化エラー: $e');
      setState(() {
        _isPurchaseManagerInitialized = false;
      });
    }
  }
  
  // 定期的なサブスクリプション状態チェックを開始
  void _startPeriodicSubscriptionCheck() {
    // Web版では課金システムを使用しないためスキップ
    // モバイルアプリ版のみでサブスクリプションチェックを実行
    
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
        if (_isPurchaseManagerInitialized && _purchaseManager != null) {
          _purchaseManager!.checkSubscriptionStatus();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // アプリがバックグラウンドに移行時はデータを保存
        _saveCurrentRoutineState();
        _saveCurrentViewMode();
        break;
    }
  }
  
  // 広告システム初期化（審査通過まで無効化）
  /*
  Future<void> _initializeAdManager() async {
    print('🔍 AdManager初期化開始: shouldShowAds=${_userSubscription.shouldShowAds()}');
    
    if (_userSubscription.shouldShowAds()) {
      // 広告機能一時無効化
      // _adManager = AdManager();
      // try {
      //   await _adManager.initialize();
        setState(() {
          // _isAdManagerInitialized = true;  // 広告機能無効化により削除
        });
        print('✅ AdManager初期化成功');
        
        // 広告読み込み状況を定期的にチェック（デバッグ用）
        Timer.periodic(Duration(seconds: 2), (timer) {
          // 広告機能一時無効化
        if (false) { // _adManager.isBannerAdReady
            print('✅ バナー広告読み込み完了');
            setState(() {}); // UIを更新
            timer.cancel();
          } else {
            print('⏳ バナー広告読み込み中...');
            if (timer.tick > 10) { // 20秒後にタイムアウト
              print('❌ バナー広告読み込みタイムアウト');
              setState(() {}); // UIを更新
              timer.cancel();
            }
          }
        });
        
      } catch (e) {
        print('❌ AdManager初期化失敗: $e');
      }
    } else {
      print('ℹ️ プレミアムユーザーのため広告無効');
    }
  }
  */
  
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
      _saveCurrentRoutineState(); // 演技構成変更を自動保存
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
      print('🔍 Loading skills from: $path for apparatus: [$apparatus]');
      final rawCsv = await rootBundle.loadString(path);
      print('✅ CSV file loaded successfully, length: ${rawCsv.length} characters');
      
      // Use compute for heavy CSV parsing to avoid blocking UI
      final skills = await _parseSkillsCsv(rawCsv, apparatus);
      
      print('Loaded ${skills.length} skills for $apparatus');

      // Cache the results
      _skillDataCache[cacheKey] = skills;
      
      // 永続化キャッシュに保存
      _saveSkillDataCache();

      if (mounted) {
        setState(() {
          _skillList = skills;
          _isSkillLoading = false;
        });
        print('✅ 技データ読み込み完了: ${apparatus} - ${skills.length}技');
      }
    } catch (e) {
      print('❌ Error loading skills: $e');
      print('❌ Attempted to load from: $path for apparatus: $apparatus');
      if (mounted) {
        setState(() {
          _isSkillLoading = false;
          _skillList = []; // 明示的に空リストに設定
        });
      }
    }
  }
  
  // Helper method for parsing CSV in isolate (if needed)
  Future<List<Skill>> _parseSkillsCsv(String rawCsv, String apparatus) async {
    final List<List<dynamic>> listData = const CsvToListConverter().convert(rawCsv);
    
    if (listData.isEmpty) {
      return [];
    }
    
    // 新しい形式: apparatus,name,group,value_letter
    final skills = <Skill>[];
    
    for (int i = 1; i < listData.length; i++) {
      final row = listData[i];
      
      if (row.length >= 4) {
        final skillApparatus = row[0].toString();
        
        if (skillApparatus == apparatus) {
          final groupString = row[2].toString();
          final difficultyString = row[3].toString();
          
          // HB（鉄棒）の場合は詳細デバッグログを出力
          if (apparatus == 'HB' && skills.length < 10) {
            print('🔧 HB DEBUG: 行$i - グループ: "$groupString", 難度: "$difficultyString", 技名: "${row[1]}"');
          }
          
          final skill = Skill.fromMap({
            'id': 'SKILL_${i.toString().padLeft(3, '0')}',
            'apparatus': skillApparatus,
            'name': row[1].toString(),
            'group': groupString, // ローマ数字
            'value_letter': difficultyString,
            'description': row[1].toString(),
          });
          
          // HB（鉄棒）の場合はSkillオブジェクト作成後の値も確認
          if (apparatus == 'HB' && skills.length < 10) {
            print('🔧 HB DEBUG: 変換後 - グループ: ${skill.group}, 難度: "${skill.valueLetter}", 値: ${skill.value}');
          }
          
          skills.add(skill);
        }
      }
    }
    
    if (skills.isEmpty) {
      print('警告: ${apparatus}用の技が見つかりません');
    } else if (apparatus == 'HB') {
      print('🔧 HB DEBUG: 合計${skills.length}個の鉄棒技を読み込みました');
      
      // グループ分布を確認
      final groupCounts = <int, int>{};
      final difficultyCounts = <String, int>{};
      for (final skill in skills) {
        groupCounts[skill.group] = (groupCounts[skill.group] ?? 0) + 1;
        difficultyCounts[skill.valueLetter] = (difficultyCounts[skill.valueLetter] ?? 0) + 1;
      }
      print('🔧 HB DEBUG: グループ分布: $groupCounts');
      print('🔧 HB DEBUG: 難度分布: $difficultyCounts');
    }
    
    // 全ての種目で先にグループ順、次に難度順でソート
    if (apparatus == 'VT') {
      // 跳馬は技名順のまま
      skills.sort((a, b) => a.name.compareTo(b.name));
    } else {
      // その他の種目はグループ→難度→技名順
      skills.sort((a, b) {
        // まずグループで比較
        int groupComparison = a.group.compareTo(b.group);
        if (groupComparison != 0) return groupComparison;
        
        // グループが同じなら難度で比較
        int diffComparison = a.valueLetter.compareTo(b.valueLetter);
        if (diffComparison != 0) return diffComparison;
        
        // 最後に技名で比較
        return a.name.compareTo(b.name);
      });
      
      print('🔧 ${apparatus} DEBUG: ソート後の最初の10技:');
      for (int i = 0; i < skills.length && i < 10; i++) {
        final skill = skills[i];
        print('🔧 ${apparatus} DEBUG: [$i] G${skill.group}-${skill.valueLetter}: ${skill.name}');
      }
    }
    
    return skills;
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





  // 連続技グループを適切に構築
  List<List<Skill>> _buildConnectedSkillGroups(List<Skill> skills, List<int> connectionGroups) {
    final routine = <List<Skill>>[];
    
    if (skills.isEmpty) return routine;
    
    List<Skill> currentGroup = [skills[0]];
    int currentConnectionId = connectionGroups.isNotEmpty ? connectionGroups[0] : 0;
    
    for (int i = 1; i < skills.length; i++) {
      final connectionId = i < connectionGroups.length ? connectionGroups[i] : 0;
      
      // 同じ連続技IDを持つ技同士は連続技として扱う（0は連続技ではない）
      if (connectionId != 0 && connectionId == currentConnectionId) {
        currentGroup.add(skills[i]);
      } else {
        // 連続技グループを確定し、新しいグループを開始
        routine.add(List.from(currentGroup));
        currentGroup = [skills[i]];
        currentConnectionId = connectionId;
      }
    }
    
    // 最後のグループを追加
    if (currentGroup.isNotEmpty) {
      routine.add(currentGroup);
    }
    
    return routine;
  }

  // プレミアム誘導ダイアログ（計算制限時）
  void _showCalculationLimitDialog() async {
    final dailyUsage = await DScoreUsageTracker.getDailyUsage();
    final bonusCredits = await DScoreUsageTracker.getBonusCredits();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text('計算制限に達しました'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本日の使用状況:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('・無料枠: $dailyUsage/${DScoreUsageTracker.dailyFreeLimit}回'),
              Text('・ボーナス: ${bonusCredits}回'),
              const SizedBox(height: 16),
              const Text('続けてD-Score計算を行うには:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (bonusCredits == 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('広告を見て+1回計算')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // プレミアム表示を削除
            ],
          ),
          actions: [
            if (bonusCredits == 0)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDScoreRewardedAd();
                },
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('広告を見る'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showUpgradeDialog('プレミアム機能');
              },
              icon: const Icon(Icons.star, size: 16),
              label: const Text('プレミアム'),
              style: TextButton.styleFrom(foregroundColor: Colors.amber),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  // D-スコアを再計算
  Future<void> _calculateDScoreFromRoutine() async {
    print('CALCULATION_START: 計算処理開始');
    print('CALCULATION_START: 種目: $_selectedApparatus, 技数: ${_routine.length}');
    
    if (_selectedApparatus == null || _routine.isEmpty) {
      print('CALCULATION_START: 計算処理終了（条件不足）');
      return;
    }
    
    // 使用量チェックを無効化（無料版では制限なし）
    
    // 連続技グループを適切に構築
    final routine = _buildConnectedSkillGroups(_routine, _connectionGroups);
    
    // デバッグ情報
    print('DEBUG_CONNECTION: 連続技グループ構築結果');
    print('DEBUG_CONNECTION: 種目: $_selectedApparatus');
    print('DEBUG_CONNECTION: _connectionGroups: $_connectionGroups');
    print('DEBUG_CONNECTION: _routine技詳細:');
    for (int i = 0; i < _routine.length; i++) {
      final skill = _routine[i];
      print('DEBUG_CONNECTION:   [$i] ${skill.name}: グループ${skill.group}, 難度レター${skill.valueLetter}, 難度値${skill.value}');
    }
    for (int i = 0; i < routine.length; i++) {
      final group = routine[i];
      print('DEBUG_CONNECTION: グループ${i + 1}: ${group.map((s) => '${s.name}(難度値:${s.value})').join(' → ')}');
    }
    
    // D-スコアを計算
    final result = calculateDScore(_selectedApparatus!, routine);
    print('  計算結果 - 連続技ボーナス: ${result.connectionBonus}');
    
    // 使用量を記録
    await DScoreUsageTracker.recordDScoreUsage(_userSubscription);
    
    setState(() {
      _dScoreResult = result;
    });
    
    // D-スコア計算結果を自動保存
    _saveDScoreResults();
    
    // 無料ユーザーの場合、計算完了後にインタースティシャル広告を表示（審査通過まで無効化）
    /*
    // 広告機能一時無効化
    if (false) { // _userSubscription.shouldShowAds() && _isAdManagerInitialized
      // 計算結果の表示後、少し遅らせて広告を表示（UX向上のため）
      Future.delayed(const Duration(milliseconds: 1500), () {
        _showCalculationCompletedWithAd();
      });
    }
    */
  }

  // 計算完了時の広告表示とプレミアム誘導（審査通過まで無効化）
  void _showCalculationCompletedWithAd() {
    // 広告機能を無効化
    return;
    
    /*
    // 広告機能一時無効化
    if (true) { // !_userSubscription.shouldShowAds() || !_isAdManagerInitialized
      return;
    }
    
    // 広告機能一時無効化
    // if (_adManager.isInterstitialAdReady) {
    //   _adManager.showInterstitialAd();
      
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
    */
  }
  
  // プレミアムアップグレード誘導（無効化）
  void _showPremiumUpgradePrompt() {
    return; // 無料版では表示しない
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
      child: _buildMainScaffold(),
    );
  }
  
  Widget _buildMainScaffold() {
    return Scaffold(
        appBar: AppBar(
          titleSpacing: 0, // タイトル領域のスペーシングを最小化
          title: SizedBox(
            width: MediaQuery.of(context).size.width * 0.75, // 画面幅の75%まで使用
            child: _currentMode == AppMode.chat 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getAppBarTitle(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    FutureBuilder<String>(
                      future: ChatUsageTracker.getUsageStatus(_userSubscription),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            snapshot.data!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                )
              : Text(
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
            // AIチャットモードの場合はリセットボタンとフィードバックボタンを表示
            if (_currentMode == AppMode.chat) ...[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  setState(() {
                    _chatMessages.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_currentLang == '日本語' ? 'チャットをリセットしました' : 'Chat has been reset'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: _currentLang == '日本語' ? 'チャットをリセット' : 'Reset Chat',
              ),
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
                        const Icon(Icons.feedback, size: 20),
                        const SizedBox(width: 8),
                        Text(_currentLang == '日本語' ? 'フィードバック' : 'Feedback'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            // その他のモードでは既存のアクションを表示
            if (_currentMode != AppMode.chat) ...[
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
          ],
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
                        // プレミアムマークを非表示
                        // Icon(
                        //   _userSubscription.isPremium ? Icons.star : Icons.star_border,
                        //   color: _userSubscription.isPremium ? Colors.amber : Colors.grey.shade400,
                        //   size: 28,
                        // ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ユーザー',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _userSubscription.isPremium ? Colors.amber.shade200 : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Premium upgrade section removed - free version
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
              const Divider(),
              // 利用規約
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(_currentLang == '日本語' ? '利用規約' : 'Terms of Service'),
                onTap: () {
                  Navigator.of(context).pop();
                  _launchURL('https://daito-iwa.github.io/gym/terms.html');
                },
              ),
              // プライバシーポリシー
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(_currentLang == '日本語' ? 'プライバシーポリシー' : 'Privacy Policy'),
                onTap: () {
                  Navigator.of(context).pop();
                  _launchURL('https://daito-iwa.github.io/gym/privacy.html');
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
          // バナー広告表示（審査通過まで無効化）
          /*
          // 広告機能一時無効化
          if (false) // _userSubscription.shouldShowAds() && _isAdManagerInitialized
            Container(
              margin: EdgeInsets.only(bottom: isMobile ? 12.0 : 16.0),
              child: _buildBannerAd(),
            ),
          */
          
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
                              _isSkillLoading = true; // ローディング状態に設定
                            });
                            _saveCurrentRoutineState(); // 種目切り替えを自動保存
                            _ensureSkillsLoaded(newValue); // 非同期で技データ読み込み
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
                              // プレミアムチェックを削除
                              _saveCurrentRoutine();
                            } : null,
                            tooltip: '構成を保存',
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 20),
                            onPressed: () {
                              // プレミアムチェックを削除
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
                        : _routine.isEmpty 
                          ? const Center(
                              child: Text(
                                '技を選択して追加してください',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ReorderableListView(
                              shrinkWrap: true,
                              onReorder: _onReorderSkills,
                              physics: const NeverScrollableScrollPhysics(), // スクロール競合を防ぐ
                              buildDefaultDragHandles: false, // カスタムドラッグハンドルを使用
                              children: _buildReorderableRoutineDisplay(),
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
                              // プレミアムチェックを削除
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
                                // 使用量チェックを無効化（無料版では制限なし）
                                
                                // 床運動の場合、バランス技チェック（警告のみ、計算は続行）
                                if (_selectedApparatus!.toLowerCase() == 'floor' || 
                                    _selectedApparatus!.toLowerCase() == 'fx') {
                                  final floorError = _checkFloorRequirements(_routine);
                                  if (floorError != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('警告: $floorError（計算は実行されます）'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                    // return を削除 - 計算を続行
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
                                print('CALCULATION_START: 計算ボタン押下');
                                print('CALCULATION_START: 種目: $_selectedApparatus, 技数: ${_routine.length}');
                                print('CALCULATION_START: _connectionGroups: $_connectionGroups');
                                print('CALCULATION_START: routineForCalculation: ${routineForCalculation.length}グループ');
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
                                
                                // D-スコア計算結果を自動保存
                                _saveDScoreResults();
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
                        
                        // 🌟 新機能: 最強AIコーチによる演技分析ボタン
                        if (_dScoreResult != null) ...[
                          const SizedBox(height: 12),
                          // AIで詳細分析ボタンを削除（AIチャットで直接質問する方式に変更）
                          // なぜこの点数？ボタンを削除（AIチャットで直接質問する方式に変更）
                        ],
                      ],
                    ),
                    
                    // 使用回数表示を削除
                    
                    // D-Score計算制限時の広告視聴ボタン（Row外に配置）
                    FutureBuilder<bool>(
                      future: _canShowDScoreRewardedAd(),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => _showDScoreRewardedAd(),
                                  icon: const Icon(Icons.play_circle_filled, size: 20),
                                  label: const Text(
                                    '🎬 広告を見て+1回計算',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
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
        
        // 技選択カード表示（ローディング状態も考慮）
        Container(
          height: isMobile ? 150 : 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isSkillLoading ? 
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('技データを読み込み中...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ) :
            _getFilteredSkillList().isEmpty ? 
              const Center(
                child: Text('技が見つかりません', style: TextStyle(color: Colors.grey)),
              ) :
              ListView.builder(
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
                                      _selectedApparatus == 'VT' 
                                          ? skill.valueLetter // 跳馬は valueLetter のみ表示
                                          : '${skill.valueLetter}(${skill.value.toStringAsFixed(1)})',
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
                       (_selectedApparatus!.toLowerCase() == 'vault' || _selectedApparatus!.toLowerCase() == 'vt') 
                         ? _routine.length < 1 // 跳馬は1技まで
                         : _routine.length < 8) // その他は8技未満
                ? () {
                    HapticFeedback.mediumImpact();
                    if (_isEditingSkill) {
                      // 編集モードの場合は保存処理
                      _saveEditedSkill();
                    } else {
                      // 通常モードの場合は追加処理
                      bool canAdd = true;
                      String errorMessage = '';
                      
                      if (_selectedApparatus != null) {
                        if (_selectedApparatus!.toLowerCase() == 'vault' || 
                            _selectedApparatus!.toLowerCase() == 'vt') {
                          // 跳馬の場合は1技のみ
                          if (_routine.length >= 1) {
                            canAdd = false;
                            errorMessage = '跳馬は1技のみ選択可能です';
                          }
                        } else {
                          // 跳馬以外の場合
                          
                          // 8技制限チェック
                          if (_routine.length >= 8) {
                            canAdd = false;
                            errorMessage = '演技構成は最大8技までです';
                          }
                          
                          // グループ制限チェック（全グループは最大4技）
                          if (canAdd) {
                            final groupCounts = _countSkillsPerGroup(_routine);
                            final currentGroupCount = groupCounts[_selectedSkill!.group] ?? 0;
                            if (currentGroupCount >= 4) {
                              canAdd = false;
                              errorMessage = 'グループ${_selectedSkill!.group}は最大4技までです';
                            }
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
                        _saveCurrentRoutineState(); // 演技構成変更を自動保存
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
    final difficulties = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    
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
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // メインスコア表示
            Center(
              child: Column(
                children: [
                  Text(
                    'D-Score',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.totalDScore.toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: isMobile ? 42 : 52,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[700],
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'points',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // スコア内訳
            Text(
              'スコア内訳',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            _buildCleanScoreRow(
              '難度点',
              result.difficultyValue,
              Colors.blue[100]!,
              Colors.blue[700]!,
              isMobile
            ),
            if (_selectedApparatus != 'VT') ...[
              const SizedBox(height: 12),
              _buildCleanScoreRow(
                'グループ要求 (${result.fulfilledGroups}/${result.requiredGroups})',
                result.groupBonus,
                Colors.orange[100]!,
                Colors.orange[700]!,
                isMobile
              ),
            ],
            if (_selectedApparatus == 'FX' || _selectedApparatus == 'HB') ...[
              const SizedBox(height: 12),
              _buildCleanScoreRow(
                '連続技ボーナス',
                result.connectionBonus,
                Colors.green[100]!,
                Colors.green[700]!,
                isMobile
              ),
            ],
            
            // ND減点表示（減点がある場合のみ）
            if (result.neutralDeductions > 0) ...[
              const SizedBox(height: 12),
              _buildCleanScoreRow(
                'ND減点',
                -result.neutralDeductions,  // マイナス値として表示
                Colors.red[100]!,
                Colors.red[700]!,
                isMobile
              ),
              // 減点内訳の詳細表示
              if (result.deductionBreakdown.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '減点内訳:',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...result.deductionBreakdown.entries.map((entry) => 
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '• ${entry.key}: -${entry.value.toStringAsFixed(1)}点',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: Colors.red[600],
                            ),
                          ),
                        ),
                      ).toList(),
                    ],
                  ),
                ),
              ],
            ],
            
            // チャットに送信ボタン
            if (_currentMode == 'ai_chat') ...[
              const SizedBox(height: 24),
              // なぜその点数？ボタンを削除（AIチャットで直接質問する方式に変更）
              const SizedBox(height: 12),
              // 改善提案ボタン
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _sendAnalysisToChat(result);
                  },
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text('改善提案をもらう'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCleanScoreRow(String label, double value, Color backgroundColor, Color textColor, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(3),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
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


  // チャット用のUI - サーバー接続復旧
  Widget _buildChatInterface() {
    // AIチャット機能が有効の場合は実際のチャット画面を表示
    if (AppConfig.enableAIChat) {
      return _buildActualChatInterface();
    } else {
      return _buildComingSoonInterface();
    }
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

  // 実際のAIチャット画面
  Widget _buildActualChatInterface() {
    return SafeArea(
      child: Column(
        children: [
          // チャット状態バーを削除（リセットボタンはAppBarに移動済み）
          
          // チャットメッセージリスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AIチャットヘッダー
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      // 接続状態バッジ
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isServerOnline 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isServerOnline 
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isServerOnline ? Icons.cloud_done : Icons.cloud_off, 
                              size: 14, 
                              color: _isServerOnline ? Colors.green : Colors.orange
                            ),
                            SizedBox(width: 4),
                            Text(
                              _isServerOnline ? 'オンライン' : 'オフライン',
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.w500,
                                color: _isServerOnline ? Colors.green : Colors.orange
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // メッセージエリア
                Expanded(
                  child: _chatMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '体操のルールや技について\n何でも質問してください！',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isUser = message['role'] == 'user';
                      
                      return Padding(
                        padding: EdgeInsets.only(
                          left: isUser ? 40 : 8,
                          right: isUser ? 8 : 40,
                          top: 4,
                          bottom: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.sports_gymnastics,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser 
                                      ? Colors.blue 
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(18),
                                    topRight: Radius.circular(18),
                                    bottomLeft: isUser ? Radius.circular(18) : Radius.circular(4),
                                    bottomRight: isUser ? Radius.circular(4) : Radius.circular(18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  message['content'],
                                  style: TextStyle(
                                    color: isUser ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) ...[
                              SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey,
                                child: Icon(
                                  Icons.person,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // メッセージ入力エリア
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText: '体操について質問してください...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSendingMessage ? null : () => _sendMessage(_chatController.text),
                    icon: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.white,
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

  // 分析結果をチャットに送信して改善提案を取得
  Future<void> _sendAnalysisToChat(DScoreResult result) async {
    String analysisText;
    
    if (_selectedApparatus == 'VT') {
      // 跳馬専用の分析メッセージ
      analysisText = '''跳馬分析結果：
🏆 Dスコア: ${result.totalDScore.toStringAsFixed(1)}点

📝 基本情報:
- 種目: 跳馬 (VT)
- 跳躍技: ${_routine.length}技

この跳躍について技術的な改善提案をお願いします。''';
    } else {
      // その他種目の分析メッセージ（従来形式）
      analysisText = '''演技構成分析結果：
🏆 Dスコア: ${result.totalDScore.toStringAsFixed(3)}点
📊 内訳:
- 難度点: ${result.difficultyValue.toStringAsFixed(3)}点''' + 
      ((_selectedApparatus != 'VT') 
          ? '\n- グループ要求 (${result.fulfilledGroups}/${result.requiredGroups}): ${result.groupBonus.toStringAsFixed(3)}点' 
          : '') +
      ((_selectedApparatus == 'FX' || _selectedApparatus == 'HB') 
          ? '\n- 連続技ボーナス: ${result.connectionBonus.toStringAsFixed(3)}点' 
          : '') +
      (result.neutralDeductions > 0 
          ? '\n⚠️ ND減点: -${result.neutralDeductions.toStringAsFixed(1)}点' 
          : '') +
      (result.deductionBreakdown.isNotEmpty 
          ? '\n  減点内訳: ${result.deductionBreakdown.entries.map((e) => '${e.key} -${e.value.toStringAsFixed(1)}点').join(', ')}' 
          : '') + '''

📝 基本情報:
- 種目: $_selectedApparatus
- 技数: ${_routine.length}技

この構成について改善提案をお願いします。特にND減点がある場合は、その解決方法を教えてください。''';
    }
    
    // チャットに送信
    await _sendMessage(analysisText);
  }

  // AIチャットメッセージ送信
  Future<void> _sendMessage(String message) async {
    print('=== _sendMessage 開始 ===');
    print('メッセージ: $message');
    print('_isServerOnline の現在値: $_isServerOnline');
    
    if (message.trim().isEmpty) return;
    
    // Web版の使用制限チェック（廃止済み）
    if (PlatformConfig.isWeb) {
      // Web版の使用制限は廃止済み
    } else {
      // モバイル版の制限チェック
      bool canSend = await ChatUsageTracker.canSendMessage(_userSubscription);
      if (!canSend) {
        setState(() {
          _chatMessages.add({
            'role': 'system',
            'content': '❌ **利用制限に達しました**\n\n'
                'AIチャット機能は1日${ChatUsageTracker.dailyFreeLimit}回、月${ChatUsageTracker.monthlyFreeLimit}回までご利用いただけます。\n\n'
                '明日または来月になると、再度ご利用いただけます。\n'
                'それまでは、D-score計算や技検索などの他の機能をお使いください。',
            'timestamp': DateTime.now(),
          });
        });
        return;
      }
    }
    
    setState(() {
      _isSendingMessage = true;
      _chatMessages.add({
        'role': 'user',
        'content': message,
        'timestamp': DateTime.now(),
      });
    });
    
    _chatController.clear();
    
    try {
      print('🔍 _sendMessage デバッグ: サーバーを優先使用');
      
      // Web版・モバイル版共通: まずサーバーを試行
      print('🔑 匿名ユーザーモードでサーバーに送信');
      
      // サーバーにメッセージを送信 (認証ヘッダーなし = 匿名ユーザー)
      final response = await http.post(
        Uri.parse('${Config.apiUrl}/chat/message'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': message,
          'conversation_id': null,
          'context': _buildContextData(),
        }),
      );
      
      print('📤 サーバーレスポンス: ${response.statusCode}');
      print('📤 レスポンス本文: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ サーバーから正常な回答を受信');
        setState(() {
          _chatMessages.add({
            'role': 'assistant',
            'content': responseData['response'] ?? '申し訳ありません。サーバーから応答がありませんでした。',
            'timestamp': DateTime.now(),
          });
        });
        
        // 使用回数を記録（サーバー応答成功時のみ）
        if (PlatformConfig.isWeb) {
          // Web版の使用制限は廃止済み
        } else {
          await ChatUsageTracker.recordChatUsage(_userSubscription);
        }
      } else if (response.statusCode == 401) {
        // 認証エラーの場合、匿名ユーザーとしてローカル回答にフォールバック
        print('認証エラー - ローカル回答にフォールバック');
        
        String? fallbackResponse = _getLocalGymnasticsResponse(message);
        if (fallbackResponse != null) {
          setState(() {
            _chatMessages.add({
              'role': 'assistant',
              'content': fallbackResponse + '\n\n⚠️ （認証エラーのためローカル情報で回答しました）',
              'timestamp': DateTime.now(),
            });
          });
          // フォールバック回答も使用回数として記録
          if (PlatformConfig.isWeb) {
            // Web版の使用制限は廃止済み
          } else {
            await ChatUsageTracker.recordChatUsage(_userSubscription);
          }
        } else {
          setState(() {
            _chatMessages.add({
              'role': 'assistant',
              'content': '申し訳ありません。現在サーバーに接続できません。体操に関する基本的な質問をお試しください。',
              'timestamp': DateTime.now(),
            });
          });
        }
      } else {
        print('Server error: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('Request URL: ${Config.apiUrl}/chat/message');
        print('Request headers: ${json.encode({
          'Content-Type': 'application/json',
          if (_token != null && _token!.isNotEmpty) 
            'Authorization': 'Bearer ${_token!.length > 20 ? _token!.substring(0, 20) : _token}...', // 安全なトークン表示
        })}');
        throw Exception('Server error: ${response.statusCode}');
      }
      
    } catch (e) {
      print('Chat error: $e');
      
      // サーバーエラー時のフォールバック: ローカル回答を試行
      String? fallbackResponse = _getLocalGymnasticsResponse(message);
      if (fallbackResponse != null) {
        setState(() {
          _chatMessages.add({
            'role': 'assistant',
            'content': fallbackResponse + '\n\n⚠️ （デバッグ: _isServerOnline=$_isServerOnline, エラー: $e）',
            'timestamp': DateTime.now(),
          });
        });
        // 使用回数を記録
        if (PlatformConfig.isWeb) {
          // Web版の使用制限は廃止済み
        } else {
          await ChatUsageTracker.recordChatUsage(_userSubscription);
        }
      } else {
        setState(() {
          _chatMessages.add({
            'role': 'assistant',
            'content': '申し訳ありません。現在AIチャット機能に一時的な問題が発生しています。しばらく後に再試行してください。',
            'timestamp': DateTime.now(),
          });
        });
      }
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
      
      // チャット履歴を保存
      _saveChatMessages();
    }
  }

  // D-スコア計算の詳細説明をAIチャットに送信
  Future<void> _sendScoreExplanationToChat(DScoreResult result) async {
    if (_selectedApparatus == null) return;
    
    final explanationText = '''🤔 **D-スコア計算の詳細説明をお願いします**

🏅 **計算結果**：
- **総合D-スコア**: ${result.totalDScore.toStringAsFixed(3)}点

📊 **内訳**：
- 難度点: ${result.difficultyValue.toStringAsFixed(3)}点''' + 
    ((_selectedApparatus != 'VT') 
        ? '\n- グループ要求 (${result.fulfilledGroups}/${result.requiredGroups}): ${result.groupBonus.toStringAsFixed(3)}点' 
        : '') +
    ((_selectedApparatus == 'FX' || _selectedApparatus == 'HB') 
        ? '\n- 連続技ボーナス: ${result.connectionBonus.toStringAsFixed(3)}点' 
        : '') +
    (result.neutralDeductions > 0 
        ? '\n⚠️ ND減点: -${result.neutralDeductions.toStringAsFixed(1)}点' 
        : '') +
    (result.deductionBreakdown.isNotEmpty 
        ? '\n  減点内訳: ${result.deductionBreakdown.entries.map((e) => '${e.key} -${e.value.toStringAsFixed(1)}点').join(', ')}' 
        : '') + '''

💡 **質問**：
なぜこの点数になったのか、計算過程を詳しく教えてください。特に以下を知りたいです：

1. **難度点${result.difficultyValue.toStringAsFixed(3)}点の内訳** - どの技が選ばれて、なぜこの合計になったのか？
2. **グループ要求${result.groupBonus.toStringAsFixed(3)}点の計算根拠** - 各グループのボーナス点の詳細
${(_selectedApparatus == 'FX' || _selectedApparatus == 'HB') ? '3. **連続技ボーナス${result.connectionBonus.toStringAsFixed(3)}点の詳細** - どの技の組み合わせでボーナスが発生したか？' : ''}
${result.neutralDeductions > 0 ? '4. **ND減点の詳細** - なぜこの減点が適用されたか？' : ''}

📋 **演技情報**：
- 種目: $_selectedApparatus
- 技数: ${_routine.length}技
- 現在の技構成: ${_routine.map((skill) => '${skill.name}(${skill.valueLetter}難度・G${skill.group})').join(', ')}

FIG公式ルールに基づいて、計算過程を分かりやすく説明してください。''';
    
    await _sendMessage(explanationText);
  }

  // AIに送信するコンテキストデータを構築
  Map<String, dynamic> _buildContextData() {
    return {
      'user_profile': {
        'current_apparatus': _selectedApparatus,
        'skill_level': 'intermediate', // 今後ユーザーレベル判定機能を追加予定
        'language': _currentLang,
      },
      'current_routine': {
        'apparatus': _selectedApparatus,
        'skills': _routine.map((skill) => {
          'name': skill.name,
          'group': skill.group,
          'difficulty_letter': skill.valueLetter,
          'difficulty_value': skill.value,
          'description': skill.description,
        }).toList(),
        'connection_groups': _connectionGroups,
        'total_skills': _routine.length,
      },
      'calculation_result': _dScoreResult != null ? {
        'total_d_score': _dScoreResult!.totalDScore,
        'difficulty_value': _dScoreResult!.difficultyValue,
        'group_bonus': _dScoreResult!.groupBonus,
        'connection_bonus': _dScoreResult!.connectionBonus,
        'neutral_deductions': _dScoreResult!.neutralDeductions,
        'deduction_breakdown': _dScoreResult!.deductionBreakdown,
        'fulfilled_groups': _dScoreResult!.fulfilledGroups,
        'required_groups': _dScoreResult!.requiredGroups,
        'total_skills': _dScoreResult!.totalSkills,
      } : null,
      'apparatus_rules': _selectedApparatus != null ? {
        'apparatus': _selectedApparatus,
        'group_requirements': _selectedApparatus != 'VT' ? 4 : 0,
        'skill_limit': _selectedApparatus != 'VT' ? 8 : 1,
        'supports_connections': _selectedApparatus == 'FX' || _selectedApparatus == 'HB',
      } : null,
      'knowledge_base': {
        'rulebook_version': '2025-2028',
        'scoring_system': 'FIG_official',
        'language': _currentLang,
      }
    };
  }

  // ローカル体操データベースから回答を生成
  String? _getLocalGymnasticsResponse(String message) {
    try {
      // 基本的な挨拶や簡単な質問に先に対応
      final lowerMessage = message.toLowerCase();
      
      if (lowerMessage.contains('こんにちは') || lowerMessage.contains('hello') || lowerMessage.contains('はじめまして')) {
        return 'こんにちは！AIアシスタントです。\n\n体操のルールや技について何でもお聞きください。例えば：\n\n• 「床のグループ1の技を教えて」\n• 「つり輪のD難度技は？」\n• 「跳馬のルールは？」\n\nお気軽にご質問ください！';
      }
      
      if (lowerMessage.contains('ありがとう') || lowerMessage.contains('thank')) {
        return 'どういたしまして！他にも体操について質問がございましたら、お気軽にお聞きください。';
      }
      
      if (lowerMessage.contains('テスト') || lowerMessage.contains('test')) {
        return '✅ AIチャット機能が正常に動作しています！\n\n現在はローカルデータベースでの回答機能をテスト中です。サーバー接続が完了すると、より高度なAI機能をご利用いただけます。';
      }
      
      // GymnasticsExpertDatabaseを使用して回答を生成
      String response = GymnasticsExpertDatabase.getExpertAnswer(message);
      
      if (response.isNotEmpty && !response.contains('申し訳ありません')) {
        // ローカル回答であることを明示
        return '$response\n\n💡 この回答はローカルデータベースから生成されました。より詳細な情報については、サーバー接続後にご利用ください。';
      }
      
      // 回答できない場合はnullを返す（サーバーにフォールバック）
      return null;
      
    } catch (e) {
      print('Local response error: $e');
      return null;
    }
  }

  
  // Web版インタースティシャル広告表示
  void _showWebInterstitialAd(String adType) {
    return; // Web版広告機能は廃止
    
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
                          child: Container(), // Web版広告は廃止
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

  // バナー広告ウィジェット（審査通過まで無効化）
  Widget _buildBannerAd() {
    // 広告機能を無効化し、空のコンテナを返す
    return SizedBox.shrink();
    
    /*
    // Web版広告機能は廃止 - モバイル版のみでAdMob使用
    {
      // モバイル版：既存のAdMob実装
      // 広告機能一時無効化
      final adWidget = null; // _adManager?.createBannerAdWidget();
      
      if (adWidget != null) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: adWidget,
        );
      } else {
        // 広告読み込み中または失敗時のプレースホルダー
        return Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '広告読み込み中...',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        );
      }
    }
    */
  }

  
  // 演技構成を表示するWidgetリストを構築
  // 技の並び替え処理
  void _onReorderSkills(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      
      // 技をリストから取り出して新しい位置に挿入
      final skill = _routine.removeAt(oldIndex);
      final connectionGroup = _connectionGroups.removeAt(oldIndex);
      
      _routine.insert(newIndex, skill);
      _connectionGroups.insert(newIndex, connectionGroup);
      
      // D-Score結果をリセット（順序が変わったため再計算が必要）
      _dScoreResult = null;
    });
    _saveCurrentRoutineState(); // 並び替え変更を自動保存
  }

  // ReorderableListView用の技表示リスト作成
  List<Widget> _buildReorderableRoutineDisplay() {
    List<Widget> widgets = [];
    
    for (int i = 0; i < _routine.length; i++) {
      final skill = _routine[i];
      final connectionGroupId = _connectionGroups[i];
      final isSelected = _selectedSkillIndex == i;
      final isConnected = connectionGroupId != 0;
      final isBeingEdited = _isEditingSkill && _selectedSkillIndex == i;
      
      // ReorderableListViewでは各アイテムにuniqueなkeyが必要
      widgets.add(
        Container(
          key: Key('skill_$i'), // 一意のキーを設定
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              
              // デバッグ: 技選択ダイアログの呼び出し情報
              print('🔧 DEBUG: 技選択ダイアログを開始');
              print('🔧 DEBUG: 種目: $_selectedApparatus');
              print('🔧 DEBUG: 技リスト数: ${_skillList.length}');
              print('🔧 DEBUG: 現在の技: ${skill.name}');
              
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (BuildContext dialogContext) {
                  print('🔧 DEBUG: ダイアログビルダー呼び出し');
                  return _SkillSelectionDialog(
                    currentSkill: skill,
                    skillList: _skillList,
                    currentLang: _currentLang,
                    apparatus: _selectedApparatus,
                    onSkillSelected: (Skill selectedSkill) {
                      print('🔧 DEBUG: 技が選択されました: ${selectedSkill.name}');
                      Navigator.of(dialogContext).pop();
                      setState(() {
                        _routine[i] = selectedSkill;
                        _dScoreResult = null;
                        _selectedSkillIndex = null;
                      });
                    },
                  );
                },
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 1.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _getSkillBackgroundColor(isSelected, isBeingEdited, isConnected),
                borderRadius: BorderRadius.circular(8.0),
                border: isSelected 
                  ? Border.all(color: Colors.blue, width: 2.0)
                  : isConnected 
                    ? Border.all(color: Colors.green.shade300, width: 1.5)
                    : Border.all(color: Colors.grey.shade300, width: 1.0),
              ),
              child: Row(
                children: [
                  // ドラッグハンドル（カスタム実装）
                  ReorderableDragStartListener(
                    index: i,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // 技情報
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i + 1}. ${skill.name}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // 削除ボタン
                            InkWell(
                              onTap: () {
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildCompactSkillBadge('${skill.valueLetter}難度', _getDifficultyColor(skill.valueLetter), true),
                            const SizedBox(width: 6),
                            _buildCompactSkillBadge('グループ${skill.group}', Colors.teal, true),
                            if (isConnected) ...[
                              const SizedBox(width: 6),
                              _buildCompactSkillBadge('連続', Colors.orange, true),
                            ],
                          ],
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

      // 連続技の線を追加（次の技と連続している場合）
      if (i < _routine.length - 1 && 
          connectionGroupId != 0 && 
          _connectionGroups[i + 1] == connectionGroupId) {
        widgets.add(
          Container(
            key: Key('connection_$i'), // 連続技の線にも一意のキーを設定
            padding: const EdgeInsets.only(left: 30.0),
            child: Container(
              width: 2,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  // 背景色を取得するヘルパーメソッド
  Color _getSkillBackgroundColor(bool isSelected, bool isBeingEdited, bool isConnected) {
    if (isBeingEdited) {
      return Colors.blue.shade50;
    } else if (isSelected) {
      return Colors.blue.shade100;
    } else if (isConnected) {
      return Colors.green.shade100;
    } else {
      return Colors.grey.shade50;
    }
  }

  // 従来の_buildRoutineDisplayメソッドは下位互換性のため保持
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
    
    print('DEBUG_CONVERT: 連続技グループ変換開始');
    print('DEBUG_CONVERT: _routine.length: ${_routine.length}');
    print('DEBUG_CONVERT: _connectionGroups: $_connectionGroups');
    
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
    
    print('DEBUG_CONVERT: 変換結果: ${grouped.length}グループ');
    for (int i = 0; i < grouped.length; i++) {
      final group = grouped[i];
      print('DEBUG_CONVERT: グループ${i + 1}: ${group.map((s) => '${s.name}(${s.valueLetter}=${s.value})').join(' → ')}');
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
      final totalRequiredGroups = _getMaxGroupsForApparatus(_selectedApparatus); // 種目ごとの正しいグループ数
      final completenessScore = groupDistribution.length / totalRequiredGroups;
      
      // 不足グループの特定
      for (int i = 1; i <= totalRequiredGroups; i++) {
        if (!groupDistribution.containsKey(i) || groupDistribution[i] == 0) {
          missingGroups.add('グループ$i');
        }
      }
      
      // 改善案の生成（詳細版）
      final List<String> suggestions = [];
      
      // グループ不足の詳細分析
      if (missingGroups.isNotEmpty) {
        final groupNames = {
          'グループ1': '非アクロバット系要素',
          'グループ2': '前方系アクロバット要素',
          'グループ3': '後方系アクロバット要素',
          'グループ4': '終末技',
          'グループ5': '力技・特殊要素'
        };
        
        String detailedMissingGroups = missingGroups.map((g) => 
          '$g（${groupNames[g] ?? g}）').join('、');
        
        suggestions.add('【緊急：必須グループ不足】\n' +
          '不足: $detailedMissingGroups\n' +
          '影響: 大幅な減点が発生します\n' +
          '対策: 早急に各グループの基本技から練習を始めてください');
      }
      
      // 難度分析の詳細化
      final avgDifficulty = stats['averageDifficulty'] as double? ?? 0.0;
      if (avgDifficulty < 0.3) {
        suggestions.add('【難度不足】平均難度${(avgDifficulty * 10).toStringAsFixed(1)}点\n' +
          '現状: 初級レベルの構成です\n' +
          '改善: C難度以上の技を3-4個追加しましょう');
      } else if (avgDifficulty < 0.4) {
        suggestions.add('【難度向上の余地あり】平均難度${(avgDifficulty * 10).toStringAsFixed(1)}点\n' +
          '現状: 中級レベル\n' +
          '改善: D難度の技を1-2個追加でスコアアップ');
      }
      
      // 技数分析（跳馬は除外）
      if (_selectedApparatus?.toLowerCase() != 'vault' && 
          _selectedApparatus?.toLowerCase() != 'vt') {
        if (_routine.length < 8) {
          suggestions.add('【技数不足】現在${_routine.length}技\n' +
            '推奨: 8技（難度上位7技+終末技）\n' +
            '対策: あと${8 - _routine.length}技以上追加が必要です');
        } else if (_routine.length > 12) {
          suggestions.add('【技数過多】現在${_routine.length}技\n' +
            'リスク: 体力消耗、実施精度低下\n' +
            '対策: 8-10技程度に絞り込みましょう');
        }
      }
      
      // 種目固有のアドバイス
      if (_selectedApparatus == 'FX' && !(groupDistribution.containsKey(4))) {
        suggestions.add('【フロア特有】終末技（グループ4）が必須です');
      } else if (_selectedApparatus == 'HB' && !(groupDistribution.containsKey(5))) {
        suggestions.add('【鉄棒特有】終末技（グループ5）が必須です');
      }
      
      // 優先度の詳細設定
      String priority = 'low';
      if (missingGroups.isNotEmpty) {
        priority = 'high';
      } else if (avgDifficulty < 0.3 || _routine.length < 8) {
        priority = 'medium';
      }
      
      final recommendations = {
        'suggestions': suggestions,
        'priority': priority,
        'totalScore': stats['totalDifficulty'] as double? ?? 0.0,
        'averageDifficulty': avgDifficulty,
        'completenessScore': completenessScore,
      };
      
      return RoutineAnalysis(
        apparatus: _selectedApparatus!,
        timestamp: DateTime.now(),
        difficultyDistribution: stats['difficultyDistribution'] as Map<String, int>? ?? {},
        groupDistribution: groupDistribution.map((key, value) => MapEntry(key, value)),
        connectionBonusRatio: (_selectedApparatus == 'FX' || _selectedApparatus == 'HB') 
            ? ((_dScoreResult?.connectionBonus ?? 0.0) / 0.4) // 0.4が最大連続ボーナス
            : 0.0, // FXとHB以外は連続技ボーナスなし
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
      
      // モバイル版のみでflutter_secure_storageを使用
      routinesData = await _storage.read(key: 'saved_routines');
      
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

  // AIチャット履歴を読み込み
  Future<void> _loadChatMessages() async {
    try {
      final chatData = await _storage.read(key: 'chat_messages');
      if (chatData != null) {
        final List<dynamic> decoded = json.decode(chatData);
        setState(() {
          _chatMessages = decoded.map((message) => Map<String, dynamic>.from(message)).toList();
        });
        print('Loaded ${_chatMessages.length} chat messages');
      }
    } catch (e) {
      print('Error loading chat messages: $e');
    }
  }

  // AIチャット履歴を保存
  Future<void> _saveChatMessages() async {
    try {
      await _storage.write(
        key: 'chat_messages',
        value: json.encode(_chatMessages),
      );
      print('Saved ${_chatMessages.length} chat messages');
    } catch (e) {
      print('Error saving chat messages: $e');
    }
  }

  // D-スコア計算結果を読み込み
  Future<void> _loadDScoreResults() async {
    try {
      final dScoreData = await _storage.read(key: 'dscore_results');
      if (dScoreData != null) {
        final Map<String, dynamic> decoded = json.decode(dScoreData);
        setState(() {
          _allDScoreResults.clear();
          decoded.forEach((key, value) {
            final Map<String, dynamic> resultMap = Map<String, dynamic>.from(value);
            _allDScoreResults[key] = DScoreResult(
              totalDScore: (resultMap['totalDScore'] as num?)?.toDouble() ?? 0.0,
              difficultyValue: (resultMap['difficultyValue'] as num?)?.toDouble() ?? 0.0,
              groupBonus: (resultMap['groupBonus'] as num?)?.toDouble() ?? 0.0,
              connectionBonus: (resultMap['connectionBonus'] as num?)?.toDouble() ?? 0.0,
              neutralDeductions: (resultMap['neutralDeductions'] as num?)?.toDouble() ?? 0.0,
              deductionBreakdown: Map<String, double>.from(resultMap['deductionBreakdown'] ?? {}),
              fulfilledGroups: (resultMap['fulfilledGroups'] as int?) ?? 0,
              requiredGroups: (resultMap['requiredGroups'] as int?) ?? 0,
              totalSkills: (resultMap['totalSkills'] as int?) ?? 0,
            );
          });
        });
        print('Loaded D-Score results for ${_allDScoreResults.length} apparatus');
      }
    } catch (e) {
      print('Error loading D-Score results: $e');
    }
  }

  // D-スコア計算結果を保存
  Future<void> _saveDScoreResults() async {
    try {
      final resultsToSave = <String, dynamic>{};
      _allDScoreResults.forEach((key, result) {
        if (result != null) {
          resultsToSave[key] = {
            'totalDScore': result.totalDScore,
            'difficultyValue': result.difficultyValue,
            'groupBonus': result.groupBonus,
            'connectionBonus': result.connectionBonus,
            'neutralDeductions': result.neutralDeductions,
            'deductionBreakdown': result.deductionBreakdown,
            'fulfilledGroups': result.fulfilledGroups,
            'requiredGroups': result.requiredGroups,
            'totalSkills': result.totalSkills,
          };
        }
      });
      
      await _storage.write(
        key: 'dscore_results',
        value: json.encode(resultsToSave),
      );
      print('Saved D-Score results for ${resultsToSave.length} apparatus');
    } catch (e) {
      print('Error saving D-Score results: $e');
    }
  }

  // 技データキャッシュを読み込み
  Future<void> _loadSkillDataCache() async {
    try {
      final skillCacheData = await _storage.read(key: 'skill_data_cache');
      if (skillCacheData != null) {
        final Map<String, dynamic> decoded = json.decode(skillCacheData);
        setState(() {
          _skillDataCache.clear();
          decoded.forEach((key, value) {
            final List<dynamic> skillList = value;
            _skillDataCache[key] = skillList.map((skill) => Skill.fromMap(Map<String, dynamic>.from(skill))).toList();
          });
        });
        print('Loaded skill data cache for ${_skillDataCache.length} apparatus/language combinations');
      }
    } catch (e) {
      print('Error loading skill data cache: $e');
    }
  }

  // 技データキャッシュを保存
  Future<void> _saveSkillDataCache() async {
    try {
      final cacheToSave = <String, dynamic>{};
      _skillDataCache.forEach((key, skillList) {
        cacheToSave[key] = skillList.map((skill) => {
          'id': skill.id,
          'name': skill.name,
          'group': skill.group,
          'valueLetter': skill.valueLetter,
          'description': skill.description,
          'apparatus': skill.apparatus,
          'value': skill.value,
        }).toList();
      });
      
      await _storage.write(
        key: 'skill_data_cache',
        value: json.encode(cacheToSave),
      );
      print('Saved skill data cache for ${_skillDataCache.length} apparatus/language combinations');
    } catch (e) {
      print('Error saving skill data cache: $e');
    }
  }
  
  // 現在の演技構成状態を自動保存（リロード対策）
  Future<void> _saveCurrentRoutineState() async {
    try {
      final routineState = {
        'selectedApparatus': _selectedApparatus,
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
        'allRoutines': _allRoutines.map((apparatus, skills) => MapEntry(
          apparatus,
          skills.map((skill) => {
            'id': skill.id,
            'name': skill.name,
            'group': skill.group,
            'valueLetter': skill.valueLetter,
            'description': skill.description,
            'apparatus': skill.apparatus,
            'value': skill.value,
          }).toList(),
        )),
        'allConnectionGroups': _allConnectionGroups,
        'allNextConnectionGroupIds': _allNextConnectionGroupIds,
        // D-score結果を保存
        'dScoreResult': _dScoreResult != null ? {
          'totalDScore': _dScoreResult!.totalDScore,
          'difficultyValue': _dScoreResult!.difficultyValue,
          'groupBonus': _dScoreResult!.groupBonus,
          'connectionBonus': _dScoreResult!.connectionBonus,
          'neutralDeductions': _dScoreResult!.neutralDeductions,
          'fulfilledGroups': _dScoreResult!.fulfilledGroups,
          'requiredGroups': _dScoreResult!.requiredGroups,
          'totalSkills': _dScoreResult!.totalSkills,
          'deductionBreakdown': _dScoreResult!.deductionBreakdown,
        } : null,
        'allDScoreResults': _allDScoreResults.map((apparatus, result) => MapEntry(
          apparatus,
          result != null ? {
            'totalDScore': result.totalDScore,
            'difficultyValue': result.difficultyValue,
            'groupBonus': result.groupBonus,
            'connectionBonus': result.connectionBonus,
            'neutralDeductions': result.neutralDeductions,
            'fulfilledGroups': result.fulfilledGroups,
            'requiredGroups': result.requiredGroups,
            'totalSkills': result.totalSkills,
            'deductionBreakdown': result.deductionBreakdown,
          } : null,
        )),
        'lastSavedAt': DateTime.now().toIso8601String(),
      };
      
      await _storage.write(
        key: 'current_routine_state',
        value: json.encode(routineState),
      );
      print('Auto-saved current routine state');
    } catch (e) {
      print('Error auto-saving routine state: $e');
    }
  }

  // 保存された演技構成状態を読み込み
  Future<void> _loadCurrentRoutineState() async {
    try {
      final stateData = await _storage.read(key: 'current_routine_state');
      if (stateData != null) {
        final Map<String, dynamic> state = json.decode(stateData);
        
        setState(() {
          // 選択された種目を復元
          if (state['selectedApparatus'] != null) {
            _selectedApparatus = state['selectedApparatus'];
          }
          
          // 現在の演技構成を復元
          if (state['routine'] != null) {
            final List<dynamic> routineData = state['routine'];
            _routine = routineData.map((skillData) => Skill.fromMap(Map<String, dynamic>.from(skillData))).toList();
          }
          
          if (state['connectionGroups'] != null) {
            _connectionGroups = List<int>.from(state['connectionGroups']);
          }
          
          if (state['nextConnectionGroupId'] != null) {
            _nextConnectionGroupId = state['nextConnectionGroupId'];
          }
          
          // 全種目の演技構成を復元
          if (state['allRoutines'] != null) {
            final Map<String, dynamic> allRoutinesData = state['allRoutines'];
            _allRoutines.clear();
            allRoutinesData.forEach((apparatus, skillsData) {
              final List<dynamic> skillList = skillsData;
              _allRoutines[apparatus] = skillList.map((skillData) => Skill.fromMap(Map<String, dynamic>.from(skillData))).toList();
            });
          }
          
          if (state['allConnectionGroups'] != null) {
            final Map<String, dynamic> allConnectionGroupsData = state['allConnectionGroups'];
            _allConnectionGroups.clear();
            allConnectionGroupsData.forEach((key, value) {
              _allConnectionGroups[key] = List<int>.from(value);
            });
          }
          
          if (state['allNextConnectionGroupIds'] != null) {
            final Map<String, dynamic> allNextConnectionGroupIdsData = state['allNextConnectionGroupIds'];
            _allNextConnectionGroupIds.clear();
            allNextConnectionGroupIdsData.forEach((key, value) {
              _allNextConnectionGroupIds[key] = value;
            });
          }
          
          // D-score結果を復元
          if (state['allDScoreResults'] != null) {
            final Map<String, dynamic> allDScoreResultsData = state['allDScoreResults'];
            _allDScoreResults.clear();
            allDScoreResultsData.forEach((apparatus, resultData) {
              if (resultData != null) {
                final Map<String, dynamic> result = Map<String, dynamic>.from(resultData);
                _allDScoreResults[apparatus] = DScoreResult(
                  totalDScore: result['totalDScore']?.toDouble() ?? 0.0,
                  difficultyValue: result['difficultyValue']?.toDouble() ?? 0.0,
                  groupBonus: result['groupBonus']?.toDouble() ?? 0.0,
                  connectionBonus: result['connectionBonus']?.toDouble() ?? 0.0,
                  neutralDeductions: result['neutralDeductions']?.toDouble() ?? 0.0,
                  fulfilledGroups: result['fulfilledGroups'] ?? 0,
                  requiredGroups: result['requiredGroups'] ?? 0,
                  totalSkills: result['totalSkills'] ?? 0,
                  deductionBreakdown: Map<String, double>.from(result['deductionBreakdown'] ?? {}),
                );
              }
            });
          }
          
          // 現在の種目のD-score結果を復元
          if (_selectedApparatus != null && _allDScoreResults.containsKey(_selectedApparatus)) {
            _dScoreResult = _allDScoreResults[_selectedApparatus];
          }
        });
        
        print('✅ Successfully loaded routine state:');
        print('  - Selected apparatus: $_selectedApparatus');
        print('  - Current routine skills: ${_routine.length}');
        print('  - All routines: ${_allRoutines.keys.toList()}');
        print('  - Connection groups: ${_connectionGroups.length}');
        print('  - D-score result restored: ${_dScoreResult != null ? _dScoreResult!.totalDScore : "null"}');
      } else {
        // 保存データがない場合はデフォルト値を設定
        setState(() {
          _selectedApparatus = 'FX';
        });
        print('No saved state found, using default apparatus: FX');
      }
    } catch (e) {
      print('Error loading routine state: $e');
      // エラーの場合もデフォルト値を設定
      setState(() {
        _selectedApparatus = 'FX';
      });
    }
  }
  
  // 現在の画面状態（タブ）を自動保存
  Future<void> _saveCurrentViewMode() async {
    try {
      await _storage.write(
        key: 'current_view_mode',
        value: _currentMode.toString(),
      );
      print('Auto-saved current view mode: $_currentMode');
    } catch (e) {
      print('Error auto-saving view mode: $e');
    }
  }

  // 保存された画面状態（タブ）を読み込み
  Future<void> _loadCurrentViewMode() async {
    try {
      final modeData = await _storage.read(key: 'current_view_mode');
      print('DEBUG: Reading view mode data: $modeData');
      if (modeData != null) {
        setState(() {
          // 文字列から AppMode に変換
          switch (modeData) {
            case 'AppMode.chat':
              _currentMode = AppMode.chat;
              break;
            case 'AppMode.dScore':
              _currentMode = AppMode.dScore;
              break;
            case 'AppMode.allApparatus':
              _currentMode = AppMode.allApparatus;
              break;
            case 'AppMode.analytics':
              _currentMode = AppMode.analytics;
              break;
            case 'AppMode.admin':
              _currentMode = AppMode.admin;
              break;
            default:
              print('DEBUG: Unknown mode data: $modeData, using default chat');
              _currentMode = AppMode.chat; // デフォルト
          }
        });
        print('✅ Successfully loaded view mode: $_currentMode from: $modeData');
      } else {
        print('DEBUG: No saved view mode found, using default chat');
      }
    } catch (e) {
      print('Error loading view mode: $e');
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
            
            // モバイル版のみでflutter_secure_storageを使用
            await _storage.write(
              key: 'saved_routines',
              value: json.encode(_savedRoutines),
            );
            
            setState(() {});
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('演技構成「$name」を保存しました'),
                backgroundColor: Colors.green,
              ),
            );
            
            // モバイルアプリ版のみ（Web版広告機能は廃止）
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
      
      // モバイル版のみでflutter_secure_storageを使用
      await _storage.write(
        key: 'saved_routines',
        value: json.encode(_savedRoutines),
      );
      
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
                          scoreResult?.totalDScore.toStringAsFixed(3) ?? '0.000',
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
                        _skillList = []; // 技リストをクリア
                        _isSkillLoading = true; // ローディング状態を設定
                        _currentSkillPage = 1; // ページをリセット
                        _selectedSkill = null; // 選択された技をクリア
                        _selectedSkillIndex = null; // 選択されたインデックスをクリア
                      });
                      if (value != null) {
                        _ensureSkillsLoaded(value);
                      }
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
          
          const SizedBox(height: 16),
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
        
        // 分析結果用AIチャットインターフェース
        _buildAnalyticsAIChatInterface(analysis),
      ],
    );
  }

  // 分析結果を自動的にチャットに送信するウィジェット
  Widget _buildAutoSendToChat(RoutineAnalysis analysis) {
    // AI チャットモードでない場合は何も表示しない
    if (_currentMode != 'ai_chat') {
      return const SizedBox.shrink();
    }

    // 分析結果を詳細に整理してチャットに送信
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sendAnalysisResultsToChat(analysis);
      }
    });

    // 送信中の表示
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[800]!, Colors.green[600]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[400]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.green[200], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '分析結果を自動的にチャットに送信しています...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[200]!),
            ),
          ),
        ],
      ),
    );
  }

  // 分析結果をチャットに送信する詳細版（自動送信用）
  Future<void> _sendAnalysisResultsToChat(RoutineAnalysis analysis) async {
    // 分析結果を詳細に整理
    final analysisText = '''演技構成分析結果：

🏆 総合評価: ${(analysis.completenessScore * 100).toStringAsFixed(1)}%
📊 基本情報:
- 種目: ${analysis.apparatus}
- 技数: ${analysis.totalSkills}技
- 平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}

📈 詳細分析:
- 難度分布: ${analysis.difficultyDistribution.entries.map((e) => '${e.key}難度:${e.value}技').join(', ')}
- グループ分布: ${analysis.groupDistribution.entries.map((e) => 'G${e.key}:${e.value}技').join(', ')}''' + 
    ((_selectedApparatus == 'FX' || _selectedApparatus == 'HB') 
        ? '\n- 連続技ボーナス率: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%' 
        : '') +
    (_dScoreResult?.neutralDeductions != null && _dScoreResult!.neutralDeductions > 0 
        ? '\n⚠️ ND減点: -${_dScoreResult!.neutralDeductions.toStringAsFixed(1)}点 (${_dScoreResult!.deductionBreakdown.keys.join(', ')})' 
        : '') + '''

${analysis.missingGroups.isNotEmpty ? '❌ 不足グループ: ${analysis.missingGroups.join(', ')}' : '✅ 全グループ要求を満たしています'}

この構成について改善提案をお願いします。特に以下の観点でアドバイスをください：
1. 技の構成バランス
2. 難度アップの可能性''' + 
    ((_selectedApparatus == 'FX' || _selectedApparatus == 'HB') 
        ? '\n3. 連続技ボーナスの最適化\n4. リスク管理' 
        : '\n3. リスク管理') +
    (_dScoreResult?.neutralDeductions != null && _dScoreResult!.neutralDeductions > 0 
        ? '\n5. ND減点の解決方法' 
        : '');
    
    // チャットに送信
    await _sendMessage(analysisText);
  }

  // 分析結果用AIチャットインターフェース（簡易版）
  Widget _buildAnalyticsAIChatInterface(RoutineAnalysis analysis) {
    // AIチャット機能が無効の場合は情報バーを表示
    if (!AppConfig.enableAIChat) {
      return _buildAnalysisInfoBar();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // アイコンと説明
          Icon(
            Icons.psychology,
            size: 48,
            color: Colors.blue[400],
          ),
          const SizedBox(height: 12),
          Text(
            '分析結果について詳しく質問する',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'AIチャットで構成の改善提案や詳細な分析を受けられます',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // AIチャットへ移動ボタン
          ElevatedButton.icon(
            onPressed: () async {
              // 分析結果を自動的にチャットに送信
              await _sendAnalysisResultsToChat(analysis);
              // AIチャットタブに切り替え
              setState(() {
                _currentMode = AppMode.chat;
              });
            },
            icon: Icon(Icons.chat, size: 20),
            label: Text('より詳細はAIチャットへ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
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
            '今後AIチャットで自分の演技を分析する機能が実装されます。',
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

  // 詳細な改善提案を取得
  String? _getDetailedSuggestion(String suggestion) {
    // 提案内容に基づいて詳細な説明を返す
    if (suggestion.contains('難度')) {
      return '難度構成を見直すことで、より高い得点を狙えます。現在の技術レベルに合わせて、段階的に難度を上げていくことをお勧めします。';
    } else if (suggestion.contains('接続')) {
      return '技の接続をスムーズにすることで、演技の流れが良くなり、評価が上がります。特に難度の高い技の前後の流れに注意しましょう。';
    } else if (suggestion.contains('バランス')) {
      return '演技全体のバランスを考慮し、前半と後半の技の配分を調整することで、より完成度の高い演技になります。';
    } else if (suggestion.contains('終末技')) {
      return '終末技は演技の印象を大きく左右します。確実に実施できる技を選択し、着地の安定性を重視しましょう。';
    } else if (suggestion.contains('組み合わせ')) {
      return '技の組み合わせを工夫することで、加点要素を増やすことができます。練習で確実性を高めてから導入しましょう。';
    }
    return null;
  }

  // 改善提案の静的表示
  Widget _buildImprovementSuggestions() {
    if (_currentAnalysis?.recommendations == null) return const SizedBox.shrink();
    
    final suggestions = _currentAnalysis!.recommendations!['suggestions'] as List<String>? ?? [];
    
    if (suggestions.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[300]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '改善提案はありません\n\n現在の演技構成は体操競技規則に適合しており、基本的な要求を満たしています。さらなる向上のためには個別の技術指導をお勧めします。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '改善提案',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildSuggestionsList(suggestions),
          ],
        ),
      ),
    );
  }

  // 改善提案の静的表示（特定の分析用）
  Widget _buildStaticImprovementSuggestions(RoutineAnalysis analysis) {
    if (analysis.recommendations == null) return const SizedBox.shrink();
    
    final suggestions = analysis.recommendations!['suggestions'] as List<String>? ?? [];
    
    if (suggestions.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[300]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '改善提案はありません\n\n現在の演技構成は体操競技規則に適合しており、基本的な要求を満たしています。さらなる向上のためには個別の技術指導をお勧めします。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  '改善提案',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildSuggestionsList(suggestions),
          ],
        ),
      ),
    );
  }

  // 提案リストの構築
  List<Widget> _buildSuggestionsList(List<String> suggestions) {
    final List<Widget> widgets = [];
    int itemIndex = 0;
    
    for (int i = 0; i < suggestions.length; i++) {
      final suggestion = suggestions[i];
      
      // セクションヘッダーの場合
      if (suggestion.startsWith('===')) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 16));
        }
        widgets.add(
          Text(
            suggestion.replaceAll('=', '').trim(),
            style: TextStyle(
              color: _getPriorityColor(suggestion),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        itemIndex = 0; // セクションごとにインデックスをリセット
      } else if (suggestion.trim().isEmpty) {
        // 空行はスキップ
        continue;
      } else {
        // 通常の提案項目
        itemIndex++;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getSuggestionBorderColor(suggestion),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getSuggestionColor(suggestion).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$itemIndex',
                            style: TextStyle(
                              color: _getSuggestionColor(suggestion),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    
    return widgets;
  }
  
  // 優先度に基づく色の取得
  Color _getPriorityColor(String text) {
    // 優先度レベルとしての文字列を処理
    if (text == 'high' || text.contains('緊急')) return Colors.red;
    if (text == 'medium' || text.contains('重要')) return Colors.orange;
    if (text == 'low' || text.contains('推奨')) return Colors.blue;
    return Colors.amber;
  }
  
  // 提案内容に基づく色の取得
  Color _getSuggestionColor(String suggestion) {
    if (suggestion.contains('【緊急') || suggestion.contains('必須')) return Colors.red;
    if (suggestion.contains('不足】')) return Colors.orange;
    if (suggestion.contains('改善】')) return Colors.amber;
    if (suggestion.contains('良好】') || suggestion.contains('適切')) return Colors.green;
    return Colors.blue;
  }
  
  // 提案の枠線色の取得
  Color _getSuggestionBorderColor(String suggestion) {
    return _getSuggestionColor(suggestion).withOpacity(0.3);
  }
  
  // 優先度アイコンの取得
  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.lightbulb;
      default:
        return Icons.info;
    }
  }
  
  // 優先度テキストの取得
  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '緊急';
      case 'medium':
        return '重要';
      case 'low':
        return '推奨';
      default:
        return '情報';
    }
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
        total += result.totalDScore;
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
        horizontal: isMobile ? 6 : 7, 
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
          fontSize: isMobile ? 11 : 12,
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

  // デバッグ用アプリ状態確認
  void _debugAppState() {
    print('=== アプリ状態デバッグ ===');
    print('_isBackgroundInitComplete: $_isBackgroundInitComplete');
    // print('_isAdManagerInitialized: $_isAdManagerInitialized');  // 広告機能無効化により削除
    print('_userSubscription.shouldShowAds(): ${_userSubscription.shouldShowAds()}');
    print('_userSubscription.tier: ${_userSubscription.tier}');
    print('_userSubscription.isActive: ${_userSubscription.isActive}');
    print('_userSubscription.isFree: ${_userSubscription.isFree}');
    print('kDebugMode: ${kDebugMode}');
    // print('広告表示条件: ${_userSubscription.shouldShowAds() && _isAdManagerInitialized}');
    
    /*
    // 広告機能一時無効化
    // if (_adManager != null) {
    //   print('_adManager存在: true');
    //   _adManager.diagnoseBannerAdStatus();
    // } else {
    //   print('_adManager存在: false');
    }
    */
    print('========================');
  }

  // 🌟 世界クラスAIコーチによる詳細演技分析
  void _showWorldClassAIAnalysis() async {
    if (_dScoreResult == null || _selectedApparatus == null) {
      _showErrorDialog('エラー', 'まずD-Score計算を実行してください。');
      return;
    }

    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.purple.shade600),
            const SizedBox(height: 16),
            const Text('🤖 世界クラスAIコーチが分析中...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      // 演技データを準備
      final routineData = _routine.map((skill) => {
        'name': skill.name,
        'valueLetter': skill.valueLetter,
        'group': skill.group,
        'value': skill.value,
      }).toList();

      // AI分析APIを呼び出し
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/analyze_routine'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'routine_data': routineData,
          'apparatus': _selectedApparatus,
          'total_score': _dScoreResult!.totalDScore,
          'difficulty_score': _dScoreResult!.difficultyValue,
          'group_bonus': _dScoreResult!.groupBonus,
          'connection_bonus': _dScoreResult!.connectionBonus,
          'message': '演技構成の詳細分析と改善提案をお願いします。',
        }),
      ).timeout(const Duration(seconds: 30));

      Navigator.of(context).pop(); // ローディングダイアログを閉じる

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final analysis = data['analysis'] as String;
        
        // 分析結果ダイアログを表示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🤖 世界クラスAI分析結果',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade600),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 500),
              child: SingleChildScrollView(
                child: Text(
                  analysis,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      } else {
        throw Exception('AI分析サーバーエラー: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop(); // ローディングダイアログを閉じる
      _showErrorDialog('AI分析エラー', 'AI分析に失敗しました。ネットワーク接続を確認してください。\n\nエラー詳細: $e');
    }
  }

  // 🔍 なぜこの点数？ - クイック説明機能
  void _showQuickScoreExplanation() async {
    if (_dScoreResult == null || _selectedApparatus == null) {
      _showErrorDialog('エラー', 'まずD-Score計算を実행してください。');
      return;
    }

    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.blue.shade600),
            const SizedBox(height: 16),
            const Text('🤔 点数の根拠を解析中...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      // 演技データを準備
      final routineData = _routine.map((skill) => {
        'name': skill.name,
        'valueLetter': skill.valueLetter,
        'group': skill.group,
        'value': skill.value,
      }).toList();

      // クイック分析APIを呼び出し
      final response = await http.post(
        Uri.parse('${Config.apiBaseUrl}/quick_analysis'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'routine_data': routineData,
          'apparatus': _selectedApparatus,
          'total_score': _dScoreResult!.totalDScore,
          'difficulty_score': _dScoreResult!.difficultyValue,
          'group_bonus': _dScoreResult!.groupBonus,
          'connection_bonus': _dScoreResult!.connectionBonus,
        }),
      ).timeout(const Duration(seconds: 20));

      Navigator.of(context).pop(); // ローディングダイアログを閉じる

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final explanation = data['explanation'] as String;
        
        // 説明結果ダイアログを表示
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue.shade600, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🤔 なぜこの点数？',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade600),
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Text(
                  explanation,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      } else {
        throw Exception('クイック分析サーバーエラー: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(context).pop(); // ローディングダイアログを閉じる
      _showErrorDialog('点数説明エラー', '点数の説明に失敗しました。ネットワーク接続を確認してください。\n\nエラー詳細: $e');
    }
  }

  @override
  void dispose() {
    // アプリライフサイクル監視を停止
    WidgetsBinding.instance.removeObserver(this);
    
    // 定期チェックタイマーを停止
    _subscriptionCheckTimer?.cancel();
    
    // コントローラーをクリーンアップ
    _skillSearchController.dispose();
    
    super.dispose();
  }

  // 床運動の要求事項チェック
  String? _checkFloorRequirements(List<Skill> routine) {
    if (routine.isEmpty) return null;
    
    // グループ別の技数をカウント
    final Map<int, int> groupCounts = {};
    for (final skill in routine) {
      groupCounts[skill.group] = (groupCounts[skill.group] ?? 0) + 1;
    }
    
    // 床運動の基本要求事項チェック
    final missingGroups = <int>[];
    
    // グループI（非アクロバット系要素）- 必須
    if (!groupCounts.containsKey(1) || groupCounts[1]! == 0) {
      missingGroups.add(1);
    }
    
    // グループII（前方系アクロバット要素）- 必須  
    if (!groupCounts.containsKey(2) || groupCounts[2]! == 0) {
      missingGroups.add(2);
    }
    
    // グループIII（後方系アクロバット要素）- 必須
    if (!groupCounts.containsKey(3) || groupCounts[3]! == 0) {
      missingGroups.add(3);
    }
    
    // グループIV（終末技） - 必須ではないが推奨
    if (!groupCounts.containsKey(4) || groupCounts[4]! == 0) {
      // 警告として表示するが、エラーではない
    }
    
    if (missingGroups.isNotEmpty) {
      final groupNames = {
        1: '非アクロバット系要素（バランス、柔軟性、ジャンプなど）',
        2: '前方系アクロバット要素',
        3: '後方系アクロバット要素',
        4: '終末技'
      };
      
      final missingGroupNames = missingGroups.map((g) => 'グループ$g: ${groupNames[g]}').join('、');
      return '床運動の要求事項が不足しています：$missingGroupNames';
    }
    
    return null; // 要求事項を満たしている
  }

  // 技のグループ別カウント
  Map<int, int> _countSkillsPerGroup(List<Skill> routine) {
    final Map<int, int> groupCounts = {};
    for (final skill in routine) {
      groupCounts[skill.group] = (groupCounts[skill.group] ?? 0) + 1;
    }
    return groupCounts;
  }

  // 種目別最大グループ数を取得
  int _getMaxGroupsForApparatus(String? apparatus) {
    switch (apparatus?.toUpperCase()) {
      case 'FX':
      case 'FLOOR':
        return 4;
      case 'PH':
      case 'POMMEL':
        return 4;
      case 'SR':
      case 'RINGS':
        return 4;
      case 'VT':
      case 'VAULT':
        return 0; // 跳馬はグループなし
      case 'PB':
      case 'PARALLEL':
        return 4;
      case 'HB':
      case 'HORIZONTAL':
        return 4;
      default:
        return 4; // デフォルト
    }
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
    print('🔧 DEBUG: _SkillSelectionDialog initState()');
    print('🔧 DEBUG: 初期技リスト数: ${widget.skillList.length}');
    print('🔧 DEBUG: 種目: ${widget.apparatus}');
    
    _filteredSkills = widget.skillList;
    print('🔧 DEBUG: フィルタリング後の技数: ${_filteredSkills.length}');
    
    // 技データのサンプルを表示
    if (_filteredSkills.isNotEmpty) {
      print('🔧 DEBUG: 最初の技サンプル: ${_filteredSkills.first.name} (G${_filteredSkills.first.group}, ${_filteredSkills.first.valueLetter})');
      
      // HBの場合は更に詳細なサンプル
      if (widget.apparatus == 'HB') {
        print('🔧 HB DEBUG: ダイアログに渡された技の詳細サンプル:');
        for (int i = 0; i < _filteredSkills.length && i < 10; i++) {
          final skill = _filteredSkills[i];
          print('🔧 HB DEBUG: [$i] ${skill.name}: G${skill.group}, ${skill.valueLetter} (${skill.value})');
        }
        
        // グループと難度の分布を確認
        final groupCounts = <int, int>{};
        final difficultyCounts = <String, int>{};
        for (final skill in _filteredSkills) {
          groupCounts[skill.group] = (groupCounts[skill.group] ?? 0) + 1;
          difficultyCounts[skill.valueLetter] = (difficultyCounts[skill.valueLetter] ?? 0) + 1;
        }
        print('🔧 HB DEBUG: ダイアログ内グループ分布: $groupCounts');
        print('🔧 HB DEBUG: ダイアログ内難度分布: $difficultyCounts');
      }
    } else {
      print('🔧 DEBUG: 警告 - フィルタリング後の技が0個です');
    }
  }

  void _filterSkills(String query) {
    setState(() {
      _searchText = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    print('🔧 DEBUG: _applyFilters() 開始');
    print('🔧 DEBUG: 検索テキスト: "$_searchText"');
    print('🔧 DEBUG: グループフィルター: $_selectedGroupFilter');
    print('🔧 DEBUG: 難度フィルター: $_selectedDifficultyFilter');
    print('🔧 DEBUG: 元の技リスト数: ${widget.skillList.length}');
    
    _filteredSkills = widget.skillList.where((skill) {
      // テキスト検索フィルター
      bool textMatch = _searchText.isEmpty || _matchesSearchQuery(skill.name, _searchText);
      
      // グループフィルター
      bool groupMatch = _selectedGroupFilter == null || skill.group == _selectedGroupFilter;
      
      // 難度フィルター
      bool difficultyMatch = _selectedDifficultyFilter == null || skill.valueLetter == _selectedDifficultyFilter;
      
      return textMatch && groupMatch && difficultyMatch;
    }).toList();
    
    print('🔧 DEBUG: フィルタリング後の技数: ${_filteredSkills.length}');
    if (_filteredSkills.isEmpty) {
      print('🔧 DEBUG: 警告 - フィルタリング後に技が0個になりました');
      print('🔧 DEBUG: 原因調査: 元データから最初の5技を確認');
      for (int i = 0; i < widget.skillList.length && i < 5; i++) {
        final skill = widget.skillList[i];
        print('🔧 DEBUG: 技$i: ${skill.name} (G${skill.group}, ${skill.valueLetter})');
      }
    }
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
    final difficulties = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
    
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
    print('🔧 DEBUG: SkillSelectionDialog build() - フィルタリング済み技数: ${_filteredSkills.length}');
    
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('技を変更 (${widget.apparatus ?? "Unknown"})'),
          Text(
            '現在: ${widget.currentSkill.name}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Colors.grey[600],
            ),
          ),
          if (_filteredSkills.isNotEmpty)
            Text(
              '${_filteredSkills.length}技が利用可能',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.blue[600],
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // 検索フィールド
            TextField(
              decoration: InputDecoration(
                hintText: '技を検索...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchText = '';
                            _applyFilters();
                          });
                        },
                      )
                    : null,
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
                child: _filteredSkills.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '技が見つかりません',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '検索条件を変更するか、\nフィルターをクリアしてください',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                print('🔧 DEBUG: フィルターリセットボタンが押されました');
                                setState(() {
                                  _searchText = '';
                                  _selectedGroupFilter = null;
                                  _selectedDifficultyFilter = null;
                                  _applyFilters();
                                });
                                print('🔧 DEBUG: フィルターリセット後の技数: ${_filteredSkills.length}');
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('フィルターをリセット'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
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
                                    widget.apparatus == 'VT' 
                                        ? 'D値: ${skill.valueLetter}' // 跳馬は valueLetter のみ表示
                                        : 'D値: ${skill.valueLetter} (${skill.value.toStringAsFixed(1)})',
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

  // 種目別最大グループ数を取得
  int _getMaxGroupsForApparatus(String? apparatus) {
    switch (apparatus?.toUpperCase()) {
      case 'FX':
      case 'FLOOR':
        return 4;
      case 'PH':
      case 'POMMEL':
        return 4;
      case 'SR':
      case 'RINGS':
        return 4;
      case 'VT':
      case 'VAULT':
        return 0; // 跳馬はグループなし
      case 'PB':
      case 'PARALLEL':
        return 4;
      case 'HB':
      case 'HORIZONTAL':
        return 4;
      default:
        return 4; // デフォルト
    }
  }
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
    if (_isSkillsLoaded) {
      print('🔧 DEBUG: 技データベース既に読み込み済み');
      return;
    }
    
    try {
      print('🔧 DEBUG: 技データベース読み込み開始');
      final String data = await rootBundle.loadString('data/skills_ja.csv');
      print('🔧 DEBUG: CSVファイル読み込み完了。データサイズ: ${data.length}文字');
      
      final List<List<dynamic>> csvData = const CsvToListConverter().convert(data);
      print('🔧 DEBUG: CSV解析完了。行数: ${csvData.length}');
      
      _skillsDatabase.clear(); // 既存のデータをクリア
      
      Map<String, int> apparatusCount = {};
      
      for (int i = 1; i < csvData.length; i++) { // 1行目はヘッダーなのでスキップ
        if (csvData[i].length >= 4) {
          final String apparatus = csvData[i][0]?.toString().trim() ?? '';
          final String name = csvData[i][1]?.toString().trim() ?? '';
          final String group = csvData[i][2]?.toString().trim() ?? '';
          final String valueLetter = csvData[i][3]?.toString().trim() ?? '';
          
          if (apparatus.isNotEmpty && name.isNotEmpty) {
            apparatusCount[apparatus] = (apparatusCount[apparatus] ?? 0) + 1;
            _skillsDatabase.add({
              'id': '${apparatus}_${i}',
              'apparatus': apparatus,
              'name': name,
              'group': group,
              'value_letter': valueLetter,
              'description': '',
            });
          }
        }
      }
      
      _isSkillsLoaded = true;
      print('🔧 DEBUG: 技データベース読み込み完了: ${_skillsDatabase.length}技');
      print('🔧 DEBUG: 種目別技数: $apparatusCount');
      print('技データベース読み込み完了: ${_skillsDatabase.length}技');
    } catch (e) {
      print('技データベース読み込みエラー: $e');
      _isSkillsLoaded = false;
    }
  }
  
  // 種目別技の検索
  static List<Map<String, dynamic>> getSkillsForApparatus(String apparatus) {
    print('🔧 DEBUG: getSkillsForApparatus() 呼び出し - 種目: $apparatus');
    
    if (!_isSkillsLoaded) {
      print('🔧 DEBUG: エラー - 技データベースが読み込まれていません');
      return [];
    }
    
    final result = _skillsDatabase.where((skill) => 
        skill['apparatus']?.toString().toLowerCase() == apparatus.toLowerCase()).toList();
    
    print('🔧 DEBUG: ${apparatus}用の技数: ${result.length}');
    if (result.isEmpty) {
      print('🔧 DEBUG: 警告 - ${apparatus}の技が見つかりません');
      print('🔧 DEBUG: 全データベース: ${_skillsDatabase.length}技');
      print('🔧 DEBUG: 使用可能な種目: ${_skillsDatabase.map((s) => s['apparatus']).toSet()}');
    } else {
      print('🔧 DEBUG: 最初の3技: ${result.take(3).map((s) => s['name']).join(", ")}');
    }
    
    return result;
  }
  
  // 技名による検索
  static Map<String, dynamic>? findSkillByName(String name, String apparatus) {
    if (!_isSkillsLoaded) return null;
    
    try {
      return _skillsDatabase.firstWhere(
        (skill) => skill['name']?.toString().toLowerCase().contains(name.toLowerCase()) == true &&
                   skill['apparatus']?.toString().toLowerCase() == apparatus.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
  
  // 全技データの取得（デバッグ用）
  static List<Map<String, dynamic>> getAllSkills() {
    return List.from(_skillsDatabase);
  }
}
