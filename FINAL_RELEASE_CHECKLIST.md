# ✅ iOS/Android リリース 最終チェックリスト

## 🏗️ Phase 1: AdMob 本番設定 ✅
- [x] AdMob本番ID取得手順書作成 (`ADMOB_PRODUCTION_SETUP_INSTRUCTIONS.md`)
- [ ] **要対応**: AdMobコンソールで実際のID取得
- [ ] **要対応**: `lib/admob_config.dart` に本番ID設定
- [ ] **要対応**: `android/app/src/main/AndroidManifest.xml` 更新
- [ ] **要対応**: `ios/Runner/Info.plist` 更新
- [ ] **要対応**: デバッグモード無効化 (`_isDebugMode = false`)

---

## 💳 Phase 2: 課金システム完全実装 ✅
- [x] 完全版PurchaseManager実装 (`lib/purchase_manager.dart`)
- [x] iOS/Android サブスクリプション設定ガイド作成
- [ ] **要対応**: App Store Connect でサブスクリプション商品作成
- [ ] **要対応**: Google Play Console でサブスクリプション商品作成
- [ ] **要対応**: サーバー側購入検証エンドポイント実装

---

## 🚀 Phase 3: サーバー本番デプロイ ✅ 
- [x] Google App Engine設定ファイル (`app.yaml`, `secrets.yaml`)
- [x] 本番デプロイスクリプト (`deploy-production.sh`)
- [x] App Engineエントリーポイント (`main.py`)
- [ ] **要対応**: Google Cloud プロジェクト作成
- [ ] **要対応**: 実際のデプロイ実行
- [ ] **要対応**: `lib/config.dart` のproduction URL更新

---

## 📱 Phase 4: アプリストア申請準備

### iOS App Store Connect
- [ ] **開発者アカウント登録** (年間99ドル)
- [ ] **App Store Connect でアプリ作成**
  - アプリ名: `Gymnastics AI`
  - Bundle ID: `com.daito.gym`
  - SKU: `gymnastics-ai-ios`
- [ ] **アプリメタデータ入力**
  - 説明文（日本語・英語）
  - キーワード
  - カテゴリ: Sports
  - 年齢制限: 4+
- [ ] **スクリーンショット準備**
  - iPhone 6.7": 3枚
  - iPhone 6.5": 3枚  
  - iPad Pro 12.9": 3枚
- [ ] **プライバシーポリシーURL設定**
- [ ] **サブスクリプション設定**
- [ ] **TestFlight内部テスト**

### Android Google Play Console
- [ ] **開発者アカウント登録** (1回25ドル)
- [ ] **Google Play Console でアプリ作成**
  - アプリ名: `Gymnastics AI`
  - パッケージ名: `com.daito.gym`
- [ ] **ストアリスティング作成**
  - 説明文（日本語・英語）
  - カテゴリ: Sports
  - 対象年齢: Everyone
- [ ] **スクリーンショット準備**
  - スマートフォン: 8枚
  - タブレット: 1枚
- [ ] **プライバシーポリシーURL設定**
- [ ] **サブスクリプション設定**
- [ ] **内部テスト配信**

---

## 🔧 ビルド設定

### iOS ビルド準備
```bash
# iOS証明書・プロビジョニングプロファイル設定
# Xcodeで「Automatically manage signing」有効化
# Team設定確認

# リリースビルド
flutter build ios --release
```

### Android ビルド準備  
```bash
# キーストア作成（初回のみ）
keytool -genkey -v -keystore android/app/gymnastics-ai-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias gymnastics-ai

# android/key.properties 作成
storePassword=<password>
keyPassword=<password>  
keyAlias=gymnastics-ai
storeFile=gymnastics-ai-keystore.jks

# App Bundleビルド
flutter build appbundle --release
```

---

## 📊 収益予測（リリース後）

### 月間収益目標
```yaml
想定ユーザー数: 1,000 DAU
無料ユーザー率: 70% (700人)

広告収益:
- バナー: ¥70,000/月
- インタースティシャル: ¥420,000/月  
- リワード: ¥210,000/月

課金収益:
- プレミアムユーザー(30%): 300人 × ¥480 = ¥144,000/月

合計予想収益: ¥844,000/月
```

---

## ⚠️ 重要な注意事項

### セキュリティ
- [ ] **本番用APIキー設定確認**
- [ ] **デバッグログ無効化**
- [ ] **HTTPS通信確認**
- [ ] **購入検証サーバー側実装**

### 法的コンプライアンス
- [ ] **プライバシーポリシー作成・公開**
- [ ] **利用規約作成・公開** 
- [ ] **特定商取引法表記（課金あり）**
- [ ] **消費者契約法コンプライアンス**

### ユーザー体験
- [ ] **オンボーディング最適化**
- [ ] **エラーハンドリング確認**
- [ ] **オフライン機能テスト**
- [ ] **パフォーマンス最適化**

---

## 🗓️ リリーススケジュール

### Week 1: 基盤設定
- AdMob本番ID設定
- サーバーデプロイ
- 課金システム実装

### Week 2: アプリストア準備
- ストアリスティング作成
- スクリーンショット撮影
- 法的文書準備

### Week 3: テスト・審査申請
- 内部テスト実施
- ストア審査申請
- バグ修正・改善

### Week 4: リリース・運用開始
- 正式リリース
- ユーザーフィードバック対応
- 収益分析開始

---

**🎯 目標: 1ヶ月以内にiOS/Android同時リリース達成**
**💰 目標: 初月100万円収益達成**