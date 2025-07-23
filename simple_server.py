#!/usr/bin/env python3
"""
Simple working server for gymnastics AI
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import datetime
import hashlib
import os

app = FastAPI(title="Gymnastics AI API", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
        "subscription_tier": "guest"
    }

# APIエンドポイント
@app.get("/")
async def root():
    return {"message": "Gymnastics AI API Server", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage, current_user = Depends(get_current_user)):
    """体操AI専用チャットメッセージ"""
    try:
        print(f"🔥 Chat message received: {chat_data.message}")
        
        # 簡単な応答を生成
        response_text = f"""**🤖 体操専門AI**

ご質問「{chat_data.message}」にお答えします。

現在はテストモードで動作しています。以下のような質問にお答えできます：

• 技の難度や詳細
• 減点基準
• FIG公式ルール
• 種目別の技について

より具体的な質問をお聞かせください。"""

        print(f"🔥 Response generated: {response_text[:50]}...")
        
        return {
            "response": response_text,
            "conversation_id": chat_data.conversation_id or "test_conv_1",
            "usage_count": 1,
            "remaining_count": 9
        }
    
    except Exception as e:
        print(f"🚨 Chat error: {e}")
        import traceback
        print(f"🚨 Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"Chat service error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8891)