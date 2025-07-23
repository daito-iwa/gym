#!/bin/bash
# Gymnastics AI Backend Deployment Script for Google Cloud Run

set -e

# 設定
PROJECT_ID="your-gcp-project-id"
SERVICE_NAME="gymnastics-ai-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Gymnastics AI Backend デプロイメント開始..."

# Google Cloud プロジェクトの設定
echo "📋 Google Cloud プロジェクト設定中..."
gcloud config set project $PROJECT_ID

# Docker イメージをビルド
echo "🏗️ Docker イメージをビルド中..."
docker build -t $IMAGE_NAME .

# イメージをGoogle Container Registryにプッシュ
echo "📦 イメージをContainer Registryにプッシュ中..."
docker push $IMAGE_NAME

# Cloud Run にデプロイ
echo "🚢 Cloud Run にデプロイ中..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars "ENVIRONMENT=production" \
  --set-env-vars "SECRET_KEY=gymnastics-ai-production-secret-key-2024" \
  --port 8000

# サービスURLを取得
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)')

echo "✅ デプロイメント完了！"
echo "🌐 API URL: $SERVICE_URL"
echo "💡 ヘルスチェック: $SERVICE_URL/health"

# 簡単な動作確認
echo "🔍 ヘルスチェック実行中..."
curl -f $SERVICE_URL/health

echo ""
echo "🎉 Gymnastics AI Backend が正常にデプロイされました！"
echo "📋 次の手順:"
echo "   1. Flutter app の config.dart で API URL を更新"
echo "   2. 環境変数 OPENAI_API_KEY を設定"
echo "   3. フロントエンドを再ビルド・デプロイ"