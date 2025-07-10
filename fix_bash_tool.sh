#!/bin/bash

echo "🔧 Bashツール修復スクリプト"
echo "================================"

# 1. 一時ディレクトリのクリーンアップ
echo "1. 一時ディレクトリのクリーンアップ中..."
sudo rm -rf /var/folders/*/T/claude-shell-snapshot-* 2>/dev/null || true
rm -rf ~/Library/Caches/Claude* 2>/dev/null || true
rm -rf ~/.cache/Claude* 2>/dev/null || true

# 2. 権限の確認と修正
echo "2. 権限の確認と修正中..."
sudo chmod 755 /var/folders/ 2>/dev/null || true
sudo chmod 1777 /tmp/ 2>/dev/null || true

# 3. システムの一時ディレクトリクリーンアップ
echo "3. システムクリーンアップ中..."
sudo periodic daily 2>/dev/null || true

# 4. 環境変数の確認
echo "4. 環境変数の確認..."
echo "SHELL: $SHELL"
echo "PATH: $PATH"
echo "TMPDIR: $TMPDIR"
echo "HOME: $HOME"

# 5. 一時ディレクトリの状態確認
echo "5. 一時ディレクトリの状態確認..."
ls -la /var/folders/ 2>/dev/null | head -5
ls -la /tmp/ 2>/dev/null | head -5

# 6. 新しい一時ディレクトリの作成
echo "6. 新しい一時ディレクトリの作成..."
export TMPDIR=/tmp/claude-fix-$$
mkdir -p $TMPDIR
chmod 755 $TMPDIR
echo "新しい一時ディレクトリ: $TMPDIR"

echo "✅ 修復スクリプト完了"
echo "================================"
echo "次のステップ："
echo "1. Claude Codeを完全に再起動してください"
echo "2. 新しいチャットセッションを開始してください"
echo "3. Bashツールの動作を確認してください"
echo ""
echo "それでも問題が続く場合は、macOSの再起動をお試しください。"