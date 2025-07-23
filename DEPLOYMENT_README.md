# Gymnastics AI デプロイメントガイド

## 🚀 フロントエンド（Flutter Web）デプロイ

### Netlify を使用したデプロイ手順

1. **Netlifyアカウント作成/ログイン**
   - https://netlify.com でアカウント作成

2. **手動デプロイ（推奨）**
   ```bash
   # プロジェクトルートで実行
   flutter build web --release
   cd build/web
   zip -r ../web-build.zip .
   ```
   - Netlify Dashboard で `Sites` → `Add new site` → `Deploy manually`
   - `web-build.zip` をドラッグ&ドロップ

3. **Git連携デプロイ**
   - Netlify Dashboard で `Sites` → `Add new site` → `Import from Git`
   - GitHubリポジトリを選択
   - Build settings:
     - Build command: `flutter build web --release`
     - Publish directory: `build/web`

4. **カスタムドメイン設定（オプション）**
   - Site settings → Domain management → Custom domains

### 環境変数設定

Netlify Dashboard → Site settings → Environment variables:

```
FLUTTER_WEB=true
```

## 🔧 バックエンド（FastAPI）デプロイ

### Google Cloud Run を使用したデプロイ手順

1. **Google Cloud SDK セットアップ**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Docker イメージビルド**
   ```bash
   docker build -t gymnastics-ai-api .
   ```

3. **Cloud Run デプロイ**
   ```bash
   gcloud run deploy gymnastics-ai-api \
     --source . \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated
   ```

### 必要な環境変数

```
OPENAI_API_KEY=your-openai-api-key
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
```

## 📋 デプロイ後チェックリスト

- [ ] フロントエンドが正常に表示される
- [ ] APIエンドポイントが応答する
- [ ] AIチャット機能が動作する
- [ ] 認証機能が正常に動作する
- [ ] SSL証明書が適用されている
- [ ] SEOメタタグが設定されている

## 🌐 アクセスURL

- **本番サイト**: https://gymnastics-ai.netlify.app
- **API エンドポイント**: https://gymnastics-ai-api-123456789.us-central1.run.app

## 📞 サポート

デプロイに関する問題は Issue を作成してください。