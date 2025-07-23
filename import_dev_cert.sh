#!/bin/bash

# Development証明書のP12ファイルを作成
echo "Development証明書のP12ファイルを作成しています..."

# 証明書をPEM形式に変換
openssl x509 -in ios_development.cer -inform DER -out ios_development.pem -outform PEM

# P12ファイルを作成（既存の秘密鍵を使用）
openssl pkcs12 -export -out ios_development.p12 -inkey ios_distribution.key -in ios_development.pem -name "iOS Development Certificate"

echo "完了! ios_development.p12 ファイルをダブルクリックしてKeychainにインストールしてください"