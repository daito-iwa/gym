# 🚀 本番サーバーデプロイガイド

## 🌐 推奨デプロイ環境

### クラウドプロバイダー選択肢

#### 1. Google Cloud Platform (推奨)
```yaml
メリット:
- Firebase統合が簡単
- 日本リージョン利用可能
- 自動スケーリング
- 優れたAI/ML統合

サービス構成:
- App Engine (Python): APIサーバー
- Cloud SQL (PostgreSQL): データベース
- Cloud Storage: ファイル保存
- Cloud CDN: 静的コンテンツ配信
```

#### 2. AWS (代替案)
```yaml
サービス構成:
- EC2 + Elastic Beanstalk: APIサーバー
- RDS (PostgreSQL): データベース  
- S3: ファイル保存
- CloudFront: CDN
```

#### 3. 簡単デプロイ (個人・小規模)
```yaml
Platform as a Service:
- Railway: https://railway.app/
- Render: https://render.com/
- Fly.io: https://fly.io/
```

## 🏗️ GCP App Engineデプロイ (推奨)

### 1. GCPプロジェクト準備
```bash
# Google Cloud CLI インストール
curl https://sdk.cloud.google.com | bash
source ~/.bashrc

# 認証
gcloud auth login

# プロジェクト作成
gcloud projects create gymnastics-ai-prod --name="Gymnastics AI Production"

# プロジェクト設定
gcloud config set project gymnastics-ai-prod

# 必要なAPI有効化
gcloud services enable appengine.googleapis.com
gcloud services enable cloudsql.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

### 2. app.yamlファイル作成
```yaml
# app.yaml
runtime: python39
service: default
instance_class: F2

automatic_scaling:
  min_instances: 0
  max_instances: 10
  target_cpu_utilization: 0.6

env_variables:
  ENVIRONMENT: "production"
  
# シークレット管理
includes:
- secrets.yaml

# 静的ファイル
handlers:
- url: /static
  static_dir: static
  secure: always

- url: /.*
  script: auto
  secure: always

# ヘルスチェック
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 4
  success_threshold: 2
```

### 3. secrets.yaml作成
```yaml
# secrets.yaml
env_variables:
  OPENAI_API_KEY:
    _secret: openai-api-key
  STRIPE_SECRET_KEY:
    _secret: stripe-secret-key
  JWT_SECRET:
    _secret: jwt-secret
  DB_PASSWORD:
    _secret: db-password
```

### 4. requirements.txtの確認
```python
# requirements.txt (現在のものを確認・追加)
fastapi>=0.104.1
uvicorn[standard]>=0.24.0
python-multipart>=0.0.6
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
python-dotenv>=1.0.0
openai>=1.0.0
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0
google-cloud-secret-manager>=2.16.0
google-cloud-sql-connector>=1.0.0
stripe>=7.0.0
```

### 5. デプロイスクリプト作成
```bash
#!/bin/bash
# deploy.sh

echo "🚀 Gymnastics AI 本番デプロイ開始..."

# 環境変数設定
export PROJECT_ID="gymnastics-ai-prod"
export REGION="asia-northeast1"

# シークレット設定
echo "🔐 シークレット設定中..."
gcloud secrets create openai-api-key --data-file=- <<< "$OPENAI_API_KEY"
gcloud secrets create stripe-secret-key --data-file=- <<< "$STRIPE_SECRET_KEY"
gcloud secrets create jwt-secret --data-file=- <<< "$JWT_SECRET_KEY"

# Cloud SQL インスタンス作成
echo "💾 データベース作成中..."
gcloud sql instances create gymnastics-ai-db \
  --database-version=POSTGRES_14 \
  --region=$REGION \
  --cpu=1 \
  --memory=3840MB \
  --storage-size=20GB \
  --storage-type=SSD

# データベース・ユーザー作成
gcloud sql databases create production --instance=gymnastics-ai-db
gcloud sql users create app-user --instance=gymnastics-ai-db --password=$DB_PASSWORD

# App Engine デプロイ
echo "🎯 App Engine デプロイ中..."
gcloud app deploy --promote --stop-previous-version

echo "✅ デプロイ完了!"
echo "🌍 URL: https://gymnastics-ai-prod.appspot.com"
```

### 6. Cloud SQL接続設定
```python
# database.py (追加)
import os
from google.cloud.sql.connector import Connector
import sqlalchemy
from sqlalchemy.orm import sessionmaker

def create_db_connection():
    """本番環境用のCloud SQL接続"""
    if os.getenv('ENVIRONMENT') == 'production':
        # Cloud SQL Connector使用
        instance_connection_name = "gymnastics-ai-prod:asia-northeast1:gymnastics-ai-db"
        
        connector = Connector()
        
        def getconn():
            conn = connector.connect(
                instance_connection_name,
                "pg8000",
                user="app-user",
                password=os.getenv("DB_PASSWORD"),
                db="production"
            )
            return conn
        
        engine = sqlalchemy.create_engine(
            "postgresql+pg8000://",
            creator=getconn,
        )
    else:
        # 開発環境用
        engine = sqlalchemy.create_engine("sqlite:///./test.db")
    
    return engine
```

## 🐳 Docker + Cloud Run (代替案)

### Dockerfile作成
```dockerfile
FROM python:3.9-slim

WORKDIR /app

# 依存関係インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコピー
COPY . .

# 非rootユーザー作成
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# ポート設定
ENV PORT=8080
EXPOSE $PORT

# 起動コマンド
CMD uvicorn api:app --host 0.0.0.0 --port $PORT
```

### Cloud Runデプロイ
```bash
# Docker イメージビルド
docker build -t gcr.io/gymnastics-ai-prod/api .

# Container Registryにプッシュ  
docker push gcr.io/gymnastics-ai-prod/api

# Cloud Run デプロイ
gcloud run deploy gymnastics-ai-api \
  --image gcr.io/gymnastics-ai-prod/api \
  --platform managed \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars ENVIRONMENT=production
```

## 🌍 CDN・ドメイン設定

### 1. カスタムドメイン設定
```yaml
ドメイン構成例:
メインサイト: gymnastics-ai.com
APIエンドポイント: api.gymnastics-ai.com  
Webアプリ: app.gymnastics-ai.com
管理画面: admin.gymnastics-ai.com
```

### 2. SSL証明書
```bash
# Google Managed SSL証明書
gcloud compute ssl-certificates create gymnastics-ai-ssl \
  --domains=gymnastics-ai.com,api.gymnastics-ai.com,app.gymnastics-ai.com
```

### 3. ロードバランサー設定
```bash
# HTTPロードバランサー作成
gcloud compute url-maps create gymnastics-ai-lb \
  --default-service=gymnastics-ai-backend

# HTTPSリダイレクト設定
gcloud compute url-maps import gymnastics-ai-lb \
  --source=lb-config.yaml
```

## 📊 監視・ログ設定

### Cloud Monitoring設定
```yaml
アラート設定:
- API応答時間 > 5秒
- エラー率 > 1%  
- CPU使用率 > 80%
- メモリ使用率 > 80%
- データベース接続エラー

ダッシュボード:
- リクエスト数・応答時間
- エラー率・ステータスコード分布
- ユーザー数・セッション数
- AI API使用量・コスト
```

### Cloud Logging設定
```python
# logging_config.py
import logging
import os
from google.cloud import logging as cloud_logging

def setup_logging():
    if os.getenv('ENVIRONMENT') == 'production':
        client = cloud_logging.Client()
        client.setup_logging()
        
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
```

## 🔒 セキュリティ設定

### 1. ファイアウォール設定
```bash
# HTTPSトラフィックのみ許可
gcloud compute firewall-rules create allow-https \
  --allow tcp:443 \
  --target-tags https-server

# 不要なポート閉鎖
gcloud compute firewall-rules create deny-all \
  --action deny \
  --rules tcp:22,tcp:80,tcp:8080
```

### 2. IAM設定
```yaml
最小権限原則:
App Engine Service Account:
- Cloud SQL Client
- Secret Manager Secret Accessor
- Cloud Storage Object Viewer

開発者アクセス:  
- App Engine Deployer
- Cloud SQL Editor
- Secret Manager Admin
```

## 📋 デプロイチェックリスト

### 事前準備
- [ ] GCPプロジェクト作成
- [ ] 課金アカウント設定
- [ ] 必要なAPI有効化
- [ ] ドメイン購入・設定

### デプロイ実行
- [ ] シークレット設定
- [ ] データベース作成
- [ ] アプリケーションデプロイ
- [ ] ヘルスチェック確認

### 事後確認
- [ ] HTTPS動作確認
- [ ] API エンドポイント確認
- [ ] データベース接続確認  
- [ ] 監視・ログ設定確認

---

**次のステップ: 本番環境での最終動作テスト**