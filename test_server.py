#!/usr/bin/env python3
"""
Simple test server to isolate the problem
"""

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import datetime

app = FastAPI(title="Test Server")

class ChatMessage(BaseModel):
    message: str

@app.get("/")
async def root():
    return {"message": "Test server running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/chat/message")
async def test_chat(chat_data: ChatMessage):
    try:
        print(f"🔥 Received message: {chat_data.message}")
        return {
            "response": f"Echo: {chat_data.message}",
            "status": "success"
        }
    except Exception as e:
        print(f"🚨 Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8890)