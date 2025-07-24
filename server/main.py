#!/usr/bin/env python3
"""
Simple working server with debug logging
"""

print("Starting server imports...")

try:
    from fastapi import FastAPI
    print("✓ FastAPI imported")
except Exception as e:
    print(f"✗ FastAPI import error: {e}")
    raise

try:
    from fastapi.middleware.cors import CORSMiddleware
    print("✓ CORSMiddleware imported")
except Exception as e:
    print(f"✗ CORSMiddleware import error: {e}")
    raise

try:
    from pydantic import BaseModel
    print("✓ BaseModel imported")
except Exception as e:
    print(f"✗ BaseModel import error: {e}")
    raise

try:
    from typing import Optional, Dict, Any
    import datetime
    print("✓ All imports successful")
except Exception as e:
    print(f"✗ Import error: {e}")
    raise

print("Creating FastAPI app...")
app = FastAPI(title="Gymnastics AI API", version="1.0.0")
print("✓ FastAPI app created")

# CORS設定
print("Setting up CORS...")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
print("✓ CORS configured")

# データモデル
class ChatMessage(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None

print("✓ Data models defined")

# APIエンドポイント
@app.get("/")
async def root():
    print("Root endpoint called")
    return {"message": "Gymnastics AI API Server", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    print("Health check called")
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage):
    """体操AI専用チャットメッセージ"""
    print(f"Chat endpoint called with message: {chat_data.message}")
    try:
        response = {
            "response": f"**🤖 体操専門AI**\n\nご質問「{chat_data.message}」にお答えします。\n\n現在はテストモードで動作しています。",
            "conversation_id": "test_conv_1",
            "usage_count": 1,
            "remaining_count": 9
        }
        print("✓ Response created successfully")
        return response
    except Exception as e:
        print(f"✗ Error in chat endpoint: {e}")
        raise

print("✓ All endpoints defined")
print("Server initialization complete!")