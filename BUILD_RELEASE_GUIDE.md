# 📱 アプリビルド・リリース実行ガイド

## 🍎 iOS リリースビルド

### 1. Xcode設定確認
```bash
# プロジェクトを開く
open ios/Runner.xcworkspace
```

### 2. 署名設定
- **Team**: Apple Developer アカウント選択
- **Bundle Identifier**: `com.daito.gym`
- **Automatically manage signing**: ✅ 有効
- **Deployment Target**: iOS 12.0 以上

### 3. Info.plist 最終確認
```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleDisplayName</key>
<string>Gymnastics AI</string>

<key>CFBundleVersion</key>
<string>1.0.0</string>

<!-- AdMob本番ID設定 -->
<key>GADApplicationIdentifier</key>
<string>実際のAdMob iOS App ID</string>
```

### 4. リリースビルド実行
```bash
# クリーンビルド
flutter clean
flutter pub get

# iOS リリースビルド
flutter build ios --release

# App Store用アーカイブ（Xcodeで実行）
# Product → Archive → Distribute App → App Store Connect
```

---

## 🤖 Android リリースビルド

### 1. キーストア準備
```bash
# キーストア作成（初回のみ）
keytool -genkey -v -keystore android/app/gymnastics-ai-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gymnastics-ai \
  -dname "CN=Gymnastics AI, OU=Mobile, O=Daito, L=Tokyo, S=Tokyo, C=JP"
```

### 2. android/key.properties作成
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=gymnastics-ai
storeFile=gymnastics-ai-keystore.jks
```

### 3. android/app/build.gradle.kts 署名設定確認
```kotlin
android {
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = Properties()
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 4. AndroidManifest.xml 最終確認
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application android:label="Gymnastics AI">
    <!-- AdMob本番ID設定 -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="実際のAdMob Android App ID"/>
</application>
```

### 5. リリースビルド実行
```bash
# クリーンビルド
flutter clean
flutter pub get

# Android App Bundle生成（推奨）
flutter build appbundle --release

# APK生成（テスト用）
flutter build apk --release
```

**生成ファイル**:
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🌐 Web版デプロイ

### Netlifyデプロイ
```bash
# Webビルド
flutter build web --release

# Netlify手動デプロイ
# build/web フォルダをNetlifyにドラッグ&ドロップ

# またはNetlify CLI使用
npm install -g netlify-cli
netlify deploy --prod --dir=build/web
```

---

## 🧪 リリース前テスト項目

### 必須テスト
- [ ] アプリ起動・基本機能動作確認
- [ ] D-Score計算正確性確認
- [ ] AIチャット機能テスト
- [ ] 課金フロー動作確認（サンドボックス）
- [ ] 広告表示確認（テストモード）
- [ ] オンライン/オフライン切り替えテスト
- [ ] 各画面のレスポンシブ対応確認
- [ ] パフォーマンステスト（起動時間、メモリ使用量）

### プラットフォーム固有テスト

#### iOS
- [ ] iPhone/iPad各サイズでレイアウト確認
- [ ] ダークモード対応確認
- [ ] バックグラウンド/フォアグラウンド復帰テスト
- [ ] TestFlightでのβテスト

#### Android  
- [ ] 各画面サイズ・解像度確認
- [ ] Android 6〜14での動作確認
- [ ] バックボタン動作確認
- [ ] Play Console 内部テスト

---

## 📋 ビルド前チェックリスト

### コード設定
- [ ] `lib/config.dart` で本番環境設定
- [ ] `lib/admob_config.dart` で本番ID設定
- [ ] デバッグログ無効化
- [ ] `pubspec.yaml` でバージョン更新

### アセット確認
- [ ] アプリアイコン設定（全サイズ）
- [ ] スプラッシュスクリーン設定
- [ ] 必要なフォント・画像リソース

### 法的コンプライアンス
- [ ] プライバシーポリシーURL確認
- [ ] 利用規約URL確認
- [ ] ライセンス表記確認

---

## 🚨 トラブルシューティング

### よくあるビルドエラー

#### iOS
```bash
# CocoaPodsエラー
cd ios && pod clean && pod install --repo-update

# 証明書エラー
# Xcode → Preferences → Accounts でApple IDログイン確認
```

#### Android
```bash
# Gradle エラー
cd android && ./gradlew clean

# キーストア エラー
# key.propertiesのパスと設定値を確認
```

### パフォーマンス最適化
```bash
# ビルドサイズ確認
flutter build apk --analyze-size
flutter build appbundle --analyze-size

# 不要なパッケージ削除
flutter packages deps
```

---

## 📊 リリース後監視項目

### 技術指標
- アプリクラッシュ率 < 1%
- 起動時間 < 3秒
- メモリ使用量監視
- API応答時間監視

### ビジネス指標  
- インストール数
- 課金コンバージョン率
- 広告収益
- ユーザーレビュー評価

---

**🎯 目標: 初回リリース時の重大バグ0件達成**