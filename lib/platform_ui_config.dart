import 'package:flutter/material.dart';
import 'platform_config.dart';
import 'config.dart';

/// プラットフォーム別のUI設定を管理するクラス
/// Web版とモバイル版で異なるUI要素の設定を一元管理
class PlatformUIConfig {
  /// 初期画面の設定
  static AppMode get defaultStartMode {
    if (PlatformConfig.isWeb) {
      return AppMode.chat; // Web版はAIチャットから開始
    } else {
      return AppMode.dScore; // モバイル版は従来通りD-Scoreから開始
    }
  }
  
  /// タブの順序設定
  static List<AppMode> get tabOrder {
    if (PlatformConfig.isWeb) {
      // Web版：AIチャットを最優先
      return [AppMode.chat, AppMode.dScore, AppMode.allApparatus, AppMode.analytics];
    } else {
      // モバイル版：従来の順序
      return [AppMode.dScore, AppMode.allApparatus, AppMode.analytics, AppMode.chat];
    }
  }
  
  /// 指定されたAppModeの表示インデックスを取得
  static int getTabIndex(AppMode mode) {
    return tabOrder.indexOf(mode);
  }
  
  /// インデックスからAppModeを取得
  static AppMode getAppModeFromIndex(int index) {
    if (index >= 0 && index < tabOrder.length) {
      return tabOrder[index];
    }
    return defaultStartMode;
  }
  
  /// タブ情報の定義（ユーザーサブスクリプション状態を考慮）
  static List<TabInfo> getTabItems({bool isUserFree = true}) {
    final tabs = <TabInfo>[];
    
    for (final mode in tabOrder) {
      tabs.add(_getTabInfo(mode, isUserFree: isUserFree));
    }
    
    return tabs;
  }
  
  /// AppModeに対応するタブ情報を取得
  static TabInfo _getTabInfo(AppMode mode, {bool isUserFree = true}) {
    switch (mode) {
      case AppMode.chat:
        return TabInfo(
          mode: AppMode.chat,
          icon: Icons.chat_bubble_outline,
          label: _getChatLabel(),
          featureName: 'AIチャット',
          statusIcon: _getChatStatusIcon(),
        );
      
      case AppMode.dScore:
        return TabInfo(
          mode: AppMode.dScore,
          icon: Icons.calculate,
          label: _getDScoreLabel(isUserFree: isUserFree),
          featureName: 'D-Score計算',
          statusIcon: _getDScoreStatusIcon(isUserFree: isUserFree),
        );
      
      case AppMode.allApparatus:
        return TabInfo(
          mode: AppMode.allApparatus,
          icon: Icons.sports_gymnastics,
          label: _getAllApparatusLabel(isUserFree: isUserFree),
          featureName: '全種目分析',
          statusIcon: _getAllApparatusStatusIcon(isUserFree: isUserFree),
        );
      
      case AppMode.analytics:
        return TabInfo(
          mode: AppMode.analytics,
          icon: Icons.analytics,
          label: _getAnalyticsLabel(isUserFree: isUserFree),
          featureName: 'アナリティクス',
          statusIcon: _getAnalyticsStatusIcon(isUserFree: isUserFree),
        );
      
      case AppMode.admin:
        return TabInfo(
          mode: AppMode.admin,
          icon: Icons.admin_panel_settings,
          label: '管理者',
          featureName: '管理者パネル',
          statusIcon: null,
        );
    }
  }
  
  // プラットフォーム別のラベル設定
  static String _getChatLabel() {
    // AIチャットのラベル（準備中表示も含む）
    if (!AppConfig.enableAIChat) {
      return 'AIチャット🚧';
    }
    return 'AIチャット';
  }
  
  static String _getDScoreLabel({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return 'D-Score'; // Web版はシンプル
    }
    // モバイル版は従来の表示
    return isUserFree ? 'D-Score ⭐' : 'D-Score(オフライン対応)';
  }
  
  static String _getAllApparatusLabel({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return '全種目'; // Web版はシンプル
    }
    // モバイル版は従来の表示
    return isUserFree ? '全種目 ⭐' : '全種目(オフライン対応)';
  }
  
  static String _getAnalyticsLabel({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return '分析'; // Web版はシンプル
    }
    // モバイル版は従来の表示
    return isUserFree ? '分析 ⭐' : '分析(要ネット)';
  }
  
  // プラットフォーム別のステータスアイコン設定
  static StatusIconInfo? _getChatStatusIcon() {
    if (!AppConfig.enableAIChat) {
      return StatusIconInfo(
        icon: Icons.build_circle,
        color: Colors.orange,
        size: 12,
      );
    }
    return StatusIconInfo(
      icon: Icons.cloud,
      color: Colors.blue,
      size: 10,
    );
  }
  
  static StatusIconInfo? _getDScoreStatusIcon({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return null; // Web版では表示しない
    }
    
    if (isUserFree) {
      return StatusIconInfo(
        icon: Icons.star,
        color: Colors.amber,
        size: 12,
      );
    } else {
      return StatusIconInfo(
        icon: Icons.offline_bolt,
        color: Colors.green,
        size: 10,
      );
    }
  }
  
  static StatusIconInfo? _getAllApparatusStatusIcon({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return null; // Web版では表示しない
    }
    
    if (isUserFree) {
      return StatusIconInfo(
        icon: Icons.star,
        color: Colors.amber,
        size: 12,
      );
    } else {
      return StatusIconInfo(
        icon: Icons.offline_bolt,
        color: Colors.green,
        size: 10,
      );
    }
  }
  
  static StatusIconInfo? _getAnalyticsStatusIcon({bool isUserFree = true}) {
    if (PlatformConfig.isWeb) {
      return null; // Web版では表示しない
    }
    
    if (isUserFree) {
      return StatusIconInfo(
        icon: Icons.star,
        color: Colors.amber,
        size: 12,
      );
    } else {
      return StatusIconInfo(
        icon: Icons.cloud,
        color: Colors.blue,
        size: 10,
      );
    }
  }
}

/// AppModeの定義（main.dartから移動）
enum AppMode { dScore, allApparatus, analytics, admin, chat }

// AppConfigはmain.dartで定義済み

/// タブ情報を保持するクラス
class TabInfo {
  final AppMode mode;
  final IconData icon;
  final String label;
  final String featureName;
  final StatusIconInfo? statusIcon;
  
  const TabInfo({
    required this.mode,
    required this.icon,
    required this.label,
    required this.featureName,
    this.statusIcon,
  });
}

/// ステータスアイコン情報を保持するクラス
class StatusIconInfo {
  final IconData icon;
  final Color color;
  final double size;
  
  const StatusIconInfo({
    required this.icon,
    required this.color,
    required this.size,
  });
}