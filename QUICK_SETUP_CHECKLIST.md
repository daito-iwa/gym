# ⚡ サブスクリプション設定 クイックチェックリスト

## 🎯 今すぐ実行すべき作業

### 1. Apple Developer Console（最重要）
```
🌐 https://developer.apple.com/account/resources/identifiers/list/merchant
```
**作業**: Merchant ID作成
- Description: `Gymnastics AI Payments`
- Identifier: `merchant.com.daito.gymnasticsai`

### 2. App Store Connect（最重要）
```
🌐 https://appstoreconnect.apple.com/apps
```
**作業**: サブスクリプション商品作成
- 商品ID: `premium_monthly_subscription`
- 価格: ¥500

### 3. Provisioning Profile再作成
```
🌐 https://developer.apple.com/account/resources/profiles/list
```
**作業**: 既存プロファイル削除→新規作成

---

## ✅ 既に完了済み設定

- ✅ **Bundle ID統一**: `com.daito.gymnasticsai`
- ✅ **Entitlements設定**: In-App Purchase権限追加
- ✅ **Android BILLING権限**: 追加完了
- ✅ **商品ID統一**: `premium_monthly_subscription`
- ✅ **購入メソッド修正**: `buyNonConsumable`使用
- ✅ **サーバー検証ロジック**: 更新完了

---

## 🔴 現在のエラー原因

**スクリーンショットのエラー**:
```
❌ Communication with Apple failed
❌ Merchant ID not found
❌ Provisioning profile issues
```

**解決方法**: 上記3つの作業を順番に実行

---

## 📱 設定完了後のテスト手順

1. **Xcode Clean Build** (⌘+Shift+K)
2. **実機インストール**
3. **Sandboxテスト**実行
4. **購入フロー**確認

---

## 🚨 緊急度順

1. **🔥 超緊急**: Merchant ID作成
2. **🔥 超緊急**: App Store Connect商品作成  
3. **⚡ 緊急**: Provisioning Profile再作成
4. **📱 重要**: 実機テスト

---

*このチェックリストに従って作業を進めてください。各作業完了後、次のステップに進んでください。*