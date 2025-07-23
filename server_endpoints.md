# Gymnastics AI サーバーAPIエンドポイント仕様

## ベースURL
- 本番環境: `https://api.gymnastics-ai.com`
- 開発環境: `http://localhost:8000`

## 認証エンドポイント

### 1. ユーザー登録
```
POST /signup
Content-Type: application/json

リクエストボディ:
{
  "username": "string",
  "password": "string", 
  "email": "string",
  "full_name": "string"
}

レスポンス:
{
  "access_token": "jwt_token",
  "user": {
    "id": "user_id",
    "username": "string",
    "email": "string",
    "subscription_tier": "free|premium",
    "subscription_start": "2024-01-01T00:00:00Z",
    "subscription_end": "2024-12-31T23:59:59Z"
  }
}
```

### 2. ログイン
```
POST /login
Content-Type: application/json

リクエストボディ:
{
  "username": "string",
  "password": "string"
}

レスポンス: 上記と同じ
```

### 3. ユーザー情報取得
```
GET /users/me
Authorization: Bearer {jwt_token}

レスポンス:
{
  "id": "user_id",
  "username": "string", 
  "email": "string",
  "subscription_tier": "free|premium",
  "subscription_start": "2024-01-01T00:00:00Z",
  "subscription_end": "2024-12-31T23:59:59Z"
}
```

## 課金・サブスクリプション

### 4. 購入検証
```
POST /purchase/verify
Authorization: Bearer {jwt_token}
Content-Type: application/json

リクエストボディ:
{
  "platform": "ios|android",
  "receipt_data": "base64_receipt_data",
  "transaction_id": "string",
  "product_id": "com.daito.gym.premium_monthly_subscription",
  "purchase_token": "string" // Androidのみ
}

レスポンス:
{
  "success": true|false,
  "message": "string",
  "subscription": {
    "tier": "premium",
    "start_date": "2024-01-01T00:00:00Z",
    "end_date": "2024-12-31T23:59:59Z"
  }
}
```

### 5. サブスクリプション状態同期
```
POST /subscription/sync
Authorization: Bearer {jwt_token}

レスポンス:
{
  "subscription_tier": "free|premium",
  "subscription_start": "2024-01-01T00:00:00Z", 
  "subscription_end": "2024-12-31T23:59:59Z",
  "is_active": true|false
}
```

## AIチャット機能

### 6. チャットメッセージ送信
```
POST /chat/message
Authorization: Bearer {jwt_token}
Content-Type: application/json

リクエストボディ:
{
  "message": "体操の技について教えて",
  "conversation_id": "optional_conversation_id",
  "context": {
    "apparatus": "FX|PH|SR|VT|PB|HB",
    "skill_level": "beginner|intermediate|advanced"
  }
}

レスポンス:
{
  "response": "AIの回答テキスト",
  "conversation_id": "conversation_id",
  "usage_count": 10,
  "remaining_count": 90 // 無料ユーザーの場合
}
```

### 7. 会話履歴取得
```
GET /chat/conversations
Authorization: Bearer {jwt_token}

レスポンス:
{
  "conversations": [
    {
      "id": "conversation_id",
      "title": "会話のタイトル",
      "created_at": "2024-01-01T00:00:00Z",
      "last_message_at": "2024-01-01T12:00:00Z"
    }
  ]
}
```

## データ管理

### 8. 演技構成保存
```
POST /routines
Authorization: Bearer {jwt_token}
Content-Type: application/json

リクエストボディ:
{
  "name": "演技構成名",
  "apparatus": "FX",
  "skills": [
    {
      "id": "skill_id",
      "name": "技名",
      "value": 0.5,
      "group": 1
    }
  ],
  "connection_groups": [[0, 1], [2, 3]]
}

レスポンス:
{
  "id": "routine_id",
  "name": "演技構成名",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 9. 演技構成一覧取得
```
GET /routines
Authorization: Bearer {jwt_token}

レスポンス:
{
  "routines": [
    {
      "id": "routine_id",
      "name": "演技構成名",
      "apparatus": "FX",
      "created_at": "2024-01-01T00:00:00Z",
      "d_score": 6.5
    }
  ]
}
```

## エラーレスポンス形式

```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "認証トークンが無効です",
    "details": "追加の詳細情報"
  }
}
```

## HTTPステータスコード

- 200: 成功
- 201: 作成成功
- 400: リクエストエラー
- 401: 認証エラー
- 403: 権限エラー
- 404: リソースが見つからない
- 429: レート制限超過
- 500: サーバーエラー

## 認証方式

- JWT (JSON Web Token) を使用
- アクセストークンの有効期限: 24時間
- リフレッシュトークンの有効期限: 30日間
- Authorization ヘッダーに `Bearer {token}` 形式で送信

## レート制限

- 無料ユーザー: 
  - AIチャット: 100回/日
  - API呼び出し: 1000回/日
- プレミアムユーザー:
  - AIチャット: 無制限
  - API呼び出し: 10000回/日