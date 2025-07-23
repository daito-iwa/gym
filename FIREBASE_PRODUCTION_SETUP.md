# 🔥 Firebase本番設定ガイド

## 📋 Firebase Console設定手順

### 1. プロジェクト作成
1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを追加」クリック
3. プロジェクト設定:
   ```yaml
   プロジェクト名: gymnastics-ai-production
   プロジェクトID: gymnastics-ai-prod
   Analytics: 有効
   地域: asia-northeast1 (東京)
   ```

### 2. アプリ登録

#### iOS アプリ
```yaml
Bundle ID: com.daito.gymnasticsai
アプリ名: Gymnastics AI
Team ID: 3TDG65K4J5
```
**ダウンロード必要ファイル:**
- `GoogleService-Info.plist` → `ios/Runner/`に配置

#### Android アプリ  
```yaml
パッケージ名: com.daito.gymnasticsai
アプリ名: Gymnastics AI
SHA-1署名: (キーストアから生成)
```
**ダウンロード必要ファイル:**
- `google-services.json` → `android/app/`に配置

#### Web アプリ
```yaml
アプリ名: Gymnastics AI Web
ドメイン: your-domain.com
```

### 3. Firebase Analytics設定

#### 有効化するイベント
```yaml
カスタムイベント:
- d_score_calculation (種目別計算回数)
- ai_chat_message (AI会話回数)  
- skill_search (技検索回数)
- premium_upgrade (プレミアム登録)

コンバージョン目標:
- premium_subscription_start
- routine_completion
- daily_active_usage
```

#### プライバシー設定
```yaml
データ共有: 最小限に設定
IP匿名化: 有効
広告ID使用: 無効 (プライバシー重視)
データ保持期間: 14ヶ月
```

### 4. Firebase Authentication設定

#### 認証方法有効化
- [x] メール/パスワード
- [x] Google
- [x] Apple
- [ ] Facebook (無効)
- [ ] Twitter (無効)

#### Google認証設定
```yaml
iOS Client ID: (Google Cloud Consoleから取得)
Android Client ID: (Google Cloud Consoleから取得)  
Web Client ID: (Google Cloud Consoleから取得)
```

#### Apple認証設定
```yaml
Service ID: com.daito.gymnasticsai.signin
Team ID: 3TDG65K4J5
Key ID: (Apple Developer Consoleから取得)
Private Key: (Apple Developer Consoleから取得)
```

### 5. Cloud Firestore設定

#### データベース構造
```yaml
コレクション設計:
users/
  - userId (string)
  - email (string)
  - subscription_tier (string: free/premium)
  - created_at (timestamp)
  - last_active (timestamp)

routines/
  - routineId (string)
  - userId (string)
  - apparatus (string)
  - skills (array)
  - d_score (number)
  - created_at (timestamp)

chat_sessions/
  - sessionId (string)
  - userId (string)  
  - messages (array)
  - created_at (timestamp)
```

#### セキュリティルール
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // ユーザードキュメントは本人のみ
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ルーチンは本人のみ
    match /routines/{routineId} {
      allow read, write: if request.auth != null 
        && resource.data.userId == request.auth.uid;
    }
    
    // チャットセッションは本人のみ
    match /chat_sessions/{sessionId} {
      allow read, write: if request.auth != null
        && resource.data.userId == request.auth.uid;
    }
  }
}
```

### 6. Cloud Functions設定

#### 必要な関数
```yaml
functions/
  - onUserCreate: 新規ユーザー初期化
  - onPremiumUpgrade: プレミアム登録処理
  - scheduledDataCleanup: 古いデータ削除
  - stripeWebhook: Stripe決済処理
```

### 7. Firebase Hosting設定 (Web版)

```yaml
ホスティング設定:
サイト名: gymnastics-ai-web
カスタムドメイン: app.your-domain.com
SSL証明書: 自動発行
```

#### firebase.jsonファイル作成
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
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions"
  }
}
```

## 🔐 セキュリティ設定

### API Key制限
```yaml
Firebase Web API Key制限:
- HTTPリファラー: your-domain.com/*
- IP制限: なし (モバイルアプリ対応)

Google Cloud API制限:
- Android: パッケージ名とSHA-1
- iOS: Bundle IDとTeam ID
```

### 環境変数設定
```bash
# Functions環境変数
firebase functions:config:set \
  openai.api_key="your-openai-key" \
  stripe.secret_key="your-stripe-secret" \
  app.environment="production"
```

## 📊 監視・分析設定

### Performance Monitoring
- [x] Web Vitals追跡
- [x] アプリ起動時間
- [x] API応答時間
- [x] クラッシュ追跡

### Crashlytics設定
- [x] iOS自動レポート
- [x] Android自動レポート  
- [x] カスタムキー設定
- [x] ユーザー識別

## 🚀 デプロイ手順

### 1. 設定ファイル配置
```bash
# iOS
cp GoogleService-Info.plist ios/Runner/

# Android  
cp google-services.json android/app/

# Web (Firebase SDK初期化)
# main.dartで自動的に設定される
```

### 2. Firebase CLI初期化
```bash
# Firebase CLIインストール
npm install -g firebase-tools

# ログイン
firebase login

# プロジェクト初期化
firebase init

# 選択項目:
# ✓ Firestore
# ✓ Functions  
# ✓ Hosting
# ✓ Analytics
```

### 3. 本番デプロイ
```bash
# Webアプリビルド
flutter build web --release

# Firebaseデプロイ
firebase deploy

# 個別デプロイも可能
firebase deploy --only hosting
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## ✅ 設定完了チェックリスト

### Firebase Console
- [ ] プロジェクト作成完了
- [ ] iOS/Android/Webアプリ登録完了
- [ ] 認証方法設定完了
- [ ] Firestore設定完了
- [ ] Analytics設定完了

### 設定ファイル
- [ ] GoogleService-Info.plist配置
- [ ] google-services.json配置  
- [ ] firebase.json作成
- [ ] セキュリティルール設定

### 本番環境
- [ ] Firebase Hosting設定
- [ ] カスタムドメイン設定
- [ ] SSL証明書設定
- [ ] Performance Monitoring有効化

---

**次のステップ: 本番サーバーデプロイ設定**