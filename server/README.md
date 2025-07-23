# Gymnastics AI API Server

体操AI専門コーチングAPIサーバー（Google Cloud Run対応）

## 🚀 クイックスタート

### ローカル開発
```bash
# 依存関係インストール
pip install -r requirements.txt

# サーバー起動
python main.py
```

### Google Cloud Runへのデプロイ
```bash
./deploy.sh
```

## 📋 API仕様

### ヘルスチェック
```
GET /
GET /health
```

### AIチャット
```
POST /chat/message
Content-Type: application/json

{
  "message": "跳馬のラインオーバーについて教えて"
}
```

## 🔧 環境変数

- `OPENAI_API_KEY`: OpenAI APIキー（任意）
- `PORT`: サーバーポート（Cloud Runが自動設定）

## 📝 特徴

- 体操専門知識データベース
- OpenAI API統合（オプション）
- 自動フォールバック機能
- CORS対応
- 本番環境対応