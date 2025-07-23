#!/bin/bash

# Google Cloud Run デプロイスクリプト
# 使用方法: ./deploy.sh

set -e

# 設定
PROJECT_ID="gymnastics-ai-app"
SERVICE_NAME="gymnastics-ai"
REGION="asia-northeast1"  # 東京リージョン

echo "🚀 Google Cloud Run へのデプロイを開始します..."

# プロジェクトIDの確認
echo "📋 プロジェクトID: $PROJECT_ID"
echo "このプロジェクトIDで続行しますか？ (y/n): "
read -n 1 -r REPLY
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "❌ デプロイをキャンセルしました"
    exit 1
fi

# gcloud設定
echo "⚙️  Google Cloud の設定中..."
gcloud config set project $PROJECT_ID

# APIの有効化
echo "🔧 必要なAPIを有効化中..."
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Cloud Buildでデプロイ
echo "🏗️  ビルドとデプロイを実行中..."
gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --timeout 60 \
    --max-instances 100 \
    --min-instances 0

# デプロイ完了
echo "✅ デプロイが完了しました！"

# サービスURLを取得
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')
echo "🌐 サービスURL: $SERVICE_URL"

# 環境変数の設定方法を表示
echo ""
echo "📝 環境変数の設定方法:"
echo "1. OpenAI APIキーを設定する場合:"
echo "   gcloud run services update $SERVICE_NAME --region $REGION --set-env-vars OPENAI_API_KEY=your-key-here"
echo ""
echo "2. Flutter アプリの config.dart を以下のように更新してください:"
echo "   Environment.production: '$SERVICE_URL',"
echo ""
echo "🎉 デプロイ完了！"