# 💰 Google AdMob 収益化完全設定ガイド

## 🚀 Step 1: AdMob アカウント作成

### 1. AdMob アカウント作成
1. [Google AdMob](https://admob.google.com/) にアクセス
2. 「今すぐ開始」をクリック
3. Googleアカウントでログイン（既存のDeveloper Accountと同じものを使用推奨）

### 2. AdMob アカウント設定
```yaml
アカウントタイプ: 個人事業主
国/地域: 日本
タイムゾーン: (GMT+09:00) 大阪、札幌、東京
通貨: 日本円 (JPY)
```

### 3. 支払い情報設定
```yaml
支払い方法: 
- 銀行振込（8,000円以上で自動支払い）
- または小切手（推奨しない）

税務情報: 
- 日本の税務情報を入力
- 個人事業主の場合、マイナンバー必要
```

## 📱 Step 2: アプリ登録

### iOS アプリ登録
```yaml
アプリ名: Gym AI
プラットフォーム: iOS
アプリストアURL: (App Store Connect完了後に入力)
アプリカテゴリ: スポーツ
```

### Android アプリ登録  
```yaml
アプリ名: Gym AI
プラットフォーム: Android
Google Playストア URL: (Google Play Console完了後に入力)
アプリカテゴリ: スポーツ
```

## 💡 Step 3: 広告ユニット作成

### 推奨広告ユニット構成

#### 1. バナー広告（常時表示）
```yaml
iOS バナー:
広告ユニット名: Gym AI iOS Banner
広告フォーマット: バナー
配置: アプリ下部

Android バナー:
広告ユニット名: Gym AI Android Banner  
広告フォーマット: バナー
配置: アプリ下部
```

#### 2. インタースティシャル広告（全画面）
```yaml  
iOS インタースティシャル:
広告ユニット名: Gym AI iOS Interstitial
広告フォーマット: インタースティシャル
配置: 画面遷移時

Android インタースティシャル:
広告ユニット名: Gym AI Android Interstitial
広告フォーマット: インタースティシャル
配置: 画面遷移時
```

#### 3. リワード広告（報酬型）
```yaml
iOS リワード:
広告ユニット名: Gym AI iOS Rewarded
広告フォーマット: リワード
特典: AIチャット1回無料

Android リワード:  
広告ユニット名: Gym AI Android Rewarded
広告フォーマット: リワード
特典: AIチャット1回無料
```

## 🔧 Step 4: アプリコード更新

### 1. AdMob設定ファイル更新
実際のAdMob IDを取得して設定：

```dart
// lib/admob_config.dart
class AdMobConfig {
  // 本番用広告ID（AdMobから取得した実際のID）
  static const String productionAppIdAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx';
  static const String productionAppIdIOS = 'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx';
  
  // バナー広告ID
  static const String productionBannerAdUnitIdAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String productionBannerAdUnitIdIOS = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  
  // インタースティシャル広告ID
  static const String productionInterstitialAdUnitIdAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String productionInterstitialAdUnitIdIOS = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  
  // リワード広告ID
  static const String productionRewardedAdUnitIdAndroid = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String productionRewardedAdUnitIdIOS = 'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
}
```

### 2. Info.plist更新（iOS）
```xml
<!-- ios/Runner/Info.plist -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx</string>
```

### 3. AndroidManifest.xml更新
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx"/>
```

## 💰 Step 5: 収益最大化戦略

### 広告配置最適化
```yaml
バナー広告:
- 配置: アプリ下部（常時表示）
- 対象: 無料ユーザーのみ
- 予想収益: $0.05-0.15/日/ユーザー

インタースティシャル広告:
- 配置: 計算完了時、種目切り替え時
- 頻度: 3回操作に1回程度
- 予想収益: $0.10-0.30/表示

リワード広告:
- 特典: AIチャット1回追加
- 配置: AIチャット制限到達時
- 予想収益: $0.15-0.50/表示
```

### 収益予測（月間）
```yaml
想定ユーザー数: 1,000 DAU
無料ユーザー率: 70% (700人)

バナー広告収益:
700人 × $0.10/日 × 30日 = $2,100/月

インタースティシャル収益:  
700人 × 5回/日 × $0.20 × 30日 = $21,000/月

リワード収益:
700人 × 2回/日 × $0.30 × 30日 = $12,600/月

合計予想収益: $35,700/月 (約500万円)
```

## 🎯 Step 6: 広告表示ロジック実装

### ユーザー体験を損なわない配置
```dart
// 広告表示タイミング
class AdDisplayManager {
  static int _calculationCount = 0;
  static int _screenTransitionCount = 0;
  
  // 計算完了時のインタースティシャル
  static void showCalculationCompleteAd() {
    _calculationCount++;
    if (_calculationCount % 3 == 0) {
      _adManager.showInterstitialAd();
    }
  }
  
  // AIチャット制限時のリワード広告
  static void showRewardedAdForChat() {
    _adManager.showRewardedAd((reward) {
      // AIチャット回数を1回追加
      ChatLimitManager.addFreeChat();
    });
  }
}
```

## 📊 Step 7: 収益分析・最適化

### AdMob Analytics活用
```yaml
重要指標:
- インプレッション数（広告表示回数）
- クリック率（CTR）
- 収益性（RPM = 1000インプレッションあたりの収益）
- フィルレート（広告配信成功率）

最適化手法:
- A/Bテストでの配置テスト
- 広告サイズの最適化
- 配信業者の調整
- ユーザーセグメント別配信
```

### 収益レポート
```yaml
日次チェック項目:
- 収益額
- インプレッション数
- アクティブユーザー数
- 広告単価（eCPM）

月次最適化:
- 配置見直し
- 新しい広告フォーマット導入
- ユーザーフィードバック分析
```

## 🔗 Step 8: プレミアムプランとの連携

### 収益バランス戦略
```yaml
無料ユーザー: 
- バナー広告常時表示
- インタースティシャル適度表示
- リワード広告でAIチャット追加

プレミアムユーザー (¥480/月):
- 全広告非表示
- 無制限AIチャット
- 詳細分析機能

収益計算:
広告収益: 無料ユーザー × 月$10
課金収益: プレミアムユーザー × ¥480
```

## ⚠️ 注意事項・ポリシー

### AdMobポリシー準拠
```yaml
禁止事項:
- 誤クリックを誘発する配置
- 広告を隠す・改変する
- 無関係なアプリでのクリック
- 自己クリック

推奨事項:
- 自然な配置
- ユーザーエクスペリエンス重視
- 適切な広告頻度
- 高品質なコンテンツ
```

## ✅ 設定完了チェックリスト

### AdMobアカウント
- [ ] アカウント作成完了
- [ ] 支払い情報登録完了
- [ ] 税務情報登録完了
- [ ] アプリ登録完了

### 広告ユニット
- [ ] iOS バナー広告作成
- [ ] Android バナー広告作成  
- [ ] iOS インタースティシャル作成
- [ ] Android インタースティシャル作成
- [ ] iOS リワード広告作成
- [ ] Android リワード広告作成

### アプリ実装
- [ ] AdMob ID設定完了
- [ ] Info.plist更新完了
- [ ] AndroidManifest.xml更新完了
- [ ] 広告表示テスト完了

---

**予想収益: 月額数十万円〜数百万円（ユーザー数次第）** 💰