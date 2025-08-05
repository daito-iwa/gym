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

class RoutineAnalysisRequest(BaseModel):
    routine_data: List[Dict]
    apparatus: str
    total_score: float
    difficulty_score: float
    group_bonus: float
    connection_bonus: float
    message: Optional[str] = None

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

def create_expert_system_prompt(apparatus: str, routine_data: Optional[List[Dict]] = None) -> str:
    """世界最高レベルの体操競技専門家としてのシステムプロンプトを生成"""
    
    base_prompt = f"""あなたは世界トップクラスの体操競技専門AIコーチです。

【あなたの専門性】
- FIG公式採点規則のエキスパート（最新2022-2024版完全習得）
- D-Score計算の権威（難度・グループ要求・接続ボーナス全て精通）
- 体操技術分析のスペシャリスト
- 演技構成最適化の専門家
- 国際大会レベルの指導経験

【現在分析中の種目】
{apparatus} ({get_apparatus_name(apparatus)})

【あなたの回答スタイル】
✅ 具体的で実用的なアドバイス
✅ 計算根拠を詳細に説明
✅ 改善案を具体的に提示
✅ FIG規則を正確に引用
✅ 競技レベルに応じた指導

【絶対に避けること】
❌ 曖昧な回答
❌ 一般論だけの説明
❌ 計算ミス
❌ 古いルールの引用"""

    if routine_data:
        routine_info = f"""
【現在の演技構成データ】
演技技数: {len(routine_data)}技
技リスト: {[skill.get('name', 'Unknown') for skill in routine_data]}
難度構成: {[skill.get('valueLetter', 'Unknown') for skill in routine_data]}
グループ構成: {[skill.get('group', 'Unknown') for skill in routine_data]}

【分析指針】
この演技構成を基に、具体的で実践的なアドバイスを提供してください。
- なぜその点数になるのか詳細説明
- どう改善すればより高得点が狙えるか
- リスクとメリットの分析
- 代替技の提案"""
        
        base_prompt += routine_info
    
    return base_prompt

def get_apparatus_name(apparatus_code: str) -> str:
    """種目コードから日本語名を取得"""
    apparatus_names = {
        'FX': '床運動',
        'PH': 'あん馬', 
        'SR': 'つり輪',
        'VT': '跳馬',
        'PB': '平行棒',
        'HB': '鉄棒'
    }
    return apparatus_names.get(apparatus_code, apparatus_code)

async def get_ai_response(message: str, knowledge_context: str, routine_data: Optional[List[Dict]] = None, apparatus: str = "FX") -> str:
    """OpenAI APIを使用して世界最高レベルのAI応答を生成"""
    if not openai_client:
        # デモモード：基本的なルールベース応答
        return generate_demo_response(message, knowledge_context)
    
    try:
        # 最強の体操競技専門AIコーチシステムプロンプトを使用
        system_prompt = create_expert_system_prompt(apparatus, routine_data)
        
        # 知識ベースを含む完全なプロンプト
        full_system_prompt = f"""{system_prompt}

【利用可能な知識ベース】
{knowledge_context}

【現在の状況に基づく回答指針】
- 質問内容を正確に理解し、専門家として最適な回答を提供
- 計算結果があれば、その根拠を詳細に説明
- 改善提案は具体的で実践可能なものを提示
- FIG規則を正確に引用し、最新ルールに準拠
- ユーザーの技術レベルに関係なく、理解しやすい説明を心がける"""

        response = openai_client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[
                {"role": "system", "content": full_system_prompt},
                {"role": "user", "content": message}
            ],
            max_tokens=1200,  # より詳細な回答のため増量
            temperature=0.3,  # より正確な回答のため低め
            presence_penalty=0.2,
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

@app.post("/analyze_routine")
async def analyze_routine_endpoint(request: RoutineAnalysisRequest):
    """演技構成の詳細分析エンドポイント - 最強AIコーチの真骨頂"""
    try:
        # 演技構成データから知識ベースを構築
        apparatus_name = get_apparatus_name(request.apparatus)
        knowledge_context = search_knowledge(f"{apparatus_name} 演技構成 分析")
        
        # 詳細な演技分析プロンプトを構築
        analysis_message = f"""演技構成の詳細分析をお願いします。

【演技データ】
種目: {apparatus_name} ({request.apparatus})
総得点: {request.total_score}点
難度点: {request.difficulty_score}点
グループボーナス: {request.group_bonus}点
連続技ボーナス: {request.connection_bonus}点

【技構成】
{format_routine_data(request.routine_data)}

【分析希望項目】
1. 現在の点数の詳細な内訳説明
2. グループ要求の充足状況
3. 連続技ボーナスの詳細
4. さらなる高得点化の具体的提案
5. リスク分析と代替案

{request.message or '上記の演技構成について、詳細で実践的なアドバイスをください。'}"""

        # 最強AIコーチによる分析
        response = await get_ai_response(
            analysis_message, 
            knowledge_context, 
            request.routine_data, 
            request.apparatus
        )
        
        return {
            "analysis": response,
            "routine_summary": {
                "skill_count": len(request.routine_data),
                "apparatus": apparatus_name,
                "total_score": request.total_score,
                "breakdown": {
                    "difficulty": request.difficulty_score,
                    "group_bonus": request.group_bonus,
                    "connection_bonus": request.connection_bonus
                }
            }
        }
        
    except Exception as e:
        print(f"演技分析エラー: {e}")
        raise HTTPException(status_code=500, detail=f"演技分析エラー: {str(e)}")

def format_routine_data(routine_data: List[Dict]) -> str:
    """演技データを読みやすい形式でフォーマット"""
    formatted_skills = []
    for i, skill in enumerate(routine_data, 1):
        skill_name = skill.get('name', 'Unknown')
        value_letter = skill.get('valueLetter', 'Unknown')
        group = skill.get('group', 'Unknown')
        value = skill.get('value', 0.0)
        
        formatted_skills.append(
            f"{i}. {skill_name} (難度:{value_letter}/{value}点/グループ{group})"
        )
    
    return '\n'.join(formatted_skills)

@app.post("/quick_analysis")
async def quick_analysis_endpoint(request: RoutineAnalysisRequest):
    """ワンクリック分析 - 「なぜこの点数？」に即答"""
    try:
        apparatus_name = get_apparatus_name(request.apparatus)
        
        # ワンクリック質問用の簡潔なプロンプト
        quick_message = f"""「なぜこの点数になったのか？」を詳しく説明してください。

【計算結果】
総得点: {request.total_score}点
内訳:
- 難度点: {request.difficulty_score}点
- グループボーナス: {request.group_bonus}点  
- 連続技ボーナス: {request.connection_bonus}点

【種目】{apparatus_name}

この点数の根拠を、初心者にも分かりやすく、しかし詳細に説明してください。
計算式も含めて具体的にお答えください。"""

        knowledge_context = search_knowledge(f"{apparatus_name} 点数計算")
        
        response = await get_ai_response(
            quick_message,
            knowledge_context,
            request.routine_data,
            request.apparatus
        )
        
        return {
            "explanation": response,
            "score_breakdown": {
                "total": request.total_score,
                "difficulty": request.difficulty_score,
                "group_bonus": request.group_bonus,
                "connection_bonus": request.connection_bonus
            }
        }
        
    except Exception as e:
        print(f"クイック分析エラー: {e}")
        raise HTTPException(status_code=500, detail=f"クイック分析エラー: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)