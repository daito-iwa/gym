import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback, Clipboard, ClipboardData;
import 'package:csv/csv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

// dart:htmlは使用しないで、すべてfile_pickerで代替

import 'config.dart';
import 'auth_screen.dart'; // 作成した認証画面をインポート
import 'd_score_calculator.dart'; // D-スコア計算とSkillクラスをインポート

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

// 共有・エクスポート機能クラス
class ShareExportService {
  // 演技構成データのJSONエクスポート
  static Map<String, dynamic> exportRoutineToJson(
    String apparatus,
    List<Skill> routine,
    List<List<int>> connectionGroups,
    DScoreResult? dScoreResult,
  ) {
    return {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'apparatus': apparatus,
      'routine': routine.map((skill) => {
        'name': skill.name,
        'value': skill.value,
        'valueLetter': skill.valueLetter,
        'group': skill.group,
        'connectionValue': 0.0, // Skill class doesn't have connectionValue property
        'id': skill.id,
      }).toList(),
      'connectionGroups': connectionGroups,
      'dScoreResult': dScoreResult != null ? {
        'totalScore': dScoreResult.totalDScore,
        'difficultyScore': dScoreResult.difficultyValue,
        'connectionBonusScore': dScoreResult.connectionBonus,
        'neutralDeductionScore': 0.0, // Not available in DScoreResult
        'groupRequirements': {
          'fulfilled': dScoreResult.fulfilledGroups,
          'required': dScoreResult.requiredGroups,
        },
        'connections': [], // Not available in DScoreResult
        'details': 'D-Score: ${dScoreResult.dScore}',
      } : null,
    };
  }

  // 分析結果のテキスト形式エクスポート
  static String exportAnalysisToText(
    String apparatus,
    List<Skill> routine,
    DScoreResult? dScoreResult,
    RoutineAnalysis? analysis,
    String currentLang,
  ) {
    final buffer = StringBuffer();
    final dateFormatter = DateFormat('yyyy年MM月dd日 HH:mm:ss');
    
    // 翻訳辞書を直接参照（静的メソッドのため）
    final isJapanese = currentLang == '日本語';
    buffer.writeln(isJapanese ? '体操 D-スコア計算結果' : 'Gymnastics D-Score Calculation Results');
    buffer.writeln('=' * 40);
    buffer.writeln('${isJapanese ? '生成日時:' : 'Generated Time:'} ${dateFormatter.format(DateTime.now())}');
    buffer.writeln('${isJapanese ? '種目:' : 'Apparatus:'} $apparatus');
    buffer.writeln();
    
    // 演技構成
    buffer.writeln('演技構成:');
    buffer.writeln('-' * 20);
    for (int i = 0; i < routine.length; i++) {
      final skill = routine[i];
      buffer.writeln('${i + 1}. ${skill.name} (${skill.valueLetter}) - ${skill.value}点');
    }
    buffer.writeln();
    
    // D-スコア結果
    if (dScoreResult != null) {
      buffer.writeln('D-スコア結果:');
      buffer.writeln('-' * 20);
      buffer.writeln('合計スコア: ${dScoreResult.totalDScore.toStringAsFixed(1)}点');
      buffer.writeln('難度点: ${dScoreResult.difficultyValue.toStringAsFixed(1)}点');
      buffer.writeln('つなぎ加点: ${dScoreResult.connectionBonus.toStringAsFixed(1)}点');
      buffer.writeln('グループボーナス: ${dScoreResult.groupBonus.toStringAsFixed(1)}点');
      buffer.writeln();
      
      // グループ要件
      buffer.writeln('グループ要件:');
      buffer.writeln('  達成グループ: ${dScoreResult.fulfilledGroups}個');
      buffer.writeln('  必要グループ: ${dScoreResult.requiredGroups}個');
      buffer.writeln();
    }
    
    // 分析結果
    if (analysis != null) {
      buffer.writeln('分析結果:');
      buffer.writeln('-' * 20);
      buffer.writeln('技数: ${analysis.totalSkills}');
      buffer.writeln('平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}');
      buffer.writeln('完成度スコア: ${analysis.completenessScore.toStringAsFixed(1)}%');
      buffer.writeln('つなぎ加点比率: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%');
      
      if (analysis.missingGroups.isNotEmpty) {
        buffer.writeln('不足グループ: ${analysis.missingGroups.join(', ')}');
      }
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  // HTML印刷用レポート生成
  static String exportToHtmlReport(
    String apparatus,
    List<Skill> routine,
    DScoreResult? dScoreResult,
    RoutineAnalysis? analysis,
  ) {
    final dateFormatter = DateFormat('yyyy年MM月dd日 HH:mm:ss');
    
    return '''
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>体操 D-スコア計算結果 - $apparatus</title>
    <style>
        body {
            font-family: 'Hiragino Kaku Gothic ProN', 'Hiragino Sans', 'Meiryo', sans-serif;
            margin: 20px;
            line-height: 1.6;
            color: #333;
        }
        .header {
            text-align: center;
            border-bottom: 2px solid #333;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: #2c3e50;
            margin: 0;
        }
        .info {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .section {
            margin-bottom: 30px;
        }
        .section h2 {
            color: #34495e;
            border-bottom: 1px solid #bdc3c7;
            padding-bottom: 5px;
        }
        .routine-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        .routine-table th, .routine-table td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        .routine-table th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        .score-summary {
            background: #e8f5e8;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .score-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
        }
        .score-item.total {
            font-weight: bold;
            font-size: 1.2em;
            border-top: 2px solid #333;
            padding-top: 10px;
        }
        .analysis-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }
        .analysis-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
        }
        .analysis-item h3 {
            margin-top: 0;
            color: #2c3e50;
        }
        @media print {
            body { margin: 0; }
            .header { page-break-after: avoid; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>体操 D-スコア計算結果</h1>
        <p>種目: $apparatus</p>
        <p>生成日時: ${dateFormatter.format(DateTime.now())}</p>
    </div>

    <div class="section">
        <h2>演技構成</h2>
        <table class="routine-table">
            <thead>
                <tr>
                    <th>順序</th>
                    <th>技名</th>
                    <th>難度</th>
                    <th>点数</th>
                    <th>グループ</th>
                </tr>
            </thead>
            <tbody>
                ${routine.asMap().entries.map((entry) {
                  final index = entry.key;
                  final skill = entry.value;
                  return '''
                <tr>
                    <td>${index + 1}</td>
                    <td>${skill.name}</td>
                    <td>${skill.valueLetter}</td>
                    <td>${skill.value}</td>
                    <td>${skill.group}</td>
                </tr>
                  ''';
                }).join()}
            </tbody>
        </table>
    </div>

    ${dScoreResult != null ? '''
    <div class="section">
        <h2>D-スコア結果</h2>
        <div class="score-summary">
            <div class="score-item">
                <span>難度点:</span>
                <span>${dScoreResult.difficultyValue.toStringAsFixed(1)}点</span>
            </div>
            <div class="score-item">
                <span>つなぎ加点:</span>
                <span>${dScoreResult.connectionBonus.toStringAsFixed(1)}点</span>
            </div>
            <div class="score-item">
                <span>グループボーナス:</span>
                <span>${dScoreResult.groupBonus.toStringAsFixed(1)}点</span>
            </div>
            <div class="score-item total">
                <span>合計スコア:</span>
                <span>${dScoreResult.totalDScore.toStringAsFixed(1)}点</span>
            </div>
        </div>
        
        <h3>グループ要件</h3>
        <div class="info">
            達成グループ: ${dScoreResult.fulfilledGroups}個<br>
            必要グループ: ${dScoreResult.requiredGroups}個
        </div>
    </div>
    ''' : ''}

    ${analysis != null ? '''
    <div class="section">
        <h2>分析結果</h2>
        <div class="analysis-grid">
            <div class="analysis-item">
                <h3>基本統計</h3>
                <p>技数: ${analysis.totalSkills}</p>
                <p>平均難度: ${analysis.averageDifficulty.toStringAsFixed(2)}</p>
                <p>完成度スコア: ${analysis.completenessScore.toStringAsFixed(1)}%</p>
            </div>
            <div class="analysis-item">
                <h3>構成分析</h3>
                <p>つなぎ加点比率: ${(analysis.connectionBonusRatio * 100).toStringAsFixed(1)}%</p>
                ${analysis.missingGroups.isNotEmpty ? 
                  '<p>不足グループ: ${analysis.missingGroups.join(', ')}</p>' : 
                  '<p>全グループ要件満たされています</p>'}
            </div>
        </div>
    </div>
    ''' : ''}

    <div class="section">
        <p style="text-align: center; color: #7f8c8d; margin-top: 40px;">
            Generated by 体操 D-スコア計算アプリ
        </p>
    </div>
</body>
</html>
    ''';
  }

  // ファイルダウンロード（クロスプラットフォーム対応）
  static void downloadFile(String content, String fileName, String mimeType) {
    // クロスプラットフォーム対応 - クリップボードにコピー
    Clipboard.setData(ClipboardData(text: content));
  }

  // 共有URL生成
  static String generateShareUrl(
    String apparatus,
    List<Skill> routine,
    String baseUrl,
  ) {
    final routineData = {
      'apparatus': apparatus,
      'routine': routine.map((skill) => {
        'id': skill.id,
        'name': skill.name,
        'value': skill.value,
        'valueLetter': skill.valueLetter,
        'group': skill.group,
      }).toList(),
    };
    
    final encodedData = base64Encode(utf8.encode(jsonEncode(routineData)));
    return '$baseUrl/share?data=$encodedData';
  }

  // ソーシャルメディア用テキスト生成
  static String generateSocialText(
    String apparatus,
    List<Skill> routine,
    DScoreResult? dScoreResult,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('体操 $apparatus の演技構成を作成しました！');
    buffer.writeln();
    
    if (dScoreResult != null) {
      buffer.writeln('D-スコア: ${dScoreResult.totalDScore.toStringAsFixed(1)}点');
      buffer.writeln('難度点: ${dScoreResult.difficultyValue.toStringAsFixed(1)}点');
      buffer.writeln('つなぎ加点: ${dScoreResult.connectionBonus.toStringAsFixed(1)}点');
      buffer.writeln();
    }
    
    buffer.writeln('技数: ${routine.length}');
    buffer.writeln();
    buffer.writeln('#体操 #Dスコア #${apparatus}');
    
    return buffer.toString();
  }

  // JSONファイルからの演技構成読み込み
  static Future<Map<String, dynamic>?> importRoutineFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      
      // バージョンチェック
      if (data['version'] != '1.0') {
        throw Exception('サポートされていないファイル形式です');
      }
      
      // 必須フィールドのチェック
      if (!data.containsKey('apparatus') || !data.containsKey('routine')) {
        throw Exception('無効なファイル形式です');
      }
      
      return data;
    } catch (e) {
      print('Import error: $e');
      return null;
    }
  }
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

enum AppMode { chat, dScore, allApparatus, analytics, admin }

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

  // 機能アクセス権限チェック
  bool canAccessDScore() => isPremium;
  bool canAccessAllApparatus() => isPremium;
  bool canAccessAnalytics() => isPremium;
  bool canAccessUnlimitedChat() => isPremium;
  bool shouldShowAds() => isFree;
}

// チャット使用量追跡クラス
class ChatUsageTracker {
  static const String _dailyUsageKey = 'daily_chat_usage';
  static const String _monthlyUsageKey = 'monthly_chat_usage';
  static const String _lastResetDateKey = 'last_reset_date';
  static const String _monthlyResetDateKey = 'monthly_reset_date';
  
  static const int dailyFreeLimit = 10;
  static const int monthlyFreeLimit = 50;
  
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
  
  static Future<bool> canSendMessage(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return true;
    }
    
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    
    return dailyUsage < dailyFreeLimit && monthlyUsage < monthlyFreeLimit;
  }
  
  static Future<String> getUsageStatus(UserSubscription subscription) async {
    if (subscription.canAccessUnlimitedChat()) {
      return 'プレミアム: 無制限';
    }
    
    final dailyUsage = await getDailyUsage();
    final monthlyUsage = await getMonthlyUsage();
    
    return '本日: $dailyUsage/$dailyFreeLimit | 今月: $monthlyUsage/$monthlyFreeLimit';
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

// 課金システム管理クラス
class PurchaseManager {
  static const String _premiumProductId = 'premium_monthly_subscription';
  static const String _premiumProductId_ios = 'com.daito.gym.premium_monthly';
  static const String _premiumProductId_android = 'premium_monthly_subscription';
  
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  
  // コールバック関数
  Function()? onPurchaseSuccess;
  Future<void> Function()? onPurchaseVerified;
  
  // 課金システム初期化
  Future<void> initialize() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      print('Purchase stream error: $error');
    });
    
    await _initStoreInfo();
  }
  
  // ストア情報の初期化
  Future<void> _initStoreInfo() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      print('In-app purchase not available');
      return;
    }
    
    String productId = defaultTargetPlatform == TargetPlatform.iOS 
        ? _premiumProductId_ios 
        : _premiumProductId_android;
    
    final Set<String> ids = <String>{productId};
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(ids);
    
    if (response.notFoundIDs.isNotEmpty) {
      print('Product not found: ${response.notFoundIDs}');
    }
    
    _products = response.productDetails;
    print('Products loaded: ${_products.length}');
  }
  
  // 購入処理
  Future<bool> purchasePremium() async {
    if (_products.isEmpty) {
      print('No products available');
      return false;
    }
    
    final ProductDetails productDetails = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      _purchasePending = true;
      final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      print('Purchase error: $e');
      _purchasePending = false;
      return false;
    }
  }
  
  // 購入履歴復元
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }
  
  // 購入状態監視
  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _handleSuccessfulPurchase(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
        
        _purchasePending = false;
      }
    }
  }
  
  // 購入成功時の処理
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    print('Purchase successful: ${purchaseDetails.productID}');
    // バックエンドに購入情報を送信して検証
    _verifyPurchaseWithBackend(purchaseDetails);
  }
  
  // バックエンドでの購入検証
  Future<void> _verifyPurchaseWithBackend(PurchaseDetails purchaseDetails) async {
    print('Verifying purchase with backend...');
    
    try {
      // プラットフォーム検出
      String platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      
      // リクエストデータ構築
      Map<String, dynamic> verificationData = {
        'platform': platform,
        'receipt_data': purchaseDetails.verificationData.localVerificationData,
        'transaction_id': purchaseDetails.purchaseID ?? '',
        'product_id': purchaseDetails.productID,
      };
      
      // Android用の追加データ
      if (platform == 'android') {
        verificationData['purchase_token'] = purchaseDetails.purchaseID ?? '';
      }
      
      // バックエンドAPIに送信
      final response = await _makeHttpRequest(
        'POST',
        '/purchase/verify',
        body: verificationData,
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success']) {
          print('Purchase verified successfully');
          // コールバック関数があれば呼び出し
          if (onPurchaseVerified != null) {
            await onPurchaseVerified!();
          }
          if (onPurchaseSuccess != null) {
            onPurchaseSuccess!();
          }
        } else {
          print('Purchase verification failed: ${responseData['message']}');
        }
      } else {
        print('Purchase verification API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Purchase verification error: $e');
    }
  }
  
  // HTTP リクエスト送信ヘルパー
  Future<http.Response> _makeHttpRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    // PurchaseManager用の独自API通信
    final url = Uri.parse('${AppConfig.apiBaseUrl}$path');
    
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (method == 'POST') {
      return await http.post(
        url,
        headers: headers,
        body: body != null ? json.encode(body) : null,
      );
    } else {
      return await http.get(url, headers: headers);
    }
  }
  
  // 利用可能な商品を取得
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;
  
  // リソース解放
  void dispose() {
    _subscription.cancel();
  }
}

// 広告システム管理クラス
class AdManager {
  // テスト用広告ID（本番環境では実際のIDを使用）
  static const String _testBannerAdId = 'ca-app-pub-3940256099942544/6300978111';  // iOS/Android共通テスト用
  static const String _testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';  // iOS/Android共通テスト用
  
  // 本番用広告ID（実際のAdMobアカウントで設定）
  static const String _bannerAdId_ios = 'ca-app-pub-xxxxx/yyyyyyy';
  static const String _bannerAdId_android = 'ca-app-pub-xxxxx/yyyyyyy';
  static const String _interstitialAdId_ios = 'ca-app-pub-xxxxx/yyyyyyy';
  static const String _interstitialAdId_android = 'ca-app-pub-xxxxx/yyyyyyy';
  
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  
  // 広告システム初期化
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    print('AdMob initialized');
    _loadBannerAd();
    _loadInterstitialAd();
  }
  
  // バナー広告読み込み
  void _loadBannerAd() {
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
        },
      ),
    );
    
    _bannerAd?.load();
  }
  
  // インタースティシャル広告読み込み
  void _loadInterstitialAd() {
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
        },
      ),
    );
  }
  
  // バナー広告ID取得
  String _getBannerAdId() {
    // テスト環境では常にテスト用IDを使用
    return _testBannerAdId;
    
    // 本番環境では以下を使用
    // return defaultTargetPlatform == TargetPlatform.iOS 
    //     ? _bannerAdId_ios 
    //     : _bannerAdId_android;
  }
  
  // インタースティシャル広告ID取得
  String _getInterstitialAdId() {
    // テスト環境では常にテスト用IDを使用
    return _testInterstitialAdId;
    
    // 本番環境では以下を使用
    // return defaultTargetPlatform == TargetPlatform.iOS 
    //     ? _interstitialAdId_ios 
    //     : _interstitialAdId_android;
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
  }
  
  // ゲッター
  bool get isBannerAdReady => _isBannerAdReady;
  bool get isInterstitialAdReady => _isInterstitialAdReady;
}

class _HomePageState extends State<HomePage> {
  AppMode _currentMode = AppMode.chat;
  final TextEditingController _textController = TextEditingController();
  
  // ユーザーサブスクリプション管理
  UserSubscription _userSubscription = UserSubscription(tier: UserTier.free);
  bool _isLoadingSubscription = false;
  bool _isAdmin = false;
  
  // 課金システム管理
  late PurchaseManager _purchaseManager;
  bool _isPurchaseManagerInitialized = false;
  
  // 広告システム管理
  late AdManager _adManager;
  bool _isAdManagerInitialized = false;
  
  // 管理者パネル用データ
  Map<String, dynamic>? _adminAnalytics;
  List<dynamic>? _adminUsers;
  bool _isLoadingAdminData = false;

  // プレミアム機能アクセス制御
  bool _checkPremiumAccess(AppMode mode) {
    switch (mode) {
      case AppMode.chat:
        return true; // チャット機能は無料
      case AppMode.dScore:
        return _userSubscription.canAccessDScore();
      case AppMode.allApparatus:
        return _userSubscription.canAccessAllApparatus();
      case AppMode.analytics:
        return _userSubscription.canAccessAnalytics();
      case AppMode.admin:
        return _isAdmin;
    }
  }

  // アップグレード促進ダイアログ
  void _showUpgradeDialog(String featureName) {
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
    if (!_isPurchaseManagerInitialized) {
      _showMessage('課金システムが初期化されていません');
      return;
    }
    
    if (!_purchaseManager.isAvailable) {
      _showMessage('課金システムは現在利用できません');
      return;
    }
    
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
              if (_purchaseManager.purchasePending)
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
      setState(() {
        _isLoadingSubscription = true;
      });
      
      final bool success = await _purchaseManager.purchasePremium();
      
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
      setState(() {
        _isLoadingSubscription = true;
      });
      
      await _purchaseManager.restorePurchases();
      _showMessage('購入履歴を復元しました');
    } catch (e) {
      _showMessage('復元エラー: $e');
    } finally {
      setState(() {
        _isLoadingSubscription = false;
      });
    }
  }

  // テスト用：プレミアムモード切り替え（デバッグ用）
  void _togglePremiumForTesting() {
    setState(() {
      if (_userSubscription.tier == UserTier.free) {
        _userSubscription = UserSubscription(
          tier: UserTier.premium,
          subscriptionStart: DateTime.now(),
          subscriptionEnd: DateTime.now().add(Duration(days: 30)),
        );
        _showMessage('テスト用プレミアムモードを有効にしました');
      } else {
        _userSubscription = UserSubscription(tier: UserTier.free);
        _showMessage('無料モードに戻しました');
      }
    });
  }
  final List<ChatMessage> _messages = [];
  final List<AnalyticsMessage> _analyticsMessages = [];
  String _session_id = Uuid().v4();
  bool _isLoading = false;
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
      'logout': 'ログアウト',
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
      'logout': 'Logout',
      'login': 'Login',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'darkMode': 'Dark Mode',
      'lightMode': 'Light Mode',
      'theme': 'Theme',
    },
  };
  
  // 翻訳ヘルパー関数
  String _getText(String key) {
    // AI機能は常に英語表示（ダサくなるのを防ぐため）
    if (key == 'ruleBookChat') return 'Gymnastics AI Chat';
    if (key == 'dScoreCalculator') return 'D-Score Calculator';
    
    return _appTexts[_currentLang]![key] ?? _appTexts['English']![key] ?? key;
  }

  // AppBarタイトルを取得（モードと言語に応じて動的に変更）
  String _getAppBarTitle() {
    switch (_currentMode) {
      case AppMode.chat:
        return 'Gymnastics AI Chat'; // 常に英語表示
      case AppMode.dScore:
        return 'D-Score Calculator'; // 常に英語表示
      case AppMode.allApparatus:
        return _currentLang == '日本語' ? '全種目一覧' : 'All Apparatus List';
      case AppMode.analytics:
        return _currentLang == '日本語' ? '演技構成分析' : 'Routine Analysis';
      case AppMode.admin:
        return _currentLang == '日本語' ? '管理者パネル' : 'Admin Panel';
      default:
        return _currentLang == '日本語' ? '体操アプリ' : 'Gymnastics App';
    }
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
  Skill? _selectedSkill; // ドロップダウンで選択された技
  int? _selectedSkillIndex; // 選択された技のインデックス
  bool _isEditingSkill = false; // 技編集モードかどうか
  String _skillSearchQuery = ''; // 技検索クエリ
  int? _selectedGroupFilter; // グループフィルタ (1-8)
  String? _selectedDifficultyFilter; // 難度フィルタ (A-I)
  
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

  // === ERROR HANDLING METHODS ===
  
  /// Check if device has internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
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

    return await _retryRequest<http.Response>(() async {
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
    });
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
    // Clear stored authentication data
    _clearStoredToken();
    
    setState(() {
      _isAuthenticated = false;
      _token = null;
    });
    
    // Show authentication screen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => AuthScreen(
            onSubmit: _submitAuthForm,
            isLoading: _isLoading,
          ),
        ),
        (route) => false,
      );
    }
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
    _setupOfflinePremiumAccess(); // オフライン版：プレミアム機能を有効化
    _loadSavedRoutines(); // 保存された演技構成を読み込み
    _refreshSkillsData(); // スキルデータを更新
    // 課金システムと広告システムは無効化（オフライン版）
  }
  
  // オフライン版：プレミアム機能を有効化
  void _setupOfflinePremiumAccess() {
    print('オフライン版：プレミアム機能を自動有効化');
    
    // プレミアム機能を全て有効化
    _userSubscription = UserSubscription(
      tier: UserTier.premium,
      subscriptionStart: DateTime.now().subtract(Duration(days: 30)),
      subscriptionEnd: DateTime.now().add(Duration(days: 365)),
    );
    
    // 認証状態を設定
    _isAuthenticated = true;
    _token = 'offline-premium-token';
    
    // 初期化完了
    setState(() {
      _isLoading = false;
    });
    
    print('オフライン版：プレミアム機能が利用可能です');
  }
  
  // スキルデータを更新
  Future<void> _refreshSkillsData() async {
    // AIチャット用のスキルデータベースを読み込み
    GymnasticsKnowledgeBase.resetSkillsDatabase(); // データベースをリセット
    await GymnasticsKnowledgeBase.loadSkillsDatabase();
    
    // Dスコア計算用のスキルキャッシュをクリア
    _skillDataCache.clear();
    
    // 現在選択中の種目があれば再読み込み
    if (_selectedApparatus != null) {
      await _loadSkills(_selectedApparatus!);
    }
    
    print('Skills data refreshed successfully');
  }
  
  // 課金システム初期化
  Future<void> _initializePurchaseManager() async {
    _purchaseManager = PurchaseManager();
    
    // コールバック関数を設定
    _purchaseManager.onPurchaseSuccess = _showPurchaseSuccessDialog;
    _purchaseManager.onPurchaseVerified = _refreshUserSubscriptionInfo;
    
    try {
      await _purchaseManager.initialize();
      setState(() {
        _isPurchaseManagerInitialized = true;
      });
      print('PurchaseManager initialized successfully');
    } catch (e) {
      print('Failed to initialize PurchaseManager: $e');
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
  
  void _tryAutoLogin() async {
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

  void _submitAuthForm(
    String username,
    String password,
    String? email,
    String? fullName,
    bool isLogin,
  ) async {
    print('オフライン版：認証をバイパス');
    setState(() {
      _isLoading = true;
    });

    try {
      // オフライン版：認証を完全バイパス
      await Future.delayed(Duration(milliseconds: 300)); // 短い待機
      
      // オフライン版トークンを設定
      _token = 'offline-premium-token';
      
      // プレミアム機能を全て有効化
      _userSubscription = UserSubscription(
        tier: UserTier.premium,
        subscriptionStart: DateTime.now().subtract(Duration(days: 30)),
        subscriptionEnd: DateTime.now().add(Duration(days: 365)),
      );
      
      // 認証状態を更新
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
      
      _resetChat();
      _showSuccessSnackBar('オフライン版：全機能が利用可能です');
      return;
      
      // 元のコード（コメントアウト）
      /*
      // Check internet connectivity first
      if (!await _hasInternetConnection()) {
        _showErrorDialog(
          'ネットワークエラー',
          'インターネット接続を確認してください',
          onRetry: () => _submitAuthForm(username, password, email, fullName, isLogin),
        );
        return;
      }
      */

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

  void _logout() async {
    await _clearStoredToken();
    setState(() {
      _token = null;
      _isAuthenticated = false;
      _messages.clear();
      _session_id = Uuid().v4();
    });
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

  Future<void> _loadSkills(String apparatus) async {
    final lang = _currentLang == '日本語' ? 'ja' : 'en';
    final cacheKey = '${apparatus}_$lang';
    
    // デバッグのため、キャッシュを一時的に無効化
    print('Cache disabled for debugging. Loading fresh data for $apparatus');
    
    // キャッシュから取得を試行（一時的に無効化）
    // if (_skillDataCache.containsKey(cacheKey)) {
    //   setState(() {
    //     _skillList = _skillDataCache[cacheKey]!;
    //     _isSkillLoading = false;
    //   });
    //   return;
    // }

    setState(() {
      _isSkillLoading = true;
      _skillList = [];
    });

    final path = 'data/skills_$lang.csv';
    try {
      print('Loading skills from: $path for apparatus: $apparatus');
      final rawCsv = await rootBundle.loadString(path);
      final List<List<dynamic>> listData = const CsvToListConverter().convert(rawCsv);
      
      if (listData.isEmpty) {
        setState(() => _isSkillLoading = false);
        return;
      }
      
      final headers = listData[0].map((e) => e.toString()).toList();
      print('CSV headers: $headers');
      
      final skills = listData
          .skip(1)
          .map((row) {
            final map = Map<String, dynamic>.fromIterables(headers, row);
            return map;
          })
          .where((map) => map['apparatus'] == apparatus)
          .map((map) => Skill.fromMap(map))
          .toList();
      
      print('Loaded ${skills.length} skills for $apparatus');

      skills.sort((a, b) => a.name.compareTo(b.name));

      // キャッシュに保存
      _skillDataCache[cacheKey] = skills;

      setState(() {
        _skillList = skills;
        _isSkillLoading = false;
      });
    } catch (e) {
      print('Error loading skills: $e');
      setState(() {
        _isSkillLoading = false;
      });
    }
  }

  // メッセージを送信し、APIから応答を受け取る
  void _handleSendPressed() async {
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
      // まず専門知識データベースをチェック
      final knowledgeResponse = GymnasticsKnowledgeBase.getKnowledgeResponse(userInput);
      
      if (knowledgeResponse != null) {
        // 専門知識データベースに回答がある場合、即座に表示
        setState(() {
          _messages.insert(0, ChatMessage(
            text: '$knowledgeResponse\n\n🏆 体操専門知識データベースより',
            isUser: false,
          ));
          _isLoading = false;
        });
        
        // 使用量を増加
        await ChatUsageTracker.incrementUsage();
        _checkChatUsageWarning();
        return;
      }

      // 専門知識データベースに回答がない場合、APIにリクエストを送信
      final response = await _makeApiRequest(
        '/chat',
        method: 'POST',
        body: {
          'session_id': _session_id,
          'question': userInput,
          'lang': _currentLang == '日本語' ? 'ja' : 'en',
          'context': _buildGymnasticsContext(), // 体操コンテキストを追加
        },
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      // AIの応答を追加
      setState(() {
        _messages.insert(0, ChatMessage(text: data['answer'], isUser: false));
      });
      
      // 使用量を増加
      await ChatUsageTracker.incrementUsage();
      _checkChatUsageWarning();
      
    } on NetworkException catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'ネットワークエラー: ${e.message}',
          isUser: false,
        ));
      });
    } on AuthenticationException catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: '認証エラー: ${e.message}',
          isUser: false,
        ));
      });
    } on DataException catch (e) {
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'データエラー: ${e.message}',
          isUser: false,
        ));
      });
    } catch (e) {
      print('Chat error: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: 'エラー: 予期しないエラーが発生しました。($e)',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  // チャットをリセットする
  void _resetChat() {
    setState(() {
      _messages.clear();
      _session_id = Uuid().v4();
    });
  }

  // 共有・エクスポート機能メソッド
  
  // 演技構成をJSONでエクスポート
  void _exportRoutineAsJson() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      _showMessage('エクスポートするデータがありません');
      return;
    }

    final jsonData = ShareExportService.exportRoutineToJson(
      _selectedApparatus!,
      _routine,
      _connectionGroups.map((e) => [e]).toList(),
      _dScoreResult,
    );

    final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);
    final fileName = '${_selectedApparatus}_routine_${DateTime.now().millisecondsSinceEpoch}.json';
    
    ShareExportService.downloadFile(jsonString, fileName, 'application/json');
    
    if (kIsWeb) {
      _showMessage('演技構成をJSONファイルでダウンロードしました');
    } else {
      _showMessage('演技構成をクリップボードにコピーしました');
    }
  }

  // 分析結果をテキストでエクスポート
  void _exportAnalysisAsText() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      _showMessage('エクスポートするデータがありません');
      return;
    }

    final textData = ShareExportService.exportAnalysisToText(
      _selectedApparatus!,
      _routine,
      _dScoreResult,
      _currentAnalysis,
      _currentLang,
    );

    final fileName = '${_selectedApparatus}_analysis_${DateTime.now().millisecondsSinceEpoch}.txt';
    
    ShareExportService.downloadFile(textData, fileName, 'text/plain');
    
    if (kIsWeb) {
      _showMessage('分析結果をテキストファイルでダウンロードしました');
    } else {
      _showMessage('分析結果をクリップボードにコピーしました');
    }
  }

  // HTML印刷用レポートを生成
  void _exportHtmlReport() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      _showMessage('エクスポートするデータがありません');
      return;
    }

    final htmlData = ShareExportService.exportToHtmlReport(
      _selectedApparatus!,
      _routine,
      _dScoreResult,
      _currentAnalysis,
    );

    final fileName = '${_selectedApparatus}_report_${DateTime.now().millisecondsSinceEpoch}.html';
    
    ShareExportService.downloadFile(htmlData, fileName, 'text/html');
    
    if (kIsWeb) {
      _showMessage('HTML印刷用レポートをダウンロードしました');
    } else {
      _showMessage('HTML印刷用レポートをクリップボードにコピーしました');
    }
  }

  // 共有URLを生成
  void _generateShareUrl() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      _showMessage('共有するデータがありません');
      return;
    }

    final baseUrl = 'https://app.example.com';
    final shareUrl = ShareExportService.generateShareUrl(
      _selectedApparatus!,
      _routine,
      baseUrl,
    );

    // クリップボードにコピー
    Clipboard.setData(ClipboardData(text: shareUrl));
    _showMessage('共有URLをクリップボードにコピーしました');
  }

  // ソーシャルメディア用テキストを生成
  void _generateSocialText() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      _showMessage('共有するデータがありません');
      return;
    }

    final socialText = ShareExportService.generateSocialText(
      _selectedApparatus!,
      _routine,
      _dScoreResult,
    );

    // クリップボードにコピー
    Clipboard.setData(ClipboardData(text: socialText));
    _showMessage('ソーシャルメディア用テキストをクリップボードにコピーしました');
  }

  // JSONファイルからインポート
  void _importRoutineFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = result.files.single;
        final jsonString = String.fromCharCodes(file.bytes!);
        final data = await ShareExportService.importRoutineFromJson(jsonString);
        
        if (data != null) {
          await _processImportedData(data);
          _showMessage('演技構成をインポートしました');
        } else {
          _showMessage('ファイルの読み込みに失敗しました');
        }
      }
    } catch (e) {
      _showMessage('インポートエラー: ${e.toString()}');
    }
  }

  // インポートしたデータを処理
  Future<void> _processImportedData(Map<String, dynamic> data) async {
    try {
      final apparatus = data['apparatus'] as String;
      final routineData = data['routine'] as List<dynamic>;
      
      // 技データを再構築
      final importedRoutine = <Skill>[];
      for (final skillData in routineData) {
        final skill = Skill(
          id: skillData['id'] ?? '',
          name: skillData['name'] ?? '',
          value: (skillData['value'] as num).toDouble(),
          valueLetter: skillData['valueLetter'] ?? '',
          group: skillData['group'] ?? 0,
          description: skillData['description'] ?? '',
          apparatus: apparatus,
        );
        importedRoutine.add(skill);
      }

      // 状態を更新
      setState(() {
        _selectedApparatus = apparatus;
        _routine = importedRoutine;
        _connectionGroups = (data['connectionGroups'] as List<dynamic>?)
            ?.map((e) => (e as List<dynamic>).first as int)
            .toList() ?? [];
        _currentMode = AppMode.dScore;
      });

      // 技リストを読み込み
      await _loadSkills(apparatus);
      
      // D-スコアを再計算
      if (_routine.isNotEmpty) {
        _calculateDScoreFromRoutine();
      }
      
    } catch (e) {
      throw Exception('データの処理に失敗しました: $e');
    }
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
  void _calculateDScoreFromRoutine() {
    if (_selectedApparatus == null || _routine.isEmpty) {
      return;
    }
    
    // 連続技グループを適切に構築
    final routine = _buildConnectedSkillGroups(_routine, _connectionGroups);
    
    // D-スコアを計算
    final result = calculateDScore(_selectedApparatus!, routine);
    
    setState(() {
      _dScoreResult = result;
    });
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
    if (_isAuthLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return AuthScreen(
        onSubmit: _submitAuthForm,
        isLoading: _isLoading,
      );
    }

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
            // メニューボタン（複数の機能を統合）
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String value) {
                switch (value) {
                  case 'import':
                    _importRoutineFromJson();
                    break;
                  case 'feedback':
                    _showFeedbackDialog();
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload, size: 20),
                      SizedBox(width: 8),
                      Text(_currentLang == '日本語' ? 'インポート' : 'Import'),
                    ],
                  ),
                ),
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
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text(_currentLang == '日本語' ? 'ログアウト' : 'Logout'),
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
          currentIndex: _currentMode == AppMode.chat ? 0 : 
                       (_currentMode == AppMode.dScore ? 1 : 
                       (_currentMode == AppMode.allApparatus ? 2 : 
                       (_currentMode == AppMode.analytics ? 3 : 4))),
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            HapticFeedback.lightImpact(); // タップ時にハプティックフィードバック
            
            AppMode targetMode;
            String featureName;
            
            if (index == 0) {
              targetMode = AppMode.chat;
              featureName = 'AIチャット';
            } else if (index == 1) {
              targetMode = AppMode.dScore;
              featureName = 'D-Score計算';
            } else if (index == 2) {
              targetMode = AppMode.allApparatus;
              featureName = '全種目分析';
            } else if (index == 3) {
              targetMode = AppMode.analytics;
              featureName = 'アナリティクス';
            } else {
              targetMode = AppMode.admin;
              featureName = _getText('adminPanel');
            }
            
            // プレミアム機能アクセス制御
            if (_checkPremiumAccess(targetMode)) {
              setState(() {
                _currentMode = targetMode;
              });
              
              // 管理者パネルが選択されたらデータをロード
              if (targetMode == AppMode.admin) {
                _loadAdminData();
              }
            } else {
              _showUpgradeDialog(featureName);
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'AIチャット',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.calculate),
                  if (_userSubscription.isFree)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              label: 'D-Score${_userSubscription.isFree ? ' ⭐' : ''}',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.sports_gymnastics),
                  if (_userSubscription.isFree)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              label: '全種目${_userSubscription.isFree ? ' ⭐' : ''}',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  Icon(Icons.analytics),
                  if (_userSubscription.isFree)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              label: '分析${_userSubscription.isFree ? ' ⭐' : ''}',
            ),
            if (_isAdmin) 
              BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings),
                label: '管理者',
              ),
          ],
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
                    if (_userSubscription.isFree) ...[
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
                title: Text(_getText('ruleBookChat')),
                value: AppMode.chat,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentMode = value!;
                  });
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                },
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('dScoreCalculator')),
                value: AppMode.dScore,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentMode = value!;
                  });
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                },
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('allApparatus')),
                value: AppMode.allApparatus,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentMode = value!;
                  });
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
                },
              ),
              RadioListTile<AppMode>(
                title: Text(_getText('routineAnalysis')),
                value: AppMode.analytics,
                groupValue: _currentMode,
                onChanged: (AppMode? value) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentMode = value!;
                  });
                  Navigator.of(context).pop(); // ドロワーを自動で閉じる
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
              // テスト用プレミアム切り替え（デバッグ用）
              ListTile(
                leading: Icon(
                  _userSubscription.isPremium ? Icons.star : Icons.star_border,
                  color: _userSubscription.isPremium ? Colors.amber : Colors.grey,
                ),
                title: Text(
                  'テスト: ${_userSubscription.isPremium ? 'プレミアム無効化' : 'プレミアム有効化'}',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'デバッグ用機能',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () {
                  _togglePremiumForTesting();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_currentMode == AppMode.chat)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: TextButton(
                    onPressed: _resetChat,
                    child: const Text('チャットをリセット'),
                  ),
                ),
              ),
            Expanded(
              child: _currentMode == AppMode.chat
                  ? _buildChatInterface()
                  : _currentMode == AppMode.dScore
                    ? _buildDScoreInterface()
                    : _currentMode == AppMode.allApparatus
                      ? _buildAllApparatusInterface()
                      : _currentMode == AppMode.analytics
                        ? _buildAnalyticsInterface()
                        : _buildAdminInterface(),
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
                            });
                            _loadSkills(newValue);
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
                            onPressed: _routine.isNotEmpty ? _saveCurrentRoutine : null,
                            tooltip: '構成を保存',
                            padding: const EdgeInsets.all(4),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 20),
                            onPressed: _showSavedRoutines,
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
                        ] else if (_routine.length >= 2)
                          ElevatedButton.icon(
                            onPressed: () {
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
                          const Text('技をタップして編集', style: TextStyle(color: Colors.grey)),
                        ElevatedButton.icon(
                          onPressed: _routine.isNotEmpty && _selectedApparatus != null
                            ? () {
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
                                  });
                                  return;
                                }
                                
                                // 新規計算
                                final result = calculateDScore(_selectedApparatus!, routineForCalculation);
                                
                                // キャッシュに保存
                                _calculationCache[cacheKey] = result;
                                _lastCalculationKey = cacheKey;
                                
                                setState(() {
                                  _dScoreResult = result;
                                });
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
            height: isMobile ? 250 : 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              itemCount: _getFilteredSkillList().length,
              itemBuilder: (context, index) {
                final skill = _getFilteredSkillList()[index];
                final isSelected = _selectedSkill?.name == skill.name;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        padding: EdgeInsets.all(isMobile ? 8 : 10),
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
        
        // 選択された技の表示
        const SizedBox(height: 12),
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
            icon: const Icon(Icons.add),
            label: Text(_isEditingSkill ? _getText('changeSkill') : _getText('addSkill')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                      color: Colors.green[700],
                                      fontSize: isMobile ? 20 : 24,
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
                                  color: Colors.green[800],
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'points',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
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
                    
                    // 共有・エクスポートボタン
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '共有・エクスポート',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildShareButton(
                                  Icons.share,
                                  '共有URL',
                                  _generateShareUrl,
                                  Colors.blue,
                                ),
                                _buildShareButton(
                                  Icons.download,
                                  'JSON',
                                  _exportRoutineAsJson,
                                  Colors.green,
                                ),
                                _buildShareButton(
                                  Icons.text_snippet,
                                  'テキスト',
                                  _exportAnalysisAsText,
                                  Colors.orange,
                                ),
                                _buildShareButton(
                                  Icons.print,
                                  'HTML',
                                  _exportHtmlReport,
                                  Colors.purple,
                                ),
                                _buildShareButton(
                                  Icons.social_distance,
                                  'SNS',
                                  _generateSocialText,
                                  Colors.teal,
                                ),
                              ],
                            ),
                          ],
                        ),
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
  
  // 共有・エクスポートボタンのウィジェット
  Widget _buildShareButton(IconData icon, String label, VoidCallback onPressed, MaterialColor color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color[700]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color[700],
                ),
              ),
            ],
          ),
        ),
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
                          color: color[700],
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

  // チャット用のUI
  Widget _buildChatInterface() {
    return SafeArea(
      child: Column(
        children: [
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
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }
  
  // バナー広告ウィジェット
  Widget _buildBannerAd() {
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
  
  // 保存された演技構成を読み込み
  Future<void> _loadSavedRoutines() async {
    try {
      final routinesData = await _storage.read(key: 'saved_routines');
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
            
            // ローカルストレージに保存
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

  // コントローラーを追加（初期化部分で定義が必要）
  final TextEditingController _analyticsController = TextEditingController();

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

  // AI応答の生成
  void _generateAnalyticsResponse(String userInput, RoutineAnalysis analysis) {
    // 演技構成に基づいたコンテキストを含む応答
    String response = '';
    
    final lowerInput = userInput.toLowerCase();
    
    if (lowerInput.contains('難度') || lowerInput.contains('難しい')) {
      response = '現在の平均難度は${analysis.averageDifficulty.toStringAsFixed(2)}です。C難度以上の技を増やすことで得点向上が見込めます。具体的にどの種目の技について相談されますか？';
    } else if (lowerInput.contains('グループ') || lowerInput.contains('要求')) {
      response = '要求充足率は${(analysis.completenessScore * 100).toStringAsFixed(1)}%です。${analysis.missingGroups.isNotEmpty ? "不足しているのは${analysis.missingGroups.join('、')}です。" : "全グループの要求を満たしています！"}どのグループの技について詳しく知りたいですか？';
    } else if (lowerInput.contains('技数') || lowerInput.contains('構成')) {
      response = '現在${analysis.totalSkills}技で構成されています。体操競技では通常8-10技が理想的です。どのような技を追加したいか具体的に相談しましょう！';
    } else {
      response = '演技構成について何でもお聞きください！現在の構成では平均難度${analysis.averageDifficulty.toStringAsFixed(2)}、要求充足率${(analysis.completenessScore * 100).toStringAsFixed(1)}%となっています。具体的にどの部分を改善したいですか？';
    }

    // 実際のアプリでは遅延を模擬
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _analyticsMessages.add(AnalyticsMessage(text: response, isUser: false));
        _isAnalyticsLoading = false;
      });
    });
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
      
      // Dスコア計算モードに切り替え
      _currentMode = AppMode.dScore;
    });
    _loadSkills(apparatus);
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
    return apparatusInfo[apparatus.toLowerCase()];
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
    switch (apparatus.toLowerCase()) {
      case 'vault':
        suggestions += '【跳馬のアドバイス】\n';
        suggestions += '• 1技のみの実施のため、最高難度の技を選択することが重要\n';
        suggestions += '• グループボーナスはないため、個々の技の難度値が決定的\n';
        suggestions += '• 着地の安定性も含めて技を選択しましょう\n';
        break;
      case 'floor':
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
