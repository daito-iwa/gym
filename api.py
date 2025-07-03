from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any, List

# AIロジックをインポート
import rulebook_ai 
import d_score_calculator

# グローバル変数として会話チェーンを保持する辞書
# key: session_id, value: ConversationalRetrievalChain
chat_sessions: Dict[str, Any] = {}

# スキルデータベースをキャッシュするためのグローバル変数
# key: lang, value: skill_database
skill_databases: Dict[str, Any] = {}

app = FastAPI(
    title="Gymnastics AI API",
    description="API for gymnastics rulebook chat and D-score calculation.",
    version="0.1.0",
)

# --- データモデルの定義 ---

class HealthCheck(BaseModel):
    status: str

class ChatRequest(BaseModel):
    session_id: str
    question: str
    lang: str = "ja"

class ChatResponse(BaseModel):
    session_id: str
    answer: str
    source_documents: list = []

class Skill(BaseModel):
    id: str
    name: str
    group: int
    value_letter: str
    description: str
    apparatus: str
    value: float

class RoutineRequest(BaseModel):
    # [[技A], [技B, 技C], ...] のような構造
    routine: List[List[Skill]]

class DScoreStatus(BaseModel):
    fulfilled: int
    required: int

class DScoreResponse(BaseModel):
    d_score: float
    status: DScoreStatus
    difficulty_value: float
    group_bonus: float
    connection_bonus: float
    total_skills_in_routine: int


# --- APIエンドポイントの定義 ---

@app.get("/", tags=["Health Check"])
def health_check() -> HealthCheck:
    """
    APIサーバーの状態を確認するためのエンドポイント
    """
    return HealthCheck(status="ok")

@app.get("/skills/{lang}/{apparatus}", tags=["D-Score Calculator"], response_model=List[Skill])
def get_skills(lang: str, apparatus: str) -> List[Skill]:
    """
    指定された言語と種目に合致する技のリストを返す
    """
    # キャッシュされたスキルデータベースをチェック
    if lang not in skill_databases:
        print(f"{lang} のスキルデータベースを読み込みます...")
        skill_databases[lang] = d_score_calculator.load_skills_from_csv(lang)
    
    skill_db = skill_databases[lang]
    skills = skill_db.get(apparatus.upper(), [])
    return [Skill(**s) for s in skills]

@app.post("/calculate_d_score/{apparatus}", tags=["D-Score Calculator"], response_model=DScoreResponse)
def calculate_d_score_api(apparatus: str, request: RoutineRequest) -> DScoreResponse:
    """
    技の構成を受け取り、Dスコアを計算して返す
    """
    # Pydanticモデルを辞書のリストに変換
    routine_data = [
        [skill.model_dump() for skill in group] 
        for group in request.routine
    ]

    d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills = d_score_calculator.calculate_d_score(
        apparatus.upper(),
        routine_data
    )

    return DScoreResponse(
        d_score=d_score,
        status=DScoreStatus(**status_info),
        difficulty_value=difficulty_value,
        group_bonus=group_bonus,
        connection_bonus=connection_bonus,
        total_skills_in_routine=total_skills
    )

@app.post("/chat", tags=["AI Chat"])
def chat(request: ChatRequest) -> ChatResponse:
    """
    ルールブックに関する質問を受け取り、AIが回答を生成するエンドポイント
    """
    session_id = request.session_id
    lang = request.lang
    
    # セッションIDに対応する会話チェーンが存在しない場合は新規作成
    if session_id not in chat_sessions:
        print(f"新しいセッションを開始します: {session_id}")
        # 1. ベクトルストアをロード
        vectorstore = rulebook_ai.setup_vectorstore(lang=lang)
        # 2. 会話チェーンを作成
        chat_sessions[session_id] = rulebook_ai.create_conversational_chain(vectorstore, lang=lang)

    # 会話チェーンを取得
    qa_chain = chat_sessions[session_id]
    
    # 質問を渡して回答を取得
    result = qa_chain({"question": request.question})
    
    # レスポンスを作成
    response = ChatResponse(
        session_id=session_id,
        answer=result["answer"],
        source_documents=[doc.dict() for doc in result.get("source_documents", [])]
    )
    
    return response 