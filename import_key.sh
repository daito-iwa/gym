#!/bin/bash

# P12ファイルを作成（証明書と秘密鍵を結合）
echo "P12ファイルを作成しています..."

# 証明書をダウンロードフォルダから探す
CERT_FILE=""
if [ -f ~/Downloads/*.cer ]; then
    CERT_FILE=$(ls ~/Downloads/*.cer | head -1)
    echo "証明書ファイル見つかりました: $CERT_FILE"
else
    echo "証明書ファイル(.cer)がダウンロードフォルダに見つかりません"
    echo "ダウンロードした証明書ファイルをこのフォルダにコピーしてください"
    exit 1
fi

# 証明書をPEM形式に変換
openssl x509 -in "$CERT_FILE" -inform DER -out ios_distribution.pem -outform PEM

# P12ファイルを作成
openssl pkcs12 -export -out ios_distribution.p12 -inkey ios_distribution.key -in ios_distribution.pem -name "iOS Distribution Certificate"

echo "完了! ios_distribution.p12 ファイルをダブルクリックしてKeychainにインポートしてください"
echo "パスワードを聞かれたら、設定したパスワードを入力してください"