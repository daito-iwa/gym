# 🍎 Apple Developer設定完全ガイド

## 1. Apple Developer Console 設定

### Step 1: Merchant ID作成
1. [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list/merchant) にアクセス
2. **「+」ボタン** → **「Merchant IDs」** → **「Continue」**
3. 以下を入力：
   ```
   Description: Gymnastics AI Payments
   Identifier: merchant.com.daito.gymnasticsai
   ```
4. **「Register」**をクリック

### Step 2: App ID設定確認
1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) にアクセス
2. **「com.daito.gymnasticsai」**を検索
3. **「Edit」**をクリック
4. **Capabilities**で以下を有効化：
   - ✅ In-App Purchase
   - ✅ Push Notifications（必要に応じて）
5. **「Save」**をクリック

## 2. App Store Connect 設定

### Step 1: アプリ登録
1. [App Store Connect](https://appstoreconnect.apple.com/apps) にアクセス
2. **「新規アプリ」**または既存アプリを選択
3. 基本情報：
   ```
   Bundle ID: com.daito.gymnasticsai
   Name: Gym AI
   Primary Language: Japanese
   SKU: gymnastics-ai-2024
   ```

### Step 2: サブスクリプション商品作成
1. アプリ → **「機能」** → **「App内課金」** → **「管理」**
2. **「作成」** → **「自動更新サブスクリプション」**
3. サブスクリプショングループ作成：
   ```
   参照名: Premium Subscription Group
   ```
4. 商品詳細：
   ```
   商品ID: premium_monthly_subscription
   参照名: Premium Monthly Plan
   期間: 1ヶ月
   価格: ¥500 (Tier 5)
   ```
5. 表示名・説明入力：
   ```
   日本語: プレミアムプラン
   English: Premium Plan
   
   説明: 体操AI専門コーチの無制限チャット機能
   ```

## 3. Provisioning Profile 再作成

### Development Profile
1. [Profiles](https://developer.apple.com/account/resources/profiles/list) にアクセス
2. 既存の`com.daito.gymnasticsai`プロファイルを**削除**
3. **「+」** → **「iOS App Development」**
4. 設定：
   ```
   App ID: com.daito.gymnasticsai
   Certificates: 開発者証明書を選択
   Devices: テストデバイスを選択
   Profile Name: Gym AI Development
   ```
5. **「Generate」** → **「Download」**

### Distribution Profile（本番用）
1. **「+」** → **「App Store」**
2. 同様の設定で**「Gym AI Distribution」**作成

## 4. Xcode 設定

1. Xcodeで`ios/Runner.xcodeproj`を開く
2. **Runner**ターゲット選択
3. **「Signing & Capabilities」**タブ
4. 設定確認：
   ```
   Team: 正しいDeveloperチーム
   Bundle Identifier: com.daito.gymnasticsai
   ```
5. **「+ Capability」** → **「In-App Purchase」**追加

## 5. 動作確認

### Sandbox テスト
1. App Store Connect → **「ユーザーとアクセス」** → **「Sandboxテスター」**
2. テストアカウント作成
3. iOSデバイスで**「設定」** → **「App Store」** → **「SANDBOX ACCOUNT」**
4. テストアカウントでサインイン
5. アプリで購入テスト実行

## ⚠️ トラブルシューティング

### エラー: "Communication with Apple failed"
- Merchant IDが作成されているか確認
- App IDでIn-App Purchaseが有効か確認
- Provisioning Profileが最新か確認

### エラー: "Product not found"
- App Store Connectで商品IDが正しく設定されているか確認
- 商品が「準備完了」状態になっているか確認
- Bundle IDが完全一致しているか確認

## 📋 設定完了チェックリスト

- [ ] Merchant ID作成完了
- [ ] App ID設定完了（In-App Purchase有効）
- [ ] App Store Connectでアプリ登録完了
- [ ] サブスクリプション商品作成完了
- [ ] Provisioning Profile再作成完了
- [ ] Xcode設定完了
- [ ] Sandboxテスト完了

## 🎯 最終確認事項

すべての設定完了後：
1. **Clean Build Folder** (⌘+Shift+K)
2. **実機ビルド**テスト
3. **サブスクリプション購入**テスト
4. **サーバー検証**テスト

---
*このガイドに従って設定を完了すると、サブスクリプション機能が本番環境で正常に動作します。*