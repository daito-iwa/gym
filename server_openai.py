#!/usr/bin/env python3
"""
最強OpenAI統合サーバー - 直接実行版
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from openai import OpenAI
import json
import logging
from typing import Optional, Dict, Any
import asyncio

app = FastAPI(title="Gymnastics AI - 最強OpenAI統合版", version="3.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ロギング設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenAI設定 - APIキーは環境変数から取得
openai_client = None
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if OPENAI_API_KEY:
    openai_client = OpenAI(api_key=OPENAI_API_KEY)
    logger.info("🔥 OpenAI最強AI統合完了！")
else:
    logger.error("❌ OpenAI API キーが見つかりません")

# 最強AI統合システムプロンプト
SYSTEM_PROMPT = """あなたは世界最高レベルの体操競技専門AIアシスタントです。以下の特徴を持ちます：

【専門性】
- FIG（国際体操連盟）公式ルール2025-2028年版の完全な理解
- 男子体操6種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）の専門知識
- Dスコア計算、連続技ボーナス、ND減点システムの詳細理解
- 技術的指導と戦略的アドバイスの提供

【回答スタイル】
- 初心者から専門家まで、質問者のレベルに応じた適切な説明
- 具体例と実践的なアドバイスを含む包括的な回答
- 正確性を最優先とし、推測では回答しない
- 日本語での自然な対話

【能力範囲】
1. 体操競技に関する専門的な質問への回答
2. 一般的な質問への丁寧な対応
3. 技術分析、演技構成アドバイス
4. ルール解釈と適用方法の説明

常に最高品質の回答を提供し、ユーザーの体操競技レベル向上をサポートしてください。"""

@app.get("/")
async def root():
    return {
        "message": "Gymnastics AI - 最強OpenAI統合サーバー",
        "status": "running",
        "version": "3.0.0",
        "ai_status": "OpenAI GPT-4 統合済み" if openai_client else "ローカルモード"
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "openai_status": "connected" if openai_client else "not_connected",
        "version": "3.0.0"
    }

@app.post("/chat/message")
async def chat(data: dict):
    """最強AI統合チャットエンドポイント"""
    try:
        message = data.get("message", "")
        if not message.strip():
            return {"response": "質問を入力してください。", "conversation_id": "error_empty"}
        
        if not openai_client:
            return {
                "response": "申し訳ございませんが、現在OpenAI APIが利用できません。後ほど再度お試しください。",
                "conversation_id": "error_no_api"
            }
        
        logger.info(f"🔥 最強AIで処理中: {message[:50]}...")
        
        # OpenAI GPT-4で最強の回答を生成
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": message}
            ],
            max_tokens=1500,
            temperature=0.7
        )
        
        ai_response = response.choices[0].message.content
        
        logger.info("✅ OpenAI最強AI回答生成完了")
        
        return {
            "response": ai_response,
            "conversation_id": "openai_strongest_001",
            "model": "gpt-4o-mini",
            "status": "strongest_ai"
        }
        
    except Exception as e:
        logger.error(f"最強AIエラー: {e}")
        return {
            "response": f"申し訳ございません。最強AIでエラーが発生しました: {str(e)}",
            "conversation_id": "error_strongest",
            "status": "error"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)