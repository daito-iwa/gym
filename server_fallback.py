#!/usr/bin/env python3
"""
最強OpenAI統合サーバー - フォールバック機能付き
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
from openai import OpenAI
import json
import logging
from typing import Optional, Dict, Any
import asyncio

app = FastAPI(title="Gymnastics AI - 最強統合版", version="3.1.0")

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

# OpenAI設定
openai_client = None
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if OPENAI_API_KEY:
    try:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)
        logger.info("🔥 OpenAI最強AI統合完了！")
    except Exception as e:
        logger.error(f"OpenAI初期化エラー: {e}")
else:
    logger.warning("OpenAI APIキーが見つかりません。フォールバックモードで起動します。")

# システムプロンプト
SYSTEM_PROMPT = """あなたは世界最高レベルの体操競技専門AIアシスタントです。

【専門性】
- FIG（国際体操連盟）公式ルール2025-2028年版の完全な理解
- 男子体操6種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）の専門知識
- Dスコア計算、連続技ボーナス、ND減点システムの詳細理解

【回答スタイル】
- 初心者から専門家まで、質問者のレベルに応じた適切な説明
- 具体例と実践的なアドバイスを含む包括的な回答
- 正確性を最優先とし、推測では回答しない

常に最高品質の回答を提供してください。"""

def get_fallback_response(message: str) -> str:
    """フォールバック回答システム"""
    message_lower = message.lower()
    
    # 体操の基本的な質問
    if any(word in message_lower for word in ["体操って", "体操とは", "体操について", "gymnastics"]):
        return """🏅 **体操競技について**

体操競技は、人間の身体能力を最大限に引き出す美しく技術的なスポーツです。正確性、力強さ、優美さ、そして芸術性を兼ね備えた総合的な競技として、オリンピックの花形種目の一つとなっています。

## 📊 男子体操競技の6種目
1. **床運動（FX）** - アクロバティックな技と表現力
2. **あん馬（PH）** - バランスと技術の調和
3. **つり輪（SR）** - 力強さと静止技の美しさ
4. **跳馬（VT）** - 爆発力と着地の安定性
5. **平行棒（PB）** - 複雑な技の組み合わせ
6. **鉄棒（HB）** - ダイナミックな手放し技

## 🎯 採点システム
- **Dスコア**: 技の難易度を反映
- **Eスコア**: 演技の完成度を評価

体操は身体能力だけでなく、表現力や芸術性も求められる素晴らしいスポーツです！"""
    
    # あいさつ
    if any(word in message_lower for word in ["こんにちは", "はじめまして", "よろしく", "hello"]):
        return """こんにちは！体操競技専門AIコーチです🤸‍♂️

私は体操競技について詳しくお答えできます：
• D-Score計算と難度評価
• 技の組み合わせと構成アドバイス
• ルールと採点基準の解説
• 各種目の技術ポイント

何について質問したいですか？"""
    
    # 一般的な体操質問
    return f"""体操競技について「{message}」のご質問ですね。

私は体操競技専門のAIコーチとして、以下のような内容について詳しくお答えできます：

🏅 **技術・ルール関連**
- FIG公式ルールと採点基準
- D-Score計算方法
- 技の難易度と要求グループ
- 連続技（CV）ボーナス

🤸 **実技・指導関連**
- 各種目の技術ポイント
- 演技構成のアドバイス
- 練習方法と上達のコツ

より具体的な質問をしていただければ、詳細にお答えします！"""

@app.get("/")
async def root():
    return {
        "message": "Gymnastics AI - 最強統合サーバー",
        "status": "running",
        "version": "3.1.0",
        "ai_status": "OpenAI統合" if openai_client else "フォールバック"
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "openai_status": "connected" if openai_client else "fallback",
        "version": "3.1.0"
    }

@app.post("/chat/message")
async def chat(data: dict):
    """最強AI統合チャットエンドポイント"""
    try:
        message = data.get("message", "")
        if not message.strip():
            return {"response": "質問を入力してください。", "conversation_id": "error_empty"}
        
        logger.info(f"処理中: {message[:50]}...")
        
        # OpenAI利用可能な場合
        if openai_client:
            try:
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
                logger.info("✅ OpenAI回答生成完了")
                
                return {
                    "response": ai_response,
                    "conversation_id": "openai_strongest_001",
                    "model": "gpt-4o-mini",
                    "status": "strongest_ai"
                }
            except Exception as e:
                logger.error(f"OpenAI APIエラー: {e}")
                # フォールバックに移行
        
        # フォールバック回答
        fallback_response = get_fallback_response(message)
        logger.info("✅ フォールバック回答生成完了")
        
        return {
            "response": fallback_response,
            "conversation_id": "fallback_expert_001",
            "model": "expert_fallback",
            "status": "expert_fallback"
        }
        
    except Exception as e:
        logger.error(f"チャットエラー: {e}")
        return {
            "response": "申し訳ございません。一時的な問題が発生しました。もう一度お試しください。",
            "conversation_id": "error_general",
            "status": "error"
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)