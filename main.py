#!/usr/bin/env python3
# Import the full server application
try:
    from server import app
    print("Successfully imported server.py")
except ImportError as e:
    print(f"Failed to import server.py: {e}")
    # Fallback to basic app
    from fastapi import FastAPI
    from pydantic import BaseModel
    
    app = FastAPI()
    
    class ChatMessage(BaseModel):
        message: str
    
    @app.get("/")
    def read_root():
        return {"Hello": "World", "status": "fallback mode - server.py import failed"}
    
    @app.get("/health")
    def health_check():
        return {"status": "ok"}
    
    @app.post("/chat/message")
    def chat_endpoint(data: ChatMessage):
        return {"response": f"体操AIです（フォールバックモード）: {data.message}"}