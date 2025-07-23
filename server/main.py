#!/usr/bin/env python3
"""
Gymnastics AI API Server for Google Cloud Run
Production-ready server with OpenAI integration
"""

import os
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
# Cloud Runでは環境変数が自動で設定されるため、dotenvは不要
# from dotenv import load_dotenv

# 環境変数を読み込み（Cloud Runでは不要）
# load_dotenv()

app = FastAPI(
    title="Gymnastics AI API", 
    version="1.0.0",
    description="Professional gymnastics coaching AI API"
)

# CORS設定（本番環境用）
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://gymnastics-ai.web.app",  # Firebase Hosting URL（もし使う場合）
        "https://gymnastics-ai.netlify.app",  # Netlify URL（もし使う場合）
        "http://localhost:*",  # 開発用
        "*"  # 一時的に全許可（後で制限推奨）
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatMessage(BaseModel):
    message: str

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Gymnastics AI API", 
        "version": "1.0.0", 
        "status": "healthy",
        "environment": "production"
    }

@app.get("/health")
async def health_check():
    """Cloud Run health check endpoint"""
    return {"status": "healthy"}

@app.post("/chat/message")
async def chat_message(chat_data: ChatMessage):
    """AI chat endpoint with gymnastics expertise"""
    try:
        # OpenAI APIキーが設定されている場合
        if os.getenv("OPENAI_API_KEY"):
            try:
                import openai
                
                openai.api_key = os.getenv("OPENAI_API_KEY")
                
                # 体操専門のシステムプロンプト
                system_prompt = """あなたは体操競技の専門AIコーチです。
                FIG（国際体操連盟）の最新ルールブックに基づいた正確な情報を提供します。
                技術指導、採点ルール、D-score計算、練習方法について専門的にアドバイスします。
                安全性を最優先に、段階的な上達方法を提案してください。"""
                
                # OpenAI API呼び出し
                response = openai.ChatCompletion.create(
                    model="gpt-3.5-turbo",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": chat_data.message}
                    ],
                    max_tokens=1000,
                    temperature=0.7
                )
                
                response_text = response.choices[0].message.content
                
            except Exception as e:
                print(f"OpenAI API Error: {e}")
                # OpenAIエラー時はフォールバック応答
                response_text = _get_fallback_response(chat_data.message)
        else:
            # OpenAI APIキーがない場合はフォールバック応答
            response_text = _get_fallback_response(chat_data.message)
        
        return {
            "response": response_text,
            "conversation_id": "prod_conversation",
            "usage_count": 1,
            "remaining_count": 999
        }
        
    except Exception as e:
        print(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def _get_fallback_response(message: str) -> str:
    """専門的なフォールバック応答"""
    message_lower = message.lower()
    
    # 跳馬関連
    if any(keyword in message for keyword in ['跳馬', 'ライン', 'オーバー', 'ラインオーバー']):
        return """🏃‍♀️ **跳馬のラインオーバーについて**

**判定基準**
踏切足が完全に踏切線を越えた場合に0.5点減点されます。

**防止策**
1. 助走距離の正確な計測
2. 歩幅リズムの一定化  
3. 踏切板1-2歩手前での調整

**上達のコツ**
練習時から踏切位置を意識し、毎回同じリズムで助走することが重要です。"""

    # 技・難度関連
    elif any(keyword in message for keyword in ['技', '難度', 'D-score', 'Dスコア']):
        return f"""🏅 **技と難度について**

**質問**: {message}

**難度システム**
A難度(0.1) → B難度(0.2) → C難度(0.3) → D難度(0.4) → E難度(0.5) → F難度(0.6) → G難度(0.7) → H難度(0.8) → I難度(0.9) → J難度(1.0)

**D-score構成要素**
1. 技の難度価値の合計（上位8技）
2. 連続ボーナス（CV: 最大0.4点）
3. グループ要求充足（各0.5点）

詳しくはD-score計算機能をご利用ください。"""

    # 着地関連
    elif any(keyword in message for keyword in ['着地', 'ぐらつ', '減点']):
        return """🎯 **着地の減点基準**

**小さな動き**
- 小さく足をずらす: 0.1点
- 片足/両足の小さなホップ: 0.1点
- 手を回す: 0.1点

**中程度の動き**
- 大きな一歩: 0.3点
- 腕を大きく振る: 0.3点

**大きな動き**
- 複数歩: 0.5点
- 転倒: 1.0点

完全静止（スタック着地）を目指しましょう！"""

    # デフォルト応答
    else:
        return f"""🏆 **体操AI専門コーチです**

ご質問: {message}

**専門対応分野**
✅ 技術指導とフォーム改善
✅ D-score計算と向上戦略
✅ FIGルール・採点解説
✅ 安全な練習方法
✅ 全6種目の専門アドバイス

より具体的な質問をいただければ、詳しくお答えできます。
例：「倒立の脚の減点は？」「H難度の価値点は？」「床のグループ要求は？」"""

if __name__ == "__main__":
    # Cloud Runのポート設定
    port = int(os.environ.get("PORT", 8080))
    
    print(f"🏅 Gymnastics AI Server Starting on port {port}...")
    print(f"✅ OpenAI API: {'Enabled' if os.getenv('OPENAI_API_KEY') else 'Disabled (Fallback mode)'}")
    print(f"🚀 Environment: Production (Google Cloud Run)")
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        log_level="info"
    )