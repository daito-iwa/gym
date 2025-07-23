# 🚀 Gymnastics AI - 本番環境セットアップガイド

## 📋 必要な準備

### 1. Firebase設定
1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成
2. 以下のファイルをダウンロード：
   - **Android**: `google-services.json` → `android/app/` に配置
   - **iOS**: `GoogleService-Info.plist` → `ios/Runner/` に配置（Xcodeで追加）

### 2. 環境変数設定（.env）
`.env`ファイルの以下の値を実際の値に変更：

```env
# OpenAI API
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxx

# サーバーURL
API_BASE_URL=https://api.your-domain.com

# Google Sign-In
GOOGLE_CLIENT_ID=xxxxxxxxxxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=xxxxxxxxxxxxx.apps.googleusercontent.com

# AdMob（本番用ID）
ADMOB_APP_ID_ANDROID=ca-app-pub-xxxxxxxxxxxxx~xxxxxxxxxx
ADMOB_APP_ID_IOS=ca-app-pub-xxxxxxxxxxxxx~xxxxxxxxxx
ADMOB_BANNER_ANDROID=ca-app-pub-xxxxxxxxxxxxx/xxxxxxxxxx
ADMOB_BANNER_IOS=ca-app-pub-xxxxxxxxxxxxx/xxxxxxxxxx

# Stripe
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxx
```

### 3. コード内の設定更新

#### config.dart
```dart
Environment.production: 'https://api.your-actual-domain.com', // 実際のURLに変更
```

#### social_auth_manager.dart
```dart
static const String _googleClientId = 'YOUR_ACTUAL_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
static const String _iosGoogleClientId = 'YOUR_ACTUAL_IOS_GOOGLE_CLIENT_ID.apps.googleusercontent.com';
```

#### admob_config.dart
```dart
// 本番用広告IDを設定
static const String productionBannerAdUnitIdAndroid = 'ca-app-pub-xxxxxxxxxxxxx/xxxxxxxxxx';
static const String productionBannerAdUnitIdIOS = 'ca-app-pub-xxxxxxxxxxxxx/xxxxxxxxxx';
// ... 他の広告IDも同様に設定
```

### 4. バックエンドAPI要件

以下のエンドポイントを実装する必要があります：

#### 認証
- `POST /auth/login` - ユーザーログイン
- `POST /auth/register` - ユーザー登録  
- `POST /auth/social` - ソーシャル認証
- `POST /auth/refresh` - トークンリフレッシュ
- `POST /auth/logout` - ログアウト

#### ユーザー管理
- `GET /user/profile` - プロフィール取得
- `PUT /user/profile` - プロフィール更新
- `GET /user/subscription` - サブスクリプション情報

#### AIチャット
- `POST /chat/message` - メッセージ送信
- `GET /chat/history` - チャット履歴取得

#### 課金
- `POST /subscription/create` - サブスクリプション作成
- `POST /subscription/cancel` - サブスクリプションキャンセル
- `POST /webhook/stripe` - Stripe Webhook

### 5. プラットフォーム別設定

#### iOS
1. Xcodeでプロジェクトを開く
2. Signing & Capabilities で Team を設定
3. Bundle Identifier を確認
4. Info.plistに必要な権限を追加

#### Android
1. `android/app/build.gradle` でapplicationIdを確認
2. 署名設定を追加
3. ProGuardルールを設定（必要に応じて）

### 6. ビルドコマンド

#### Web
```bash
flutter build web --release
```

#### iOS
```bash
flutter build ios --release
```

#### Android
```bash
flutter build appbundle --release
```

## 🔒 セキュリティチェックリスト

- [ ] APIキーが本番用に設定されている
- [ ] デバッグログが無効化されている
- [ ] HTTPSが使用されている
- [ ] 適切なCORS設定
- [ ] APIレート制限の実装
- [ ] エラーハンドリングの確認

## 📱 テスト項目

- [ ] 新規ユーザー登録
- [ ] ログイン/ログアウト
- [ ] ソーシャル認証（Google/Apple）
- [ ] 無料ユーザーの制限確認
- [ ] プレミアムアップグレード
- [ ] AIチャット機能
- [ ] 課金フロー
- [ ] 広告表示（無料ユーザー）

## 🚨 トラブルシューティング

### Firebase初期化エラー
- `google-services.json`/`GoogleService-Info.plist`が正しく配置されているか確認
- Firebase Consoleでアプリが登録されているか確認

### ソーシャル認証エラー
- OAuth同意画面が設定されているか確認
- リダイレクトURIが正しく設定されているか確認

### 課金エラー
- Stripeのwebhookエンドポイントが正しく設定されているか確認
- 商品IDが一致しているか確認

## 📞 サポート

問題が発生した場合は、以下を確認してください：
1. エラーログ（Consoleまたはログファイル）
2. ネットワークタブでのAPIレスポンス
3. プラットフォーム固有のログ（Xcode/Android Studio）