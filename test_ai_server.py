#!/usr/bin/env python3
"""
AIチャット機能テスト用シンプルサーバー
認証なしでAI機能をテストできます
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import os

app = FastAPI(title="Gymnastics AI Test Server", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatMessage(BaseModel):
    message: str

@app.get("/")
async def root():
    return {"message": "Gymnastics AI Test Server", "version": "1.0.0", "status": "running"}

@app.post("/chat/message")
async def test_chat_message(chat_data: ChatMessage):
    """認証なしAIチャットテスト"""
    try:
        # OpenAI APIキーがあれば実際のAI機能を使用
        if os.getenv("OPENAI_API_KEY"):
            from rulebook_ai import setup_vectorstore, create_conversational_chain
            
            # 日本語検出
            is_japanese = any(ord(char) > 127 for char in chat_data.message)
            lang = "ja" if is_japanese else "en"
            
            # AI応答生成
            vectorstore = setup_vectorstore(lang)
            chain = create_conversational_chain(vectorstore, lang)
            result = chain.invoke({"question": chat_data.message})
            
            response_text = result.get("answer", "AI応答の生成中にエラーが発生しました。")
            
        else:
            # 高品質なフォールバック応答システム
            message_lower = chat_data.message.lower()
            
            # 専門的な応答パターン
            if any(keyword in chat_data.message for keyword in ['跳馬', 'ライン', 'オーバー', 'ラインオーバー']):
                response_text = """跳馬のラインオーバーについてお答えします：

🏃‍♀️ **ラインオーバーとは**
踏切線を越えて踏切を行った場合の減点です。

📏 **判定基準**
- 踏切足が完全に踏切線を越えた場合に適用
- 減点: 中間減点 0.5点
- 審判員の目視判定により決定

⚠️ **防止策**
1. 踏切距離の正確な計測と練習
2. 助走スピードとタイミングの調整
3. 踏切板手前での歩幅調整

💡 **上達のコツ**
踏切線の1-2歩手前から意識して歩幅を調整し、正確な踏切位置を身につけましょう。"""

            elif any(keyword in chat_data.message for keyword in ['技', '難度', 'D-score', 'Dスコア']):
                response_text = f"""技と難度について専門的にお答えします：

🏅 **質問内容**: {chat_data.message}

💎 **難度システム**
- A難度(0.1) → B難度(0.2) → C難度(0.3) → D難度(0.4) → E難度(0.5) → F難度(0.6)

📊 **D-score構成要素**
1. 技の難度価値の合計（上位8-10技）
2. 連続ボーナス（最大0.4点）
3. 構成要求の満充足

🎯 **向上のポイント**
- より高い難度の技の習得
- 効果的な連続技の組み合わせ  
- 全グループ要求の確実な充足

具体的にどの種目・技について詳しく知りたいですか？"""

            elif any(keyword in chat_data.message for keyword in ['練習', '上達', '習得']):
                response_text = f"""練習方法についてアドバイスいたします：

🏃‍♀️ **ご質問**: {chat_data.message}

💪 **効果的な練習法**
1. **基礎技術の反復**: 正しいフォームの定着
2. **段階的難度向上**: 無理のない技術進歩
3. **補強トレーニング**: 必要な筋力・柔軟性の向上

⚠️ **安全第一**
- 必ず指導者の監督下で練習
- 適切なウォームアップとクールダウン
- 疲労時の無理は禁物

🎯 **上達のコツ**
毎回の練習で小さな改善点を1つ見つけて集中的に取り組むことが、確実な上達への近道です。

どの技や種目の練習について具体的に相談したいですか？"""

            else:
                # 一般的な応答
                response_text = f"""体操AI専門コーチです。ご質問ありがとうございます。

📝 **ご質問**: {chat_data.message}

🏆 **専門サポート分野**
✓ 技術指導とフォーム改善
✓ D-score向上の具体的戦略
✓ 2025年FIG規則の最新解説
✓ 安全で効果的な練習方法
✓ 競技構成の最適化提案

💡 **より詳しいアドバイスのために**
以下についてお聞かせください：
- 対象種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）
- 現在のレベル（初心者・中級者・上級者）
- 具体的な悩みや目標

お気軽に何でもご相談ください！"""

        return {
            "response": response_text,
            "conversation_id": "test_conversation",
            "usage_count": 1,
            "remaining_count": 999
        }
        
    except Exception as e:
        print(f"AI Error: {e}")
        # エラー時も有用な応答を提供
        fallback_response = f"""体操AI専門コーチです。

ご質問「{chat_data.message}」については、オフライン知識ベースから基本的な回答をいたします：

🏆 **基本アドバイス**
体操の技術向上には以下が重要です：
- 正確なフォームの習得
- 段階的な練習計画
- 安全性を最優先した指導

💪 **D-score向上のポイント**  
- より高い難度技の習得
- 効果的な連続技組み合わせ
- 要求グループの完全充足

📚 **詳細情報**
より具体的なアドバイスについては、種目名や技名を含めて再度ご質問ください。

※現在はオフラインモードで動作中です"""

        return {
            "response": fallback_response,
            "conversation_id": "test_conversation",  
            "usage_count": 1,
            "remaining_count": 999
        }

if __name__ == "__main__":
    print("🏅 Gymnastics AI Test Server Starting...")
    print("✅ No authentication required for testing")
    print("🚀 Server will be available at: http://localhost:8888")
    
    uvicorn.run(
        "test_ai_server:app",
        host="0.0.0.0",
        port=8888,
        reload=False,
        log_level="info"
    )