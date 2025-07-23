#!/bin/bash
# 本番環境デプロイスクリプト

set -e

echo "🚀 Gymnastics AI 本番環境デプロイ開始..."

# 設定
PROJECT_ID="gymnastics-ai-prod"
REGION="asia-northeast1"
APP_NAME="gymnastics-ai"

# プロジェクト設定
echo "📋 Google Cloud プロジェクト設定..."
gcloud config set project $PROJECT_ID

# 必要なAPI有効化
echo "🔧 必要なAPI有効化中..."
gcloud services enable appengine.googleapis.com
gcloud services enable cloudsql.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# App Engineアプリ作成（初回のみ）
echo "⚙️ App Engine アプリ作成..."
if ! gcloud app describe > /dev/null 2>&1; then
  gcloud app create --region=$REGION
  echo "✅ App Engine アプリ作成完了"
else
  echo "⚠️ App Engine アプリは既に存在します"
fi

# シークレット設定
echo "🔐 シークレット設定中..."

# OpenAI APIキー設定
if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ エラー: OPENAI_API_KEY 環境変数が設定されていません"
  exit 1
fi

echo "$OPENAI_API_KEY" | gcloud secrets create openai-api-key --data-file=- --replication-policy="automatic" 2>/dev/null || echo "⚠️ openai-api-key は既に存在します"

# JWTシークレット設定
JWT_SECRET=${JWT_SECRET:-$(openssl rand -base64 32)}
echo "$JWT_SECRET" | gcloud secrets create jwt-secret-key --data-file=- --replication-policy="automatic" 2>/dev/null || echo "⚠️ jwt-secret-key は既に存在します"

# 管理者パスワード設定
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(openssl rand -base64 16)}
echo "$ADMIN_PASSWORD" | gcloud secrets create admin-password --data-file=- --replication-policy="automatic" 2>/dev/null || echo "⚠️ admin-password は既に存在します"

echo "✅ シークレット設定完了"

# Cloud SQL設定（オプション）
if [ "$SETUP_DATABASE" = "true" ]; then
  echo "💾 Cloud SQL データベース設定中..."
  
  # データベースインスタンス作成
  DB_INSTANCE="$APP_NAME-db"
  if ! gcloud sql instances describe $DB_INSTANCE > /dev/null 2>&1; then
    gcloud sql instances create $DB_INSTANCE \
      --database-version=POSTGRES_14 \
      --region=$REGION \
      --cpu=1 \
      --memory=3840MB \
      --storage-size=20GB \
      --storage-type=SSD
      
    echo "✅ Cloud SQL インスタンス作成完了"
  else
    echo "⚠️ Cloud SQL インスタンスは既に存在します"
  fi
  
  # データベース作成
  gcloud sql databases create production --instance=$DB_INSTANCE 2>/dev/null || echo "⚠️ データベースは既に存在します"
  
  # データベースパスワード設定
  DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 16)}
  gcloud sql users create app-user --instance=$DB_INSTANCE --password=$DB_PASSWORD 2>/dev/null || echo "⚠️ データベースユーザーは既に存在します"
  
  echo "$DB_PASSWORD" | gcloud secrets create database-password --data-file=- --replication-policy="automatic" 2>/dev/null || echo "⚠️ database-password は既に存在します"
fi

# requirements.txtの確認
echo "📦 依存関係確認中..."
if [ ! -f "requirements.txt" ]; then
  echo "❌ エラー: requirements.txt が見つかりません"
  exit 1
fi

# main.py の作成（App Engine用エントリーポイント）
if [ ! -f "main.py" ]; then
  echo "📝 main.py 作成中..."
  cat > main.py << 'EOF'
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))

from server import app

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF
fi

# デプロイ実行
echo "🎯 App Engine デプロイ実行中..."
gcloud app deploy --promote --stop-previous-version --quiet

# デプロイ確認
echo "🔍 デプロイ確認中..."
APP_URL=$(gcloud app browse --no-launch-browser)
if curl -s "$APP_URL/health" | grep -q "healthy"; then
  echo "✅ デプロイ成功！"
  echo "🌍 アプリケーションURL: $APP_URL"
else
  echo "❌ デプロイ後のヘルスチェックに失敗しました"
  echo "📋 ログを確認してください: gcloud app logs tail -s default"
  exit 1
fi

# 設定情報出力
echo ""
echo "🎉 デプロイ完了!"
echo "===================="
echo "プロジェクトID: $PROJECT_ID"
echo "アプリケーションURL: $APP_URL"
echo "管理者パスワード: $ADMIN_PASSWORD"
echo "===================="
echo ""
echo "📋 次のステップ:"
echo "1. config.dart の API URL を以下に更新:"
echo "   Environment.production: '$APP_URL',"
echo "2. Flutter アプリをリビルドしてデプロイ"
echo "3. AdMob本番IDの設定"
echo "4. App Store / Google Play Console 設定"
echo ""