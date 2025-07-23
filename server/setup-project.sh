#!/bin/bash

echo "🎯 Google Cloud プロジェクト設定ヘルパー"
echo ""
echo "1. まず、以下のURLでプロジェクトを作成してください:"
echo "   https://console.cloud.google.com"
echo ""
echo "2. プロジェクトを作成したら、プロジェクトIDを入力してください"
echo "   (例: gymnastics-ai-app-12345)"
echo ""
read -p "プロジェクトID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ プロジェクトIDが入力されていません"
    exit 1
fi

# deploy.shを更新
sed -i.bak "s/YOUR-PROJECT-ID-HERE/$PROJECT_ID/g" deploy.sh
echo "✅ deploy.sh を更新しました"

# gcloud設定
echo "⚙️  gcloud を設定中..."
gcloud config set project $PROJECT_ID

echo "✅ 設定完了！"
echo ""
echo "次のコマンドでデプロイできます:"
echo "  ./deploy.sh"