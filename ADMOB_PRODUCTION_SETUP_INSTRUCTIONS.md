# 🚨 AdMob本番ID取得・設定手順

## 📋 必要なAdMob ID一覧

以下のIDをAdMobコンソールから取得してください：

### 1. アプリケーションID
- **Android**: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`  
- **iOS**: `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`

### 2. 広告ユニットID

#### Android
- **Banner**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`
- **Interstitial**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX` 
- **Rewarded**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`

#### iOS  
- **Banner**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`
- **Interstitial**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`
- **Rewarded**: `ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX`

---

## 📱 AdMobコンソールでの設定手順

### Step 1: アプリ登録
1. [AdMob Console](https://apps.admob.com/)にログイン
2. 「アプリを追加」→「アプリは既にリリース済みですか？」で「いいえ」を選択
3. アプリ情報入力：
   - **アプリ名**: `Gymnastics AI`
   - **プラットフォーム**: Android/iOS それぞれ登録
   - **カテゴリ**: スポーツ

### Step 2: 広告ユニット作成 
各プラットフォームで以下の3種類を作成：

#### バナー広告
- **広告ユニット名**: `Gymnastics AI Banner - [Platform]`
- **広告フォーマット**: バナー
- **高度な設定**: デフォルトでOK

#### インタースティシャル広告  
- **広告ユニット名**: `Gymnastics AI Interstitial - [Platform]`
- **広告フォーマット**: インタースティシャル
- **高度な設定**: デフォルトでOK

#### リワード広告
- **広告ユニット名**: `Gymnastics AI Rewarded - [Platform]`  
- **広告フォーマット**: リワード
- **報酬設定**: AIチャット1回追加

---

## ⚠️ 取得したIDの適用方法

### 1. `lib/admob_config.dart` の更新
```dart
// 本番用ID（取得したIDに置き換える）
static const String productionBannerAdUnitIdAndroid = '取得したAndroid Banner ID';
static const String productionBannerAdUnitIdIOS = '取得したiOS Banner ID';
// ... 他のIDも同様に設定
```

### 2. `android/app/src/main/AndroidManifest.xml` の更新
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="取得したAndroid App ID"/>
```

### 3. `ios/Runner/Info.plist` の更新  
```xml
<key>GADApplicationIdentifier</key>
<string>取得したiOS App ID</string>
```

### 4. デバッグモードの無効化
```dart
static bool get _isDebugMode {
    return false; // 本番リリース時はfalseに設定
}
```

---

## 💰 収益予測（実際のIDに変更後）

```yaml
想定収益（月間）:
- 1,000 DAU × 70%無料ユーザー = 700人
- バナー: ¥70,000/月  
- インタースティシャル: ¥420,000/月
- リワード: ¥210,000/月
合計: 約¥700,000/月
```

---

**⚡ 次のアクション**: AdMobコンソールでID取得後、このファイルの手順に従ってコードを更新してください。