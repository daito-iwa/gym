# Google App Engine エントリーポイント
import os
import sys

# パス設定
sys.path.insert(0, os.path.dirname(__file__))

# サーバーアプリケーションをインポート
from server import app

if __name__ == "__main__":
    # 開発環境での実行用
    port = int(os.environ.get("PORT", 8080))
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=port)