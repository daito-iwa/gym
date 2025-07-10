# 認証システム技術仕様書

## 📋 **システム概要**

このプロジェクトは、Gym D-scoreアプリケーションの認証システムです。JWT（JSON Web Token）を使用したセキュアな認証機能を提供します。

## 🏗️ **アーキテクチャ**

### バックエンド (FastAPI)
- **認証方式**: JWT Bearer Token
- **パスワード管理**: Bcrypt ハッシュ化
- **トークン有効期限**: 30分（設定可能）
- **セッション管理**: インメモリ（開発用）

### フロントエンド (Flutter)
- **認証状態管理**: StatefulWidget
- **セキュアストレージ**: flutter_secure_storage
- **自動ログイン**: トークン自動検証
- **UI/UX**: Material Design 3 ダークテーマ

## 🔐 **セキュリティ機能**

### 1. パスワード保護
- **ハッシュ化**: Bcrypt アルゴリズム
- **最小要件**: 7文字以上
- **ソルト**: 自動生成

### 2. JWT トークン
- **署名アルゴリズム**: HS256
- **有効期限**: 30分
- **シークレットキー**: 環境変数管理

### 3. 入力検証
- **ユーザー名**: 4文字以上
- **メール**: 正規表現検証
- **パスワード**: 最小7文字
- **フィールド**: 必須項目チェック

## 🚀 **API エンドポイント**

### 認証関連

#### POST /signup
ユーザー新規登録

**Request Body:**
```json
{
  "username": "string",
  "password": "string",
  "email": "string",
  "full_name": "string"
}
```

**Response:**
```json
{
  "username": "string",
  "email": "string",
  "full_name": "string",
  "disabled": false
}
```

#### POST /token
ユーザーログイン

**Request Body (form-data):**
```
username: string
password: string
```

**Response:**
```json
{
  "access_token": "string",
  "token_type": "bearer"
}
```

#### GET /users/me
現在のユーザー情報取得

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response:**
```json
{
  "username": "string",
  "email": "string",
  "full_name": "string",
  "disabled": false
}
```

### 保護されたエンドポイント

#### POST /chat
AIチャット機能（認証必須）

**Headers:**
```
Authorization: Bearer {access_token}
Content-Type: application/json
```

**Request Body:**
```json
{
  "session_id": "string",
  "question": "string",
  "lang": "ja|en"
}
```

## 📱 **Flutter 認証フロー**

### 1. アプリ起動時
```dart
void initState() {
  super.initState();
  _tryAutoLogin(); // 自動ログイン試行
}
```

### 2. 自動ログイン処理
```dart
void _tryAutoLogin() async {
  final token = await _storage.read(key: 'auth_token');
  if (token != null) {
    // トークン有効性確認
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
      // ログイン成功
      setState(() {
        _isAuthenticated = true;
      });
    }
  }
}
```

### 3. 認証状態による画面分岐
```dart
Widget build(BuildContext context) {
  if (_isAuthLoading) {
    return const CircularProgressIndicator();
  }
  
  if (!_isAuthenticated) {
    return AuthScreen(
      onSubmit: _submitAuthForm,
      isLoading: _isLoading,
    );
  }
  
  return MainApplicationScreen();
}
```

## 🎨 **UI/UX 設計**

### 認証画面の特徴
- **ダークテーマ**: Material Design 3 準拠
- **入力検証**: リアルタイム バリデーション
- **ローディング状態**: CircularProgressIndicator
- **エラー表示**: AlertDialog
- **フォーム切り替え**: ログイン ⇄ サインアップ

### 主要コンポーネント
```dart
class AuthScreen extends StatefulWidget {
  final Function(String, String, String?, String?, bool) onSubmit;
  final bool isLoading;
  
  // UI implementation...
}
```

## 🧪 **テスト戦略**

### バックエンドテスト (`test_auth.py`)
- **ユニットテスト**: 個別機能テスト
- **統合テスト**: 認証フローテスト
- **セキュリティテスト**: 認証回避テスト
- **エラーハンドリングテスト**: 異常系テスト

### フロントエンドテスト (`test/auth_test.dart`)
- **ウィジェットテスト**: UI コンポーネントテスト
- **バリデーションテスト**: 入力検証テスト
- **インタラクションテスト**: ユーザー操作テスト
- **状態管理テスト**: 認証状態テスト

## 🔧 **設定管理**

### 環境変数
```bash
# 本番環境で必須
export SECRET_KEY="your-secret-key-here"
export ACCESS_TOKEN_EXPIRE_MINUTES="30"
```

### 設定ファイル (`lib/config.dart`)
```dart
class AppConfig {
  static String get apiBaseUrl => isProduction ? productionUrl : baseUrl;
  static bool get isProduction => false; // 本番時はtrue
}
```

## 🚨 **エラーハンドリング**

### 認証エラー
- **401 Unauthorized**: 認証情報無効
- **400 Bad Request**: 重複ユーザー名
- **422 Validation Error**: 入力形式エラー

### ネットワークエラー
- **接続エラー**: ネットワーク接続確認メッセージ
- **タイムアウト**: 再試行メッセージ
- **サーバーエラー**: 一般的なエラーメッセージ

## 📊 **パフォーマンス考慮事項**

### セキュリティ vs パフォーマンス
- **トークン有効期限**: 30分（セキュリティ重視）
- **自動ログイン**: 起動時のみ実行
- **パスワードハッシュ**: 適切なラウンド数

### メモリ管理
- **インメモリDB**: 開発用（本番は外部DB推奨）
- **トークンキャッシュ**: SecureStorage使用
- **状態管理**: StatefulWidget最小化

## 🔮 **今後の拡張性**

### データベース移行
```python
# 現在: インメモリ
fake_users_db: Dict[str, Dict[str, Any]] = {}

# 将来: 外部データベース
# SQLAlchemy, PostgreSQL, MongoDB等
```

### 追加認証機能
- **OAuth2**: Google, Apple Sign-in
- **2FA**: 二要素認証
- **パスワードリセット**: メール認証
- **ソーシャルログイン**: SNS連携

### スケーラビリティ
- **Redis**: セッション管理
- **Load Balancer**: 複数サーバー対応
- **CDN**: 静的ファイル配信
- **Monitoring**: 認証ログ収集

## 📋 **デプロイメント**

### 本番環境設定
1. **環境変数設定**
2. **HTTPS化**
3. **データベース設定**
4. **バックアップ設定**
5. **監視設定**

### セキュリティチェックリスト
- [ ] シークレットキーの安全な管理
- [ ] HTTPS通信の強制
- [ ] 入力検証の実装
- [ ] レート制限の設定
- [ ] ログ監視の設定

---

**📄 このドキュメントは、認証システムの理解と保守を目的としています。**