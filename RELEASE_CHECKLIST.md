# Gymnastics AI v1.3.0 リリースチェックリスト

## 🔧 本番環境設定

### AdMob設定
**現在**: テスト用ID使用中
- [ ] Android AdMob App ID更新 (`android/app/src/main/AndroidManifest.xml`)
- [ ] iOS AdMob App ID更新 (`ios/Runner/Info.plist`)
- [ ] 広告ユニットID更新 (main.dart内)

### API設定
**現在**: ローカル開発サーバー使用中
- [ ] 本番APIサーバーURL設定 (`lib/config.dart`)
- [ ] HTTPS証明書確認
- [ ] APIキー・認証情報更新

### Firebase設定
- [ ] Firebase本番プロジェクト設定
- [ ] `google-services.json` (Android) 本番版更新
- [ ] `GoogleService-Info.plist` (iOS) 本番版更新

## 📱 アプリ設定

### iOS設定
- [ ] Bundle Identifier確認: `com.daito.gymnastics_ai`
- [ ] App Store Connect設定
- [ ] プッシュ通知証明書設定
- [ ] Face ID/Touch ID説明文確認済み ✅

### Android設定
- [ ] Package Name確認: `com.daito.gymnastics_ai`
- [ ] Google Play Console設定
- [ ] minSdkVersion 23確認済み ✅
- [ ] 権限設定確認済み ✅

## 🔐 セキュリティ

### コード署名
- [ ] iOS証明書・プロビジョニングプロファイル
- [ ] Android署名キーストア
- [ ] 署名設定確認

### 機密情報
- [ ] APIキー・トークン確認
- [ ] デバッグ情報削除確認
- [ ] プロダクションフラグ設定確認済み ✅

## 🚀 ビルド・テスト

### 最終ビルド
- [x] Android APK生成成功 (111MB) ✅
- [ ] iOS Archive作成・テスト
- [ ] 本番設定でのビルドテスト

### 機能テスト
- [ ] 課金機能テスト (IAP)
- [ ] AdMob広告表示テスト
- [ ] 生体認証テスト
- [ ] プッシュ通知テスト
- [ ] ソーシャルログインテスト

## 📋 ストア申請準備

### 必要素材
- [ ] アプリアイコン (各サイズ)
- [ ] スクリーンショット (iPhone/Android)
- [ ] アプリ説明文 (日本語/英語)
- [ ] プライバシーポリシーURL
- [ ] サポートURL

### メタデータ
- [ ] アプリ名: "Gymnastics AI"
- [ ] バージョン: 1.3.0 (Build 4)
- [ ] カテゴリ: Sports/Health & Fitness
- [ ] 対象年齢: 4+

## ✅ 完了済み項目

### 技術基盤
- [x] Firebase統合 (Analytics + Messaging)
- [x] 生体認証 (TouchID/FaceID)
- [x] Google Sign-In + Apple Sign-In
- [x] 課金システム (IAP + Receipt Validation)
- [x] AdMob統合
- [x] 依存関係更新
- [x] 構文エラー修正
- [x] Android SDK licenses

---

## 🎯 次のアクション

1. **AdMob本番ID取得・設定**
2. **本番APIサーバー準備**
3. **Firebase本番プロジェクト設定**
4. **iOS証明書・署名設定**
5. **最終本番ビルドテスト**

> **⚠️ 重要**: テスト用設定から本番設定への切り替えが必要です