#!/usr/bin/env python3
"""
確実に動作するシンプルサーバー - 認証なし
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import datetime

app = FastAPI(title="Gym AI Server", version="2.0.0")

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

@app.get("/")
async def root():
    return {"message": "Gym AI Server", "version": "2.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage):
    """体操AI専用チャットメッセージ - 認証なし"""
    return {
        "response": f"**🤖 体操専門AI v2.0**\n\nご質問「{chat_data.message}」にお答えします。\n\nサーバーが正常に動作しています！",
        "conversation_id": "test_conv_1",
        "usage_count": 1,
        "remaining_count": 9
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)