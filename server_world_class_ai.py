from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import json
from typing import Dict, List, Optional
import openai
from openai import OpenAI

app = FastAPI()

# OpenAI APIキーの設定
openai_api_key = os.getenv("OPENAI_API_KEY")
if not openai_api_key:
    print("警告: OPENAI_API_KEYが設定されていません。デモモードで動作します。")
    openai_client = None
else:
    openai_client = OpenAI(api_key=openai_api_key)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatMessage(BaseModel):
    message: str
    conversation_id: Optional[str] = None

# 知識ベースを読み込み
KNOWLEDGE_BASE = {}
DATA_FILES = [
    'data/rulebook_ja_full.txt',
    'data/rulebook_ja_summary.md',
    'data/skills_difficulty_tables.md',
    'data/ai_implementation_guide.md',
    'data/comprehensive_rulebook_analysis.md',
    'data/apparatus_details.md'
]

# ファイルを読み込み
for file_path in DATA_FILES:
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            file_name = os.path.basename(file_path)
            KNOWLEDGE_BASE[file_name] = content
            print(f"読み込み完了: {file_name} ({len(content)} 文字)")
    else:
        print(f"ファイルが見つかりません: {file_path}")

print(f"知識ベース読み込み完了: {len(KNOWLEDGE_BASE)} ファイル")

# 検索用マッピング
SEARCH_MAPPING = {
    "床": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"],
    "あん馬": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"],
    "つり輪": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"],
    "跳馬": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"], 
    "平行棒": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"],
    "鉄棒": ["rulebook_ja_full.txt", "skills_difficulty_tables.md"],
    "連続技": ["comprehensive_rulebook_analysis.md"],
    "接続": ["comprehensive_rulebook_analysis.md"],
    "難度": ["skills_difficulty_tables.md"],
    "グループ": ["comprehensive_rulebook_analysis.md"],
    "器具": ["apparatus_details.md"],
    "種目": ["apparatus_details.md"],
    "実装": ["ai_implementation_guide.md"]
}

def search_knowledge(query: str) -> str:
    """知識ベースから関連情報を検索"""
    query_lower = query.lower()
    relevant_info = []
    
    # マッピングに基づいて関連ファイルを特定
    relevant_files = set()
    for keyword, files in SEARCH_MAPPING.items():
        if keyword in query_lower:
            relevant_files.update(files)
    
    # 関連ファイルから情報を抽出
    for file_name in relevant_files:
        if file_name in KNOWLEDGE_BASE:
            content = KNOWLEDGE_BASE[file_name]
            # 簡単な段落抽出（改良の余地あり）
            paragraphs = content.split('\n\n')
            for para in paragraphs:
                if any(keyword in para.lower() for keyword in query_lower.split()):
                    relevant_info.append(para[:500])  # 最初の500文字
    
    return '\n\n'.join(relevant_info[:3])  # 最大3段落

async def get_ai_response(message: str, knowledge_context: str) -> str:
    """OpenAI APIを使用してAI応答を生成"""
    if not openai_client:
        # デモモード：基本的なルールベース応答
        return generate_demo_response(message, knowledge_context)
    
    try:
        # 体操競技専門AIコーチとしてのシステムプロンプト
        system_prompt = f"""あなたは世界トップクラスの体操競技専門AIコーチです。

【あなたの専門性】
- FIG公式採点規則のエキスパート
- D-Score計算の権威
- 体操技術分析のスペシャリスト  
- 男子体操6種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）の専門家
- 世界レベルの競技指導経験を持つ

【応答スタイル】
- 正確で具体的な技術指導
- FIG規則に完全準拠
- 実践的で分かりやすい説明
- 日本語で自然な会話
- 必要に応じて具体的な数値や技名を使用

【利用可能な知識ベース】
{knowledge_context}

【重要】
- 常に最新のFIG規則に基づいて回答
- 不正確な情報は絶対に提供しない
- 分からない場合は正直に「確認が必要」と回答
- ユーザーの技術レベルに合わせて説明の詳しさを調整"""

        response = openai_client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message}
            ],
            max_tokens=800,
            temperature=0.7,
            presence_penalty=0.1,
            frequency_penalty=0.1
        )
        
        return response.choices[0].message.content
        
    except Exception as e:
        print(f"OpenAI API エラー: {e}")
        return generate_demo_response(message, knowledge_context)

def generate_demo_response(message: str, knowledge_context: str) -> str:
    """デモモード用の応答生成"""
    message_lower = message.lower()
    
    if "床" in message_lower or "fx" in message_lower:
        return f"""床運動について、体操AIコーチがお答えします。

{knowledge_context}

【床運動の重要ポイント】
• 演技時間：50〜70秒（時間外は減点）
• グループ要求：4つのグループから最低1技ずつ
• 連続技ボーナス：同グループ内での高難度連続で加点
• エリア活用：演技エリアを効果的に使用

具体的にどのような情報をお求めでしょうか？技の詳細、演技構成、採点について詳しく説明できます。"""
    
    elif "鉄棒" in message_lower or "hb" in message_lower:
        return f"""鉄棒について、体操AIコーチがお答えします。

{knowledge_context}

【鉄棒の特徴】
• 高い技術的要求：離手技・転向技・車輪技の組み合わせ
• 終末技の重要性：演技の締めくくりとなる高難度技
• 連続技ボーナス：D+E以上で0.2点、D+D級で0.1点
• グリップと手の保護：適切な握り方と皮の使用

どの技術について詳しく知りたいですか？カッシーナ、コールマン、コバチ等の具体的な技について説明できます。"""
    
    elif "つり輪" in message_lower or "sr" in message_lower:
        return f"""つり輪について、体操AIコーチがお答えします。

{knowledge_context}

【つり輪の要点】
• 力技と振動技のバランス：筋力と技術の総合力
• 静止技の保持：2秒間の完全静止が必要
• 十字倒立・中水平：代表的な力技
• ホンマ・アザリアン：高難度振動技

具体的な技の習得方法や演技構成についてアドバイスいたします。どの技術について詳しく聞きたいですか？"""
    
    elif "あん馬" in message_lower or "ph" in message_lower:
        return f"""あん馬について、体操AIコーチがお答えします。

{knowledge_context}

【あん馬の特徴】
• 旋回系技術の極致：連続した旋回動作
• 把手間・把手上での技術展開
• シザース・フロップの重要性
• 下馬技の多様性と難度

旋回技術、移動技術、下馬技について詳しく説明できます。どの技術についてお聞きになりたいですか？"""
    
    elif "平行棒" in message_lower or "pb" in message_lower:
        return f"""平行棒について、体操AIコーチがお答えします。

{knowledge_context}

【平行棒の要点】
• 支持技と懸垂技のバランス
• 棒上・棒間での技術展開
• ダイアモンド・ベーレ等の高難度技
• 終末技の重要性

支持系、懸垂系、終末技について詳しく説明できます。どの技術についてお聞きになりたいですか？"""
    
    elif "跳馬" in message_lower or "vt" in message_lower:
        return f"""跳馬について、体操AIコーチがお答えします。

{knowledge_context}

【跳馬の特徴】
• 1回の跳躍での技術表現
• 5つのグループによる技の分類
• 助走・踏切・着手・着地の一連動作
• 高難度技の価値と実施の重要性

具体的な技（ユルチェンコ、ツカハラ、前転跳び等）について詳しく説明できます。"""
    
    elif "連続技" in message_lower or "接続" in message_lower:
        return f"""連続技について、体操AIコーチが詳しく説明します。

{knowledge_context}

【連続技の加点システム】
• D+E以上：0.2点
• D+D級：0.1点  
• C+D級：0.1点

【種目別の特徴】
• 床運動：グループ内連続技で大幅加点
• 鉄棒：懸垂系・転向系の組み合わせ
• 平行棒：支持系・懸垂系の流れるような連続

どの種目の連続技について詳しく知りたいですか？具体的な技の組み合わせについてアドバイスします。"""
    
    else:
        return f"""体操競技について、世界トップクラスのAIコーチがお答えします。

{knowledge_context}

体操競技に関する以下のような質問にお答えできます：
• 技の難度や採点基準
• 連続技（CV）の組み合わせ
• ND減点の詳細
• 各種目のルールと要求
• 演技構成の最適化

具体的にどのような情報をお求めでしょうか？"""

@app.get("/")
async def root():
    return {"message": "World-Class Gymnastics AI Server", "status": "running", "knowledge_files": len(KNOWLEDGE_BASE)}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "loaded_files": list(KNOWLEDGE_BASE.keys())}

@app.post("/chat/message")
async def chat(data: ChatMessage):
    message = data.message.strip()
    
    if not message:
        raise HTTPException(status_code=400, detail="メッセージが空です")
    
    try:
        # 知識ベースから関連情報を検索
        knowledge_context = search_knowledge(message)
        
        # 世界クラスのAI応答を生成
        ai_response = await get_ai_response(message, knowledge_context)
        
        return {
            "response": ai_response,
            "conversation_id": data.conversation_id or "world_ai_001",
            "usage_count": 1,
            "remaining_count": -1
        }
        
    except Exception as e:
        print(f"チャット処理エラー: {e}")
        raise HTTPException(status_code=500, detail="サーバー内部エラーが発生しました")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)