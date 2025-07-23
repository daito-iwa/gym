FROM python:3.9-slim

# 作業ディレクトリを設定
WORKDIR /app

# 依存関係をコピー・インストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY . .

# Cloud Runはポート環境変数を提供
ENV PORT 8080

# Uvicornでアプリケーションを起動（Gunicornの代わり）
CMD exec python -m uvicorn main:app --host 0.0.0.0 --port $PORT