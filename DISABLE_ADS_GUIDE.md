# 🚫 広告機能完全無効化ガイド

## 現在の状況
- 広告は現在表示されていません（設定未完了のため）
- コードには広告表示機能が含まれているが無効状態

## 広告を完全に無効化する方法

### Option 1: 設定で無効化（推奨）
```dart
// lib/admob_config.dart に追加
class AdMobConfig {
  // 広告完全無効化フラグ
  static const bool ADS_DISABLED = true;
  
  static String get bannerAdUnitId {
    if (ADS_DISABLED) return '';
    // ... 既存のコード
  }
}
```

### Option 2: 広告コード完全削除
1. `lib/admob_config.dart` ファイル削除
2. `pubspec.yaml` から `google_mobile_ads` 削除
3. `lib/main.dart` からAdManager関連コード削除

### Option 3: FeatureManagerで制御
```dart
// 現在のコード
FeatureAccessManager.shouldShowAds(_userSubscription)
// を常にfalseに変更
```

## 推奨アプローチ
**Option 1** が推奨です。将来的に広告を導入する可能性がある場合、コードを残しつつ設定で無効化できます。