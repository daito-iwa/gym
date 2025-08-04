from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
import json
from typing import Dict, List, Optional

app = FastAPI()

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
    context: Optional[dict] = None

# Markdownファイルをロード
def load_markdown_files():
    knowledge_base = {}
    md_files = [
        'data/d_score_master_knowledge.md',
        'data/comprehensive_rulebook_analysis.md',
        'data/ai_implementation_guide.md',
        'data/rulebook_ja_summary.md',
        'data/skills_difficulty_tables.md',
        'data/apparatus_details.md',
        'data/difficulty_calculation_system.md'
    ]
    
    for file_path in md_files:
        try:
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    knowledge_base[os.path.basename(file_path)] = content
                    print(f"✅ Loaded: {file_path}")
            else:
                print(f"❌ File not found: {file_path}")
        except Exception as e:
            print(f"❌ Error loading {file_path}: {e}")
    
    return knowledge_base

# グローバル変数
KNOWLEDGE_BASE = load_markdown_files()

# キーワードベースの検索
def search_knowledge(query: str) -> str:
    query_lower = query.lower()
    relevant_info = []
    
    # キーワードとファイルのマッピング
    keyword_to_file = {
        "連続技": ["d_score_master_knowledge.md"],
        "組合せ": ["d_score_master_knowledge.md"],
        "cv": ["d_score_master_knowledge.md"],
        "nd": ["d_score_master_knowledge.md", "comprehensive_rulebook_analysis.md"],
        "減点": ["comprehensive_rulebook_analysis.md"],
        "ルール": ["comprehensive_rulebook_analysis.md", "rulebook_ja_summary.md"],
        "難度": ["skills_difficulty_tables.md", "difficulty_calculation_system.md"],
        "器具": ["apparatus_details.md"],
        "種目": ["apparatus_details.md"],
        "実装": ["ai_implementation_guide.md"]
    }
    
    # 関連ファイルを検索
    relevant_files = set()
    for keyword, files in keyword_to_file.items():
        if keyword in query_lower:
            relevant_files.update(files)
    
    # 関連情報を抽出
    for file_name in relevant_files:
        if file_name in KNOWLEDGE_BASE:
            content = KNOWLEDGE_BASE[file_name]
            # 簡単な段落抽出（改良の余地あり）
            paragraphs = content.split('\n\n')
            for para in paragraphs:
                if any(keyword in para.lower() for keyword in query_lower.split()):
                    relevant_info.append(para[:500])  # 最初の500文字
    
    return '\n\n'.join(relevant_info[:3])  # 最大3段落

@app.get("/")
async def root():
    return {"message": "Advanced Gymnastics AI Server", "status": "running", "knowledge_files": len(KNOWLEDGE_BASE)}

@app.get("/health")
async def health_check():
    return {"status": "healthy", "loaded_files": list(KNOWLEDGE_BASE.keys())}

@app.post("/chat/message")
async def chat(data: ChatMessage):
    message = data.message.lower()
    
    # 知識ベースから検索
    knowledge_context = search_knowledge(message)
    
    # 基本的な回答パターン
    response_patterns = {
        "連続技": f"""連続技について説明します。

{knowledge_context}

FIG公式ルール：
- 床運動: グループⅡ+グループⅡ/Ⅳ、グループⅢ+グループⅢ/Ⅳの組み合わせで加点
- 鉄棒: 懸垂技や車輪技の特定の組み合わせで加点
- D難度以上 + D難度以上 = +0.2点
- D難度以上 + B/C難度 = +0.1点""",
        
        "nd減点": f"""ND（ニュートラルディダクション）減点について：

{knowledge_context}

主なND減点：
- 時間超過/不足: 0.1〜0.3点
- ライン減点: 0.1点/回
- 服装違反: 0.3点
- コーチの違反: 0.5点""",
        
        "つり輪": """つり輪の詳細情報：

【D難度技（0.4点）】
- 中水平（2秒静止）
- 後方車輪倒立
- 前方車輪倒立
- ホンマ1回ひねり
- 振動倒立
- アザリアン

【器具仕様】
- リング径: 18cm
- リング高さ: 2.8m
- リング間隔: 50cm

【採点ポイント】
- 静止技は2秒保持必須
- 肩の高さまでの振動は減点なし
- 力技と振動技のバランスが重要""",
        
        "演技構成分析": """演技構成分析について説明します。

分析のポイント：
1. 技の難度配分（A〜J）
2. グループ要求の充足（各種目で異なる）
3. 連続技ボーナスの最適化
4. 終末技の選択

最適な演技構成：
- 高難度技を効率的に配置
- 連続技ボーナスを最大化
- グループ要求を満たす
- 体力配分を考慮"""
    }
    
    # メッセージに応じた回答を生成
    for keyword, response_template in response_patterns.items():
        if keyword in message:
            return {
                "response": response_template,
                "conversation_id": data.conversation_id or "adv_001",
                "usage_count": 1,
                "remaining_count": -1
            }
    
    # デフォルト回答（知識ベースを使用）
    if knowledge_context:
        response = f"""ご質問について、以下の情報が見つかりました：

{knowledge_context}

より具体的な質問があれば、詳しくお答えします。"""
    else:
        response = f"""「{data.message}」について、体操AIコーチがお答えします。

体操競技に関する以下のような質問にお答えできます：
- 技の難度や採点基準
- 連続技（CV）の組み合わせ
- ND減点の詳細
- 各種目のルールと要求
- 演技構成の最適化

具体的にどのような情報をお求めですか？"""
    
    return {
        "response": response,
        "conversation_id": data.conversation_id or "adv_001",
        "usage_count": 1,
        "remaining_count": -1
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=port)