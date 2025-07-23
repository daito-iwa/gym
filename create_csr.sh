#!/bin/bash

# Create CSR for iOS Distribution Certificate
openssl req -new -newkey rsa:2048 -nodes \
    -keyout ios_distribution.key \
    -out ios_distribution.csr \
    -subj "/C=JP/ST=Tokyo/L=Tokyo/O=Daito/OU=Development/CN=Daito iOS Distribution/emailAddress=daito@example.com"

echo "CSR作成完了:"
echo "- 秘密鍵: ios_distribution.key"
echo "- CSRファイル: ios_distribution.csr"
echo ""
echo "Apple Developer Portalで証明書を作成する際に、ios_distribution.csrをアップロードしてください。"