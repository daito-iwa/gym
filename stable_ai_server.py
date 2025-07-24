#!/usr/bin/env python3
"""
🏆 安定版体操AI - Stable Gymnastics AI Server with OpenAI
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import datetime
import os

app = FastAPI(title="Gymnastics AI API", version="1.5.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OpenAI設定（エラーを避けるため慎重に）
OPENAI_READY = False
try:
    import openai
    if os.getenv("OPENAI_API_KEY"):
        openai.api_key = os.getenv("OPENAI_API_KEY")
        OPENAI_READY = True
        print("✅ OpenAI API configured successfully")
    else:
        print("⚠️ OpenAI API key not found")
except ImportError:
    print("⚠️ OpenAI library not available")

# データモデル
class ChatMessage(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None

# シンプルな認証
def get_current_user(authorization: str = Header(None)):
    return {
        "id": "device_user",
        "username": "device_user",
        "subscription_tier": "premium"
    }

# APIエンドポイント
@app.get("/")
async def root():
    return {
        "message": "🏆 Gymnastics AI API Server", 
        "version": "1.5.0", 
        "status": "running",
        "ai_engine": "OpenAI GPT-4" if OPENAI_READY else "Basic Mode"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy", 
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "openai_ready": OPENAI_READY
    }

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage, current_user = Depends(get_current_user)):
    """体操AI専用チャットメッセージ"""
    try:
        print(f"🔥 Chat message received: {chat_data.message}")
        print(f"🔥 OpenAI ready: {OPENAI_READY}")
        
        response_text = ""
        
        # OpenAI APIを試す（エラーハンドリング付き）
        if OPENAI_READY:
            try:
                print("🤖 Calling OpenAI API...")
                
                system_prompt = """あなたは世界最高レベルの体操AIコーチです。
                
専門分野：
- 男子体操6種目・女子体操4種目の技術指導
- FIG公式ルールとD得点計算
- 820技の体操データベース
- 体操以外の質問にも親切に対応

親切で専門的なアドバイスを提供してください。"""
                
                # GPT-3.5を使用（より安定）
                response = openai.ChatCompletion.create(
                    model="gpt-3.5-turbo",
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": chat_data.message}
                    ],
                    max_tokens=800,
                    temperature=0.7
                )
                
                response_text = response.choices[0].message.content
                print(f"🤖 OpenAI response received: {len(response_text)} chars")
                
            except Exception as openai_error:
                print(f"⚠️ OpenAI API error: {openai_error}")
                response_text = None
        
        # フォールバック応答
        if not response_text:
            response_text = f"""**🤖 体操専門AI**

ご質問「{chat_data.message}」にお答えします。

私は体操競技の専門AIコーチです。以下のような質問にお答えできます：

🏅 **体操専門分野：**
• 技の難度や詳細（820技データベース）
• D得点計算とE得点評価
• FIG公式ルール解説
• 演技構成のアドバイス
• 種目別の技術指導

🌟 **一般的な質問にも対応：**
• スポーツ全般のアドバイス
• 健康・フィットネス相談
• その他の日常的な質問

より具体的な質問をお聞かせください！"""
        
        print(f"🔥 Response generated: {len(response_text)} chars")
        
        return {
            "response": response_text,
            "conversation_id": chat_data.conversation_id or "conv_1",
            "usage_count": 1,
            "remaining_count": 99,
            "ai_engine": "GPT-3.5" if OPENAI_READY and response_text else "Fallback"
        }
    
    except Exception as e:
        print(f"🚨 Chat error: {e}")
        import traceback
        print(f"🚨 Traceback: {traceback.format_exc()}")
        
        # エラーでも必ず応答を返す
        return {
            "response": "申し訳ございません。一時的な問題が発生しました。もう一度お試しください。",
            "conversation_id": "error_conv",
            "usage_count": 0,
            "remaining_count": 99,
            "ai_engine": "Error Handler"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)