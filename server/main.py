#!/usr/bin/env python3
"""
Simple working server - guaranteed to work
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import datetime

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

# APIエンドポイント
@app.get("/")
async def root():
    return {"message": "Gymnastics AI API Server", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage):
    """体操AI専用チャットメッセージ - 最もシンプル"""
    return {
        "response": f"**🤖 体操専門AI**\n\nご質問「{chat_data.message}」にお答えします。\n\n現在はテストモードで動作しています。",
        "conversation_id": "test_conv_1",
        "usage_count": 1,
        "remaining_count": 9
    }