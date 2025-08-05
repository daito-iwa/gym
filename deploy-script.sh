#!/bin/bash

# 確実なデプロイスクリプト
set -e

echo "🚀 Starting reliable deployment process..."

# 1. 現在の時刻をタイムスタンプとして取得
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo "📅 Deployment timestamp: $TIMESTAMP"

# 2. Flutter Web ビルド
echo "🔨 Building Flutter Web..."
flutter clean
flutter build web --release

# 3. docs フォルダをバックアップ
echo "💾 Backing up current docs..."
if [ -d "docs" ]; then
    cp -r docs "docs_backup_$TIMESTAMP"
fi

# 4. 新しいビルドをコピー
echo "📦 Copying new build..."
rm -rf docs/assets docs/canvaskit docs/flutter* docs/main.dart.js docs/manifest.json docs/version.json
cp -r build/web/* docs/

# 5. CNAME ファイルを復元
echo "gymnastics-ai.com" > docs/CNAME

# 6. キャッシュバスティング
echo "🔄 Implementing cache busting..."
sed -i '' "s/const CACHE_NAME = 'flutter-app-cache'/const CACHE_NAME = 'flutter-app-cache-$TIMESTAMP'/" docs/flutter_service_worker.js

# 7. ダミーファイルでGitHub Pagesを強制更新
echo "$TIMESTAMP" > docs/deploy-trigger.txt

# 8. コミットとプッシュ
echo "📤 Committing and pushing..."
git add -A
git commit -m "🚀 Reliable deployment v$TIMESTAMP

- Automated deployment process
- Cache busting: $TIMESTAMP
- Backup created: docs_backup_$TIMESTAMP

🤖 Generated with [Claude Code](https://claude.ai/code)"

git push origin main

echo "✅ Deployment completed!"
echo "🌐 URL: https://app.gymnastics-ai.com/"
echo "⏰ Check deployment in 2-3 minutes"
echo "🔍 Verify with: curl -s https://app.gymnastics-ai.com/flutter_service_worker.js | grep $TIMESTAMP"