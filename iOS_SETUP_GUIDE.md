# 🍎 iOS App Store配布設定ガイド

## 📋 必要事項

### **前提条件**
- ✅ macOS (Xcode実行環境)
- ✅ Xcode 16.4以降
- ❌ Apple Developer Program ($99/年) - **要登録**

### **現在の状況**
- ✅ Apple Development証明書: 利用可能
- ✅ Bundle ID: `com.daito.gymnastics_ai` 設定済み
- ❌ App Store Distribution証明書: 未作成
- ❌ プロビジョニングプロファイル: 未作成

---

## 🚀 セットアップ手順

### **Step 1: Apple Developer Program登録**
1. [Apple Developer Program](https://developer.apple.com/programs/) にアクセス
2. 個人または組織としてプログラムに参加
3. 年間 $99 の費用を支払い
4. 登録完了まで24-48時間待機

### **Step 2: Bundle ID登録**
1. [Apple Developer Portal](https://developer.apple.com/account/) にログイン
2. 「Certificates, Identifiers & Profiles」を選択
3. 「Identifiers」→「App IDs」を選択
4. 「+」ボタンをクリック
5. Bundle ID `com.daito.gymnastics_ai` を登録
6. 必要な機能を選択（In-App Purchase等）

### **Step 3: Distribution証明書作成**
1. Apple Developer Portal の「Certificates」を選択
2. 「+」ボタンをクリック
3. 「iOS Distribution (App Store and Ad Hoc)」を選択
4. CSR (Certificate Signing Request) をアップロード
5. 証明書をダウンロードしてKeychain Accessに追加

### **Step 4: プロビジョニングプロファイル作成**
1. Apple Developer Portal の「Profiles」を選択
2. 「+」ボタンをクリック
3. 「App Store」を選択
4. 作成したBundle IDを選択
5. Distribution証明書を選択
6. プロファイルをダウンロードしてXcodeに追加

---

## 🔧 Xcode設定

### **Step 1: 署名設定**
1. Xcodeで `ios/Runner.xcworkspace` を開く
2. プロジェクトナビゲーターでRunnerを選択
3. 「Signing & Capabilities」タブを開く
4. 「Automatically manage signing」のチェックを外す
5. 「Team」でApple Developer Teamを選択
6. 「Provisioning Profile」で作成したプロファイルを選択

### **Step 2: Archive作成**
```bash
# プロジェクトディレクトリで実行
flutter build ios --release
```

### **Step 3: Xcodeでアーカイブ**
1. Xcodeで「Product」→「Archive」を選択
2. アーカイブが成功したら「Distribute App」をクリック
3. 「App Store Connect」を選択
4. 「Upload」を選択
5. 証明書とプロファイルを確認
6. 「Upload」を実行

---

## 📱 App Store Connect設定

### **Step 1: アプリ作成**
1. [App Store Connect](https://appstoreconnect.apple.com/) にアクセス
2. 「My Apps」→「+」→「New App」を選択
3. 以下の情報を入力：
   - **App Name**: Gymnastics AI
   - **Primary Language**: Japanese
   - **Bundle ID**: com.daito.gymnastics_ai
   - **SKU**: gymnastics-ai-v1

### **Step 2: アプリ情報設定**
```
App Name: Gymnastics AI
Subtitle: 体操D-スコア計算・AIコーチング
Category: Sports
Secondary Category: Education

Description:
プロ体操選手・コーチのためのD-スコア計算アプリ。
1000以上の技データベース、AIコーチング機能、
演技構成分析で体操パフォーマンスを向上。
完全オフライン動作でプライバシーも安全。

Keywords:
体操,gymnastics,D-score,Dスコア,AI,コーチング,analysis,athlete,sports
```

### **Step 3: プライバシー設定**
```
データの使用:
- 体操技データ: ローカル保存のみ
- 演技構成: 端末内のみ
- 統計情報: 外部送信なし
- 位置情報: 使用しない
- 連絡先: 使用しない
```

### **Step 4: 価格設定**
- **価格**: 無料
- **国/地域**: 全世界
- **App Store配信**: 全年齢対象

---

## 🎯 審査申請

### **提出前チェックリスト**
- ✅ アプリビルドのアップロード完了
- ✅ アプリ情報の入力完了
- ✅ スクリーンショット (iPhone/iPad) 追加
- ✅ アプリプレビュー動画 (オプション)
- ✅ 年齢制限の設定
- ✅ 輸出コンプライアンス情報
- ✅ 広告識別子の使用情報

### **審査ガイドライン対応**
1. **機能完全性**: すべての機能が正常動作
2. **パフォーマンス**: クラッシュやフリーズなし
3. **デザイン**: Appleデザインガイドライン準拠
4. **安全性**: 個人情報の適切な取り扱い

---

## ⚠️ 既知の問題と対策

### **問題1: プロビジョニングプロファイルエラー**
```
Error: No profiles for 'com.daito.gymnastics_ai' were found
```
**対策**: Apple Developer Portalで正しいBundle IDとプロファイルを作成

### **問題2: Code Signing Identity**
```
Error: Code signing identity not found
```
**対策**: Keychain Accessで証明書を確認、必要に応じて再インストール

### **問題3: Archive失敗**
```
Error: Failed to code sign
```
**対策**: Xcode設定でManual Signingを使用、正しいプロファイルを選択

---

## 📋 完了チェックリスト

### **Developer Program**
- [ ] Apple Developer Program登録完了
- [ ] Bundle ID `com.daito.gymnastics_ai` 登録完了
- [ ] Distribution証明書作成完了
- [ ] プロビジョニングプロファイル作成完了

### **アプリビルド**
- [ ] Xcode署名設定完了
- [ ] Archive作成成功
- [ ] App Store Connect アップロード完了

### **App Store Connect**
- [ ] アプリ作成完了
- [ ] 基本情報入力完了
- [ ] スクリーンショット追加完了
- [ ] プライバシー設定完了
- [ ] 審査申請完了

---

## 🎉 審査完了後

### **承認時の対応**
1. **リリース**: 手動リリースまたは自動リリース設定
2. **告知**: ソーシャルメディア、ウェブサイト等での告知
3. **監視**: レビュー、クラッシュレポート、パフォーマンス監視

### **リジェクト時の対応**
1. **理由分析**: Apple Review Team からのフィードバック確認
2. **修正**: 指摘された問題点の修正
3. **再申請**: 修正版の再アップロードと審査申請

---

## 📞 サポート

### **問題発生時の連絡先**
- **Apple Developer Support**: https://developer.apple.com/support/
- **App Store Review**: https://developer.apple.com/app-store/review/
- **GitHub Issues**: https://github.com/daito-iwa/gym/issues

### **参考資料**
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Flutter iOS Deployment](https://flutter.dev/docs/deployment/ios)

---

**🚀 準備完了次第、iOS版もリリース可能です！**