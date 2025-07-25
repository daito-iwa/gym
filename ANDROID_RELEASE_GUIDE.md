# 🤖 Android版リリース完全ガイド

## 📱 現在の設定状況

### ✅ 完了済み
- **パッケージ名**: `com.daito.gymnastics_ai`
- **商品ID**: `premium_monthly_subscription`
- **Android BILLING権限**: 追加済み
- **AdMob**: 設定完了

## 🔑 Step 1: 署名キー（Keystore）作成

### Android Studioを使用する方法（推奨）

1. **Android Studio**を開く
2. **Build** → **Generate Signed Bundle/APK**
3. **Android App Bundle**を選択 → **Next**
4. **Create new**をクリック
5. 以下を入力：
   ```
   Key store path: /Users/あなたのユーザー名/gymnastics-ai-release.keystore
   Password: 強力なパスワード（例: GymnAI2024!@#）
   Alias: gymnastics-ai
   Alias Password: 同じパスワード
   Validity (years): 25
   
   Certificate:
   First and Last Name: Daito Iwasaki
   Organizational Unit: Individual
   Organization: Daito Iwasaki
   City: Tokyo
   State: Tokyo
   Country Code: JP
   ```
6. **OK** → キーストア作成完了

### ⚠️ 重要：キーストアのバックアップ
```
作成したキーストアファイルとパスワードは
絶対に失くさないでください！
復元不可能で、アプリの更新ができなくなります。
```

## 📝 Step 2: key.propertiesファイル作成

android/key.propertiesファイルを作成：

```properties
storePassword=あなたのパスワード
keyPassword=あなたのパスワード
keyAlias=gymnastics-ai
storeFile=/Users/あなたのユーザー名/gymnastics-ai-release.keystore
```

## 🔧 Step 3: build.gradle設定

android/app/build.gradleに署名設定を追加：

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 📦 Step 4: AABビルド作成

```bash
# クリーンビルド
flutter clean
flutter pub get

# リリースビルド作成
flutter build appbundle --release
```

ビルド完了後、以下に生成されます：
`build/app/outputs/bundle/release/app-release.aab`

## 🏪 Step 5: Google Play Console設定

### 1. アプリ作成
1. [Google Play Console](https://play.google.com/console)にアクセス
2. **「アプリを作成」**をクリック
3. 以下を入力：
   ```
   アプリ名: Gym AI - 体操AIコーチ
   デフォルトの言語: 日本語
   アプリまたはゲーム: アプリ
   無料または有料: 無料（アプリ内購入あり）
   ```

### 2. アプリ情報入力
- **簡単な説明**（80文字以内）:
  ```
  体操競技の専門AIコーチ。技の解説、ルール説明、D得点計算をサポート
  ```
- **詳しい説明**（4000文字以内）:
  ```
  体操AIは、体操競技のための専門的なAIコーチアプリです。
  
  【主な機能】
  • 820種類以上の技データベース
  • FIG公式ルールに基づく採点計算
  • D得点（難度点）の自動計算
  • 演技構成のアドバイス
  • 技の習得方法解説
  
  【プレミアム機能】
  • 無制限AIチャット
  • 高度な技術指導
  • 詳細な演技分析
  
  初心者から上級者まで、すべての体操選手をサポートします。
  ```

### 3. サブスクリプション商品作成
1. **「収益化」** → **「商品」** → **「定期購入」**
2. **「定期購入を作成」**をクリック
3. 以下を入力：
   ```
   商品ID: premium_monthly_subscription
   名前: プレミアムプラン
   説明: 無制限AIチャット機能
   請求期間: 1か月
   デフォルトの価格: ¥500
   ```

### 4. アプリのコンテンツ評価
1. **「アプリのコンテンツ」**セクション
2. 質問に回答（暴力的コンテンツなし、など）
3. **「全年齢」**評価を取得

### 5. ストア掲載情報
- **カテゴリ**: スポーツ
- **タグ**: 体操、スポーツ、コーチング、AI
- **アイコン**: 512x512px
- **フィーチャーグラフィック**: 1024x500px
- **スクリーンショット**: 最低2枚

## 🚀 Step 6: 内部テスト配信

1. **「テスト」** → **「内部テスト」**
2. **「新しいリリースを作成」**
3. AABファイルをアップロード
4. テスターを追加
5. テストリンクを共有

## ✅ チェックリスト

### 開発側
- [ ] Keystoreファイル作成・バックアップ
- [ ] key.properties設定
- [ ] build.gradle設定
- [ ] AABビルド成功
- [ ] versionCode/versionName更新

### Google Play Console側
- [ ] アプリ作成完了
- [ ] サブスクリプション商品作成
- [ ] ストア掲載情報入力
- [ ] コンテンツ評価完了
- [ ] 内部テスト開始

## 🔒 セキュリティ注意事項

**絶対にGitにコミットしないファイル**:
- `android/key.properties`
- `*.keystore`ファイル
- パスワード情報

**.gitignoreに追加**:
```
android/key.properties
*.keystore
*.jks
```

## 📱 テスト手順

1. **内部テストリンク**からアプリインストール
2. **Google Playでサブスクリプション購入**テスト
3. **プレミアム機能**の動作確認
4. **課金フロー**の確認

---

**準備ができたら、順番に実行していきましょう！**