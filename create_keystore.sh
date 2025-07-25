#!/bin/bash

echo "🔑 Android Keystore作成スクリプト"
echo "================================"
echo ""
echo "以下の情報を入力してください:"
echo ""

# Keystore作成コマンド
/opt/homebrew/opt/openjdk@17/bin/keytool -genkey -v \
  -keystore ~/gymnastics-ai-release.keystore \
  -alias gymnastics-ai \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

echo ""
echo "✅ Keystore作成完了！"
echo "ファイル: ~/gymnastics-ai-release.keystore"
echo ""
echo "⚠️ 重要: このファイルとパスワードは絶対に失くさないでください！"