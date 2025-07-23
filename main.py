from fastapi import FastAPI
from pydantic import BaseModel
import os

app = FastAPI()

class ChatMessage(BaseModel):
    message: str

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.post("/chat/message")
def chat_endpoint(data: ChatMessage):
    return {"response": f"体操AIです: {data.message}"}