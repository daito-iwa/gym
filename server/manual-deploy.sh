#!/bin/bash

echo "🔧 手動デプロイ（認証問題の回避）"

# プロジェクト設定
PROJECT_ID="gymnastics-ai-app"
SERVICE_NAME="gymnastics-ai"
REGION="asia-northeast1"

echo "📋 プロジェクトID: $PROJECT_ID"

# 直接デプロイを試行
echo "🚀 直接デプロイを試行中..."

# Cloud Runへ直接デプロイ
gcloud run deploy $SERVICE_NAME \
    --source . \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --memory 512Mi \
    --cpu 1 \
    --timeout 60 \
    --max-instances 100 \
    --min-instances 0 \
    --project $PROJECT_ID

echo "✅ デプロイ完了（認証問題を回避）"