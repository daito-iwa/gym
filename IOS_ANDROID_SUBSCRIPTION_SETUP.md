# 📱 iOS & Android サブスクリプション設定ガイド

## 🍎 iOS App Store Connect設定

### 1. App Store Connectでアプリ登録
1. [App Store Connect](https://appstoreconnect.apple.com/)にログイン
2. 「マイアプリ」→「+」→「新しいアプリ」
3. アプリ情報入力：
   - **名前**: `Gymnastics AI`
   - **プライマリ言語**: 日本語
   - **バンドルID**: `com.daito.gym` (Xcodeと一致させる)
   - **SKU**: `gymnastics-ai-ios`

### 2. サブスクリプション作成
1. アプリ詳細→「App内課金」→「サブスクリプション」
2. 「サブスクリプショングループを作成」
   - **参照名**: `Premium Subscriptions`
   - **App Store表示名**: `プレミアム`

3. 新しいサブスクリプション作成：
   ```yaml
   商品ID: com.daito.gym.premium_monthly_subscription
   参照名: Premium Monthly Subscription
   期間: 1ヶ月
   価格: ¥480 (Tier 5)
   
   表示名: プレミアムプラン
   説明: 広告非表示・無制限AIチャット・詳細分析機能
   ```

### 3. 税・契約設定
- 「契約・税・銀行業務」で必要情報を入力
- 日本の税務情報を設定

---

## 🤖 Android Google Play Console設定

### 1. Play Consoleでアプリ登録
1. [Google Play Console](https://play.google.com/console/)にログイン
2. 「アプリを作成」
3. アプリ詳細：
   - **アプリ名**: `Gymnastics AI`
   - **デフォルトの言語**: 日本語
   - **アプリケーションID**: `com.daito.gym`

### 2. サブスクリプション作成  
1. 「収益化」→「商品」→「サブスクリプション」→「サブスクリプションを作成」
2. サブスクリプション設定：
   ```yaml
   商品ID: premium_monthly_subscription
   名前: プレミアムプラン
   説明: 広告非表示・無制限AIチャット・詳細分析機能
   
   請求期間: 月単位（1ヶ月）
   価格: ¥480
   無料トライアル: 7日間（オプション）
   ```

### 3. ライセンステスト設定
- 「収益化」→「設定」→「ライセンステスト」
- テスト用Googleアカウントを追加

---

## 💳 Stripe決済統合（Web版用）

### 1. Stripe商品作成
```bash
# Stripe CLI使用
stripe products create \
  --name="Gymnastics AI Premium" \
  --description="広告非表示・無制限AIチャット・詳細分析機能"

stripe prices create \
  --unit-amount=48000 \
  --currency=jpy \
  --recurring[interval]=month \
  --product=prod_XXXXXXXXXXXXXXXX
```

### 2. Webhookエンドポイント設定
- **エンドポイントURL**: `https://your-api.com/webhook/stripe`
- **イベント選択**:
  - `customer.subscription.created`
  - `customer.subscription.updated` 
  - `customer.subscription.deleted`
  - `invoice.payment_succeeded`
  - `invoice.payment_failed`

---

## 🔧 アプリ内設定

### pubspec.yaml依存関係確認
```yaml
dependencies:
  in_app_purchase: ^3.1.11
  in_app_purchase_android: ^0.3.0+18
  in_app_purchase_storekit: ^0.3.6+7
  http: ^1.1.0
```

### purchase_manager.dart使用例
```dart
// 初期化
final purchaseManager = PurchaseManager();
await purchaseManager.initialize();

// コールバック設定
purchaseManager.onPurchaseSuccess = () {
  print('購入成功！');
  // UI更新処理
};

purchaseManager.onPurchaseError = (error) {
  print('購入エラー: $error');
  // エラー表示処理
};

// 購入処理
bool success = await purchaseManager.purchasePremium();

// プレミアム状態確認
if (purchaseManager.isPremiumActive) {
  // プレミアム機能有効
}
```

---

## 🧪 テスト手順

### iOS テスト
1. Xcode→「Product」→「Scheme」→「Edit Scheme」
2. 「Run」→「Arguments」で環境変数設定
3. Sandbox環境でのテストアカウント使用
4. TestFlight配信前テスト

### Android テスト
1. Play Consoleで内部テスト版アップロード  
2. ライセンステスターとしてアカウント追加
3. Google Play Billingテスト

### 共通テスト項目
- [ ] 購入フロー正常動作
- [ ] 購入復元機能
- [ ] サブスクリプション更新
- [ ] 解約処理
- [ ] サーバー購入検証
- [ ] プレミアム機能の有効/無効切り替え

---

## ⚠️ 重要な注意事項

### セキュリティ
- **絶対に**クライアント側で購入状態を信頼しない
- サーバー側での購入検証を必須とする
- レシート検証APIを適切に実装

### ユーザー体験
- 購入フローを可能な限りシンプルに
- エラーメッセージをわかりやすく表示
- 購入復元機能を提供

### コンプライアンス  
- プライバシーポリシーでサブスクリプション情報の取り扱いを明記
- 自動更新の仕組みを明確に説明
- 解約方法を明示

---

**次のステップ**: 上記設定完了後、実際のアプリでテスト購入を実行してください。