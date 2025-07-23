# 🚀 Google Cloud Run デプロイガイド

## 📋 必要なもの
1. **Googleアカウント**
2. **クレジットカード**（登録必要だが無料枠で運用可能）
3. **Google Cloud CLI (gcloud)**

## 🔧 初期設定

### 1. Google Cloud プロジェクトの作成
1. [Google Cloud Console](https://console.cloud.google.com)にアクセス
2. 新しいプロジェクトを作成
   - プロジェクト名: `Gymnastics AI App`
   - プロジェクトID: `gymnastics-ai-app-xxxxx`（自動生成）

### 2. 課金アカウントの設定
1. 左メニューから「お支払い」を選択
2. クレジットカードを登録
3. **重要**: 無料枠（$300クレジット）が自動適用されます

### 3. gcloud CLI のインストール
```bash
# macOS
brew install --cask google-cloud-sdk

# または公式インストーラー
# https://cloud.google.com/sdk/docs/install
```

### 4. gcloud の初期設定
```bash
# ログイン
gcloud auth login

# プロジェクト設定
gcloud config set project YOUR-PROJECT-ID
```

## 🚀 デプロイ手順

### 方法1: 自動デプロイ（推奨）
```bash
cd server
./deploy.sh
```

### 方法2: 手動デプロイ
```bash
cd server

# プロジェクトID設定
gcloud config set project YOUR-PROJECT-ID

# 必要なAPIを有効化
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# デプロイ実行
gcloud run deploy gymnastics-ai \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --memory 512Mi \
  --cpu 1
```

## ⚙️ 環境変数の設定

### OpenAI APIキーの設定（任意）
```bash
gcloud run services update gymnastics-ai \
  --region asia-northeast1 \
  --set-env-vars OPENAI_API_KEY=your-api-key-here
```

## 📱 アプリ側の設定

### 1. サービスURLの確認
デプロイ完了後に表示されるURL:
```
https://gymnastics-ai-xxxxx-an.a.run.app
```

### 2. config.dart の更新
```dart
// lib/config.dart
static const Map<Environment, String> _urls = {
  Environment.development: 'http://127.0.0.1:8888',
  Environment.production: 'https://gymnastics-ai-xxxxx-an.a.run.app', // ← ここを更新
};
```

### 3. 環境を本番に切り替え
```dart
static const Environment _environment = Environment.production;
```

## 💰 料金について

### 無料枠（月間）
- **200万リクエスト**まで無料
- **360,000 GB秒**のメモリ無料
- **180,000 vCPU秒**無料

### 予想使用量（月1,000ユーザー）
- リクエスト数: 約30,000回
- **料金: 0円**（無料枠内）

### OpenAI API料金（使用する場合）
- GPT-3.5-turbo: 約$10-50/月
- 専門データベースを優先使用して節約可能

## 🔍 トラブルシューティング

### エラー: プロジェクトが見つからない
```bash
gcloud projects list  # プロジェクト一覧を確認
gcloud config set project PROJECT-ID  # 正しいIDを設定
```

### エラー: APIが有効でない
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### エラー: 権限がない
- Cloud Consoleで「IAMと管理」→ 自分のアカウントに「Cloud Run 管理者」権限を付与

## 📊 モニタリング

### ログの確認
```bash
gcloud run services logs read gymnastics-ai --region asia-northeast1
```

### メトリクスの確認
Cloud Console → Cloud Run → サービス名をクリック → 「メトリクス」タブ

## 🎯 次のステップ

1. **カスタムドメイン設定**（任意）
   - `gymnastics-ai.com` などの独自ドメインを設定可能

2. **CDN設定**（任意）
   - Cloud CDNで応答速度を向上

3. **自動デプロイ設定**（任意）
   - GitHub ActionsでCI/CDパイプライン構築

## ✅ チェックリスト

- [ ] Google Cloudプロジェクト作成
- [ ] 課金アカウント設定
- [ ] gcloud CLIインストール
- [ ] サーバーファイルの準備完了
- [ ] デプロイ実行
- [ ] config.dart更新
- [ ] アプリ動作確認

## 🆘 サポート

問題が発生した場合：
1. [Google Cloud Run ドキュメント](https://cloud.google.com/run/docs)
2. エラーメッセージをコピーして検索
3. Cloud Console のエラーログを確認