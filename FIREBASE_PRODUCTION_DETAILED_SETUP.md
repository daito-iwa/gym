# 🔥 Firebase本番プロジェクト詳細設定ガイド

## 🚀 Step 1: プロジェクト作成

### Firebase Console
1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. 「プロジェクトを追加」をクリック

### プロジェクト設定
```yaml
ステップ1 - プロジェクト作成:
プロジェクト名: Gym AI Production
プロジェクトID: gym-ai-prod-2025

ステップ2 - Google Analytics:
Google Analytics: 有効
アカウント: デフォルト または 新規作成

ステップ3 - 地域設定:
デフォルトのGCP リソース ロケーション: asia-northeast1 (東京)
```

## 📱 Step 2: iOS アプリ追加

### iOS アプリ登録
```yaml
Apple Bundle ID: com.daito.gymnasticsai
アプリのニックネーム: Gym AI iOS
App Store ID: (後で追加)
```

### 設定ファイルのダウンロード
1. `GoogleService-Info.plist` をダウンロード
2. Xcode プロジェクトの `ios/Runner/` フォルダに配置
3. Xcode で Runner ターゲットに追加

### iOS 設定確認
```yaml
必要なファイル配置:
✓ ios/Runner/GoogleService-Info.plist
✓ Bundle ID が一致している
✓ Development Team が設定されている
```

## 🤖 Step 3: Android アプリ追加

### Android アプリ登録
```yaml
Android パッケージ名: com.daito.gymnasticsai
アプリのニックネーム: Gym AI Android
デバッグ用 SHA-1 証明書フィンガープリント: (開発時は空白でOK)
```

### 設定ファイルのダウンロード
1. `google-services.json` をダウンロード
2. Android プロジェクトの `android/app/` フォルダに配置
3. gradle 設定が正しいことを確認

### Android 設定確認
```yaml
必要なファイル配置:
✓ android/app/google-services.json
✓ パッケージ名が一致している
✓ gradle 設定が正しい
```

## 🌐 Step 4: Web アプリ追加

### Web アプリ登録
```yaml
アプリのニックネーム: Gym AI Web
Firebase Hosting: 有効
```

### Web 設定
```javascript
// Firebase Web設定 (自動生成)
const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "gym-ai-prod-2025.firebaseapp.com",
  projectId: "gym-ai-prod-2025",
  storageBucket: "gym-ai-prod-2025.appspot.com",
  messagingSenderId: "123456789",
  appId: "your-app-id",
  measurementId: "G-XXXXXXXXXX"
};
```

## 🔐 Step 5: Authentication 設定

### ログイン方法の有効化
1. Authentication → ログイン方法タブ

### 有効化する認証方法
```yaml
メール/パスワード: 有効
- メールアドレス/パスワード: 有効
- メールリンク（パスワードなしログイン）: 無効

Google: 有効
- プロジェクト サポートメール: your-email@gmail.com
- Web SDK設定: 自動設定

Apple: 有効 (iOS のみ)
- Service ID: com.daito.gymnasticsai.signin
- OAuth リダイレクト URL: 自動設定
```

### 承認済みドメイン
```yaml
承認済みドメイン:
- localhost (開発用)
- gym-ai-prod-2025.web.app (Firebase Hosting)
- your-custom-domain.com (カスタムドメイン)
```

## 💾 Step 6: Cloud Firestore 設定

### データベース作成
1. Firestore Database → データベースの作成
2. セキュリティルール: 本番モードで開始
3. ロケーション: asia-northeast1 (東京)

### コレクション構造設計
```yaml
users/
  {userId}
    - email: string
    - displayName: string
    - photoURL: string
    - subscription_tier: string (free/premium)
    - created_at: timestamp
    - last_login: timestamp

routines/
  {routineId}
    - userId: string
    - apparatus: string (fx/ph/sr/vt/pb/hb)
    - skills: array
    - d_score: number
    - created_at: timestamp
    - updated_at: timestamp

chat_sessions/
  {sessionId}
    - userId: string
    - messages: array
      - role: string (user/assistant)
      - content: string
      - timestamp: timestamp
    - created_at: timestamp

analytics_events/
  {eventId}
    - userId: string
    - event_name: string
    - event_params: object
    - timestamp: timestamp
```

### セキュリティルール
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザー情報は本人のみアクセス
    match /users/{userId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    
    // ルーチンデータは作成者のみアクセス
    match /routines/{routineId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId;
    }
    
    // チャットセッションは本人のみアクセス
    match /chat_sessions/{sessionId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null 
        && request.auth.uid == request.resource.data.userId;
    }
    
    // 分析イベントは作成のみ（管理者は全読み取り可能）
    match /analytics_events/{eventId} {
      allow create: if request.auth != null;
      allow read: if request.auth != null 
        && request.auth.token.admin == true;
    }
  }
}
```

### Firestoreインデックス
```yaml
複合インデックス:
1. routines コレクション
   - userId (昇順) + created_at (降順)
   - apparatus (昇順) + created_at (降順)

2. chat_sessions コレクション  
   - userId (昇順) + created_at (降順)

3. analytics_events コレクション
   - userId (昇順) + timestamp (降順)
   - event_name (昇順) + timestamp (降順)
```

## 🏠 Step 7: Firebase Hosting 設定

### Hosting 初期化
```bash
# Firebase CLI インストール
npm install -g firebase-tools

# ログイン
firebase login

# プロジェクト初期化  
firebase init hosting
```

### firebase.json設定
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)",
        "headers": [
          {
            "key": "Cache-Control", 
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "**",
        "headers": [
          {
            "key": "X-Frame-Options",
            "value": "DENY"
          },
          {
            "key": "X-Content-Type-Options",
            "value": "nosniff"
          }
        ]
      }
    ]
  }
}
```

## 📊 Step 8: Analytics & Performance 設定

### Google Analytics設定
```yaml
アナリティクス設定:
- 自動収集イベント: 有効
- 拡張測定機能: 有効
- Google 広告リンク: 無効

カスタムイベント定義:
- d_score_calculation
- ai_chat_message  
- skill_search
- premium_upgrade
- routine_save
```

### Performance Monitoring
```yaml
有効化する監視:
- Web パフォーマンス: 有効
- アプリ起動時間: 有効
- HTTP/S ネットワーク リクエスト: 有効
- カスタム パフォーマンス トレース: 有効
```

## 🔔 Step 9: Cloud Messaging 設定

### FCM設定（プッシュ通知）
```yaml
Cloud Messaging:
- APNs 証明書: iOS用にアップロード
- サーバーキー: バックエンド用に取得

通知タイプ設計:
- ウェルカム通知（新規登録）
- 週間利用レポート
- 新機能のお知らせ
- プレミアム期限切れ警告
```

## 💰 Step 10: 課金・サブスクリプション連携

### Stripe連携準備
```yaml
必要な設定:
- Stripe アカウント作成
- Webhook エンドポイント設定
- 商品・価格設定
- 顧客情報の Firestore 同期
```

### Firebase Functions (サーバーレス)
```javascript
// 課金処理用 Cloud Function例
exports.handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  // Stripe webhookの処理
  // ユーザーのサブスクリプション状態をFirestoreに更新
});

exports.verifyPremiumAccess = functions.https.onCall(async (data, context) => {
  // プレミアム機能のアクセス権チェック
});
```

## 🔒 Step 11: セキュリティ設定

### App Check設定
```yaml
App Check (DDoS・不正利用対策):
- iOS: Device Check
- Android: Play Integrity
- Web: reCAPTCHA v3
```

### セキュリティルール強化
```yaml
追加セキュリティ:
- Storage セキュリティルール
- Functions セキュリティルール  
- Rate Limiting設定
- IP制限（必要に応じて）
```

## ✅ 設定完了チェックリスト

### プロジェクト基盤
- [ ] Firebase プロジェクト作成完了
- [ ] iOS/Android/Web アプリ追加完了
- [ ] 設定ファイルダウンロード・配置完了

### 主要機能
- [ ] Authentication 設定完了
- [ ] Firestore データベース・ルール設定完了  
- [ ] Hosting 設定完了
- [ ] Analytics・Performance 設定完了

### セキュリティ・運用
- [ ] セキュリティルール設定完了
- [ ] App Check 設定完了
- [ ] Cloud Messaging 設定完了
- [ ] 監視・アラート設定完了

---

**次のステップ: スクリーンショット撮影とビルド問題解決** 📸