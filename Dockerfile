# FastAPI用のDockerfile
FROM python:3.11-slim

# 作業ディレクトリを設定
WORKDIR /app

# システムパッケージのアップデートと必要なパッケージのインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Pythonの依存関係をコピーしてインストール
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# データディレクトリとプロンプトディレクトリの作成
RUN mkdir -p data prompts db_ja db_en

# 権限設定
RUN chmod +x main.py

# Cloud RunはPORT環境変数を使用
ENV PORT=8080
EXPOSE $PORT

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:$PORT/health || exit 1

# Cloud Run用アプリケーション起動（本番用なので--reloadを削除）
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "$PORT"]