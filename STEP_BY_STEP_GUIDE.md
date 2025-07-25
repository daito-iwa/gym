# 📱 Apple設定 - 超詳細手順書

## 🚀 STEP 1: Apple Developer Console

### 1️⃣ サイトにアクセス
1. **Chrome/Safari**で https://developer.apple.com を開く
2. 右上の **「Account」** をクリック
3. **Apple ID**と**パスワード**でサインイン
4. **「Certificates, Identifiers & Profiles」** をクリック

### 2️⃣ Merchant ID作成
1. 左メニューの **「Identifiers」** をクリック
2. 画面右上の **「+ (プラス)」** ボタンをクリック
3. **「Merchant IDs」** にチェック → **「Continue」** をクリック
4. 入力フォームに以下を記入：
   ```
   Description: Gymnastics AI Payments
   Identifier: merchant.com.daito.gymnasticsai
   ```
5. **「Register」** をクリック
6. ✅ **「Registration Complete」** が表示されればOK

### 3️⃣ App ID設定確認
1. 左メニューの **「Identifiers」** をクリック
2. 検索ボックスに **「com.daito.gymnasticsai」** と入力
3. 該当するApp IDをクリック
4. **「Capabilities」** セクションで以下を確認：
   - ✅ **In-App Purchase** にチェックが入っているか
   - 入っていない場合：**「Edit」** → チェックを入れる → **「Save」**

---

## 🏪 STEP 2: App Store Connect

### 1️⃣ App Store Connectにアクセス
1. **新しいタブ**で https://appstoreconnect.apple.com を開く
2. 同じApple IDでサインイン
3. **「My Apps」** をクリック

### 2️⃣ アプリ確認/作成
**既存アプリがある場合：**
1. **「Gym AI」** または類似名のアプリをクリック
2. Bundle IDが **「com.daito.gymnasticsai」** か確認

**新規アプリ作成の場合：**
1. **「+ (プラス)」** → **「New App」** をクリック
2. 以下を入力：
   ```
   Platform: iOS
   Name: Gym AI
   Primary Language: Japanese
   Bundle ID: com.daito.gymnasticsai
   SKU: gymnastics-ai-2024
   ```

### 3️⃣ サブスクリプション商品作成
1. アプリ画面で **「Features」** タブをクリック
2. **「In-App Purchases」** → **「Manage」** をクリック
3. **「Create」** → **「Auto-Renewable Subscription」** を選択

### 4️⃣ サブスクリプショングループ作成
1. **「Create New Subscription Group」** をクリック
2. **Reference Name**: `Premium Subscription Group`
3. **「Create」** をクリック

### 5️⃣ 商品詳細設定
1. **「Create Subscription」** をクリック
2. 以下を入力：
   ```
   Product ID: premium_monthly_subscription
   Reference Name: Premium Monthly Plan
   Subscription Duration: 1 Month
   ```
3. **「Create」** をクリック

### 6️⃣ 価格設定
1. **「Price」** セクションで **「Set Starting Price」** をクリック
2. **「Japan」** を選択 → **「¥500」** を設定
3. 他の国も自動設定される
4. **「Next」** をクリック

### 7️⃣ 表示情報入力
1. **「Localization」** で **「Create」** をクリック
2. **「Japanese」** を選択
3. 以下を入力：
   ```
   Display Name: プレミアムプラン
   Description: 体操AI専門コーチの無制限チャット機能とプレミアム指導コンテンツ
   ```
4. **「Save」** をクリック

---

## 🔐 STEP 3: Provisioning Profile

### 1️⃣ 既存Profile削除
1. Apple Developer Console → **「Profiles」** をクリック
2. **「com.daito.gymnasticsai」** を含むProfileを検索
3. 該当するProfileの **「Delete」** をクリック

### 2️⃣ 新規Profile作成
1. **「+ (プラス)」** をクリック
2. **「iOS App Development」** を選択 → **「Continue」**
3. **「App ID」** で **「com.daito.gymnasticsai」** を選択
4. **「Certificates」** で開発者証明書を選択
5. **「Devices」** でテストデバイスを選択
6. **「Profile Name」**: `Gym AI Development`
7. **「Generate」** → **「Download」** をクリック

---

## 💻 STEP 4: Xcode設定

### 1️⃣ Xcodeを開く
1. **Finder** → **「Desktop」** → **「gym」** → **「ios」**
2. **「Runner.xcworkspace」** をダブルクリック
3. Xcodeが起動するまで待つ

### 2️⃣ プロジェクト設定
1. 左のファイルリストで **「Runner」** (一番上) をクリック
2. **「TARGETS」** の **「Runner」** をクリック
3. **「Signing & Capabilities」** タブをクリック

### 3️⃣ 署名設定
1. **「Team」** を正しいDeveloper Teamに設定
2. **「Bundle Identifier」** が **「com.daito.gymnasticsai」** になっているか確認
3. **「Automatically manage signing」** にチェックが入っているか確認

### 4️⃣ Capability追加
1. **「+ Capability」** をクリック
2. **「In-App Purchase」** を検索して追加

---

## ✅ 確認チェックリスト

### Apple Developer Console
- [ ] Merchant ID作成完了: `merchant.com.daito.gymnasticsai`
- [ ] App ID設定完了: In-App Purchase有効化

### App Store Connect  
- [ ] アプリ登録完了: Bundle ID `com.daito.gymnasticsai`
- [ ] サブスクリプション商品作成完了: `premium_monthly_subscription`
- [ ] 価格設定完了: ¥500

### Provisioning Profile
- [ ] 既存Profile削除完了
- [ ] 新規Profile作成・ダウンロード完了

### Xcode
- [ ] 署名設定完了
- [ ] In-App Purchase Capability追加完了

---

## 🆘 トラブル対応

### ❌ 「Merchant ID already exists」エラー
→ 既に作成済み。次のステップに進む

### ❌ 「App ID not found」エラー  
→ Bundle IDのスペルを確認：`com.daito.gymnasticsai`

### ❌ 「Certificate not found」エラー
→ Apple Developer Consoleで開発者証明書を確認

---

**⚡ この手順書を印刷またはスマホで開いて、一つずつ確実に実行してください！**