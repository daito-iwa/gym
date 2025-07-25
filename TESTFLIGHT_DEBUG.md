# 🔍 TestFlight購入失敗 - デバッグガイド

## 1️⃣ App Store Connect商品状態確認

### 確認箇所
1. App Store Connect → Gymnastics AI → 機能 → App内課金
2. サブスクリプション商品のステータス確認
3. 以下の状態である必要があります：

```
✅ ステータス: 準備完了 または 承認済み
✅ 価格: 設定済み（¥500）
✅ 地域: 日本で利用可能
✅ 表示名: 日本語・英語で設定済み
```

## 2️⃣ 商品ID確認

### アプリ内設定
- purchase_manager.dart: `com.daito.gymnasticsai.premium_monthly_subscription`

### App Store Connect設定  
- 商品ID: 上記と完全一致している必要があります

## 3️⃣ デバッグ用ログ追加

以下をpurchase_manager.dartに追加してArchive再作成：

```dart
// 商品読み込み時のデバッグログ
Future<void> _loadProducts() async {
  try {
    final Set<String> productIds = {premiumProductId};
    print('🔍 Requesting product IDs: $productIds');
    
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds);
    
    print('🔍 Found products: ${response.productDetails.length}');
    print('🔍 Not found IDs: ${response.notFoundIDs}');
    
    if (response.notFoundIDs.isNotEmpty) {
      print('❌ Products not found: ${response.notFoundIDs}');
      print('❌ Requested product ID: $premiumProductId');
    }
    
    _products = response.productDetails;
    for (var product in _products) {
      print('✅ Product: ${product.id}, Title: ${product.title}, Price: ${product.price}');
    }
    
  } catch (e) {
    print('❌ Error loading products: $e');
  }
}
```

## 4️⃣ TestFlightデバッグ手順

### Xcode Console確認
1. Xcode → Window → Devices and Simulators
2. TestFlightデバイスを選択
3. 「Open Console」でリアルタイムログ確認
4. アプリで購入を試行
5. エラーログを確認

### よくあるエラーメッセージ

**❌ "Cannot connect to iTunes Store"**
```
原因: ネットワーク接続またはApple側の問題
解決: WiFi確認、時間をおいて再試行
```

**❌ "Product ID not found"**  
```
原因: App Store Connectで商品が未承認
解決: 商品を「準備完了」状態にする
```

**❌ "This In-App Purchase has already been bought"**
```
原因: TestFlightでは購入履歴がリセットされない場合がある
解決: 異なるApple IDでテスト
```

## 5️⃣ 段階的確認手順

### Step 1: 商品取得確認
```
アプリ起動 → premium機能画面
→ 商品が表示されるか？
→ 価格が表示されるか？
```

### Step 2: 購入ダイアログ確認  
```
購入ボタンタップ
→ App Store購入ダイアログが表示されるか？
→ 商品名・価格が正しいか？
```

### Step 3: 購入処理確認
```
「購入」ボタンタップ
→ Touch ID/Face ID認証
→ エラーメッセージまたは成功メッセージ
```

## 🆘 緊急チェックリスト

- [ ] App Store Connect商品が「準備完了」状態
- [ ] Bundle IDが完全一致
- [ ] 商品IDが完全一致  
- [ ] 価格設定が完了
- [ ] 日本地域で利用可能設定
- [ ] TestFlightビルドが最新
- [ ] デバッグログが出力される
- [ ] ネットワーク接続が正常

## 📱 代替テスト方法

### Sandboxテストに切り替え
TestFlightで問題が続く場合：
1. Xcodeから直接実機にインストール
2. Sandboxテストアカウントでテスト
3. 基本動作確認後、再度TestFlightテスト