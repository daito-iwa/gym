from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any, List
import re

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
    try:
        # Pydantic v2の場合
        routine_data = [
            [skill.model_dump() for skill in group] 
            for group in request.routine
        ]
    except AttributeError:
        # Pydantic v1の場合
        routine_data = [
            [skill.dict() for skill in group] 
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
    import os
    
    session_id = request.session_id
    lang = request.lang
    
    # OpenAI APIキーの確認
    openai_api_key = os.getenv("OPENAI_API_KEY")
    if not openai_api_key or openai_api_key == "sk-dummy":
        # テスト用のダミーレスポンス
        test_response = {
            "ja": f"テスト環境では、実際のAI機能は無効になっています。あなたの質問: 「{request.question}」\n\n実際の機能を使用するには、有効なOpenAI APIキーを設定してください。",
            "en": f"In test environment, actual AI functionality is disabled. Your question: \"{request.question}\"\n\nTo use actual functionality, please set a valid OpenAI API key."
        }
        
        return ChatResponse(
            session_id=session_id,
            answer=test_response.get(lang, test_response["en"]),
            source_documents=[]
        )
    
    # Dスコア計算に関する質問かチェック
    question_lower = request.question.lower()
    
    # 連続技に関する質問
    connection_keywords = ["連続技", "連続", "コンビネーション", "ボーナス", "加点", "connection", "combination", "bonus"]
    if any(keyword in question_lower for keyword in connection_keywords):
        rule_answer = get_dynamic_rule_answer(request.question, lang, "connection")
        if rule_answer:
            return ChatResponse(
                session_id=session_id,
                answer=rule_answer,
                source_documents=[]
            )
    
    # 計算デモに関する質問（優先度高 - 先にチェック）
    demo_keywords = ["もし", "例えば", "計算例", "何点", "いくつ", "what if", "example", "how much", "calculate"]
    # より広いスキル検出パターン
    skill_patterns = [
        r'[a-j]難度', r'[a-j]\s*difficulty', r'\d+技', r'\d+\s*skill',
        r'[a-j]難度\d+技', r'd難度.*?c難度', r'c難度.*?d難度'
    ]
    skill_mention = any(re.search(pattern, question_lower) for pattern in skill_patterns)
    demo_check = any(keyword in question_lower for keyword in demo_keywords)
    
    if (demo_check and skill_mention) or re.search(r'[a-j]難度.*?[a-j]難度.*?何点', question_lower):
        demo_answer = get_calculation_demo_answer(request.question, lang)
        if demo_answer:
            return ChatResponse(
                session_id=session_id,
                answer=demo_answer,
                source_documents=[]
            )
    
    # 種目別ルールに関する質問
    apparatus_keywords = ["床", "あん馬", "つり輪", "跳馬", "平行棒", "鉄棒", "fx", "ph", "sr", "vt", "pb", "hb", "floor", "pommel", "rings", "vault", "parallel", "horizontal"]
    rule_keywords = ["技数", "グループ", "制限", "必要", "ルール", "rules", "groups", "skills", "limit"]
    if any(ak in question_lower for ak in apparatus_keywords) and any(rk in question_lower for rk in rule_keywords):
        rule_answer = get_dynamic_rule_answer(request.question, lang, "apparatus")
        if rule_answer:
            return ChatResponse(
                session_id=session_id,
                answer=rule_answer,
                source_documents=[]
            )
    
    # 難度値に関する質問（計算デモに該当しない場合のみ）
    difficulty_keywords = ["難度値", "価値", "点数", "difficulty", "value", "points"]
    difficulty_only = ["a難度", "b難度", "c難度", "d難度", "e難度", "f難度", "g難度", "h難度", "i難度", "j難度"]
    # デモ質問でない場合のみ難度値説明を返す
    if not demo_check and (any(keyword in question_lower for keyword in difficulty_keywords) or 
                          any(keyword in question_lower for keyword in difficulty_only)):
        rule_answer = get_dynamic_rule_answer(request.question, lang, "difficulty")
        if rule_answer:
            return ChatResponse(
                session_id=session_id,
                answer=rule_answer,
                source_documents=[]
            )
    
    # Dスコア計算全般に関する質問
    dscore_keywords = ["dスコア", "d-score", "計算", "calculation", "種目", "apparatus", "体操", "gymnastics"]
    if any(keyword in question_lower for keyword in dscore_keywords):
        rule_answer = get_dynamic_rule_answer(request.question, lang, "overview")
        if rule_answer:
            return ChatResponse(
                session_id=session_id,
                answer=rule_answer,
                source_documents=[]
            )
    
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

def get_dynamic_rule_answer(question: str, lang: str, question_type: str) -> str:
    """
    実装されたルールに基づいて動的に回答を生成する
    整合性保証とフォールバック機能を含む
    """
    try:
        question_lower = question.lower()
        
        if question_type == "connection":
            # 特定の種目について質問されているかチェック
            if "床" in question_lower or "fx" in question_lower:
                result = d_score_calculator.get_connection_rules_explanation("FX", lang)
                return result if result else _fallback_response(lang, "connection")
            elif "鉄棒" in question_lower or "hb" in question_lower:
                result = d_score_calculator.get_connection_rules_explanation("HB", lang)
                return result if result else _fallback_response(lang, "connection")
            else:
                # 一般的な連続技質問 - FXとHBの両方を表示
                fx_rules = d_score_calculator.get_connection_rules_explanation("FX", lang)
                hb_rules = d_score_calculator.get_connection_rules_explanation("HB", lang)
                if fx_rules and hb_rules:
                    if lang == "ja":
                        return f"""連続技ボーナスについて、このアプリで実装されているルールをお答えします：

{fx_rules}

{hb_rules}

詳細は各種目のDスコア計算機能で実際に試してご確認ください。"""
                    else:
                        return f"""Based on the connection bonus rules implemented in this app:

{fx_rules}

{hb_rules}

Please use the D-score calculation feature to see these rules in action."""
                return fx_rules or hb_rules or _fallback_response(lang, "connection")
        
        elif question_type == "apparatus":
            # 特定の種目について質問されているかチェック
            apparatus_map = {
                "床": "FX", "fx": "FX",
                "あん馬": "PH", "ph": "PH", "pommel": "PH",
                "つり輪": "SR", "sr": "SR", "rings": "SR",
                "跳馬": "VT", "vt": "VT", "vault": "VT", 
                "平行棒": "PB", "pb": "PB", "parallel": "PB",
                "鉄棒": "HB", "hb": "HB", "horizontal": "HB"
            }
            
            detected_apparatus = None
            for keyword, apparatus in apparatus_map.items():
                if keyword in question_lower:
                    detected_apparatus = apparatus
                    break
            
            if detected_apparatus:
                result = d_score_calculator.get_apparatus_rules_explanation(detected_apparatus, lang)
                return result if result else _fallback_response(lang, "apparatus")
            else:
                # 全種目の概要を返す
                result = d_score_calculator.get_all_apparatus_overview(lang)
                return result if result else _fallback_response(lang, "overview")
        
        elif question_type == "difficulty":
            result = d_score_calculator.get_difficulty_values_explanation(lang)
            return result if result else _fallback_response(lang, "difficulty")
        
        elif question_type == "overview":
            result = d_score_calculator.get_all_apparatus_overview(lang)
            return result if result else _fallback_response(lang, "overview")
        
        return None
        
    except Exception as e:
        print(f"Error in get_dynamic_rule_answer: {e}")
        return _fallback_response(lang, question_type)

def _fallback_response(lang: str, question_type: str) -> str:
    """
    Dスコア計算システムからの情報取得に失敗した場合のフォールバック応答
    """
    if lang == "ja":
        base_message = "申し訳ございませんが、Dスコア計算システムからの情報取得に問題が発生しました。"
        
        if question_type == "connection":
            return f"""{base_message}

連続技ボーナスについての詳細は、アプリのDスコア計算機能で実際に技を選択して連続技設定を行うことで確認できます。または、ルールブックの関連セクションをご参照ください。"""
        
        elif question_type == "apparatus":
            return f"""{base_message}

各種目のルールについては、アプリのDスコア計算機能で実際の計算を試すか、ルールブックの該当箇所をご確認ください。"""
        
        elif question_type == "difficulty":
            return f"""{base_message}

難度値については、体操競技では一般的にA難度（0.1点）からJ難度（1.0点）まで設定されています。詳細はアプリのDスコア計算機能でご確認ください。"""
        
        else:
            return f"""{base_message}

詳細な情報については、アプリのDスコア計算機能をご利用いただくか、一般的なルールブック検索をお試しください。"""
    
    else:
        base_message = "Sorry, there was an issue accessing information from the D-score calculation system."
        
        if question_type == "connection":
            return f"""{base_message}

For details about connection bonuses, please use the app's D-score calculation feature to select skills and set up connections, or refer to the relevant rulebook sections."""
        
        elif question_type == "apparatus":
            return f"""{base_message}

For apparatus-specific rules, please try the actual calculations in the app's D-score feature or check the relevant rulebook sections."""
        
        elif question_type == "difficulty":
            return f"""{base_message}

Difficulty values in gymnastics typically range from A difficulty (0.1 points) to J difficulty (1.0 points). Please check the app's D-score calculation feature for details."""
        
        else:
            return f"""{base_message}

For detailed information, please use the app's D-score calculation feature or try a general rulebook search."""

def get_calculation_demo_answer(question: str, lang: str) -> str:
    """
    質問から技情報を抽出して計算デモンストレーションを行う
    """
    import re
    
    question_lower = question.lower()
    
    # 種目を検出
    apparatus_map = {
        "床": "FX", "fx": "FX",
        "あん馬": "PH", "ph": "PH", "pommel": "PH",
        "つり輪": "SR", "sr": "SR", "rings": "SR",
        "跳馬": "VT", "vt": "VT", "vault": "VT", 
        "平行棒": "PB", "pb": "PB", "parallel": "PB",
        "鉄棒": "HB", "hb": "HB", "horizontal": "HB"
    }
    
    detected_apparatus = None
    for keyword, apparatus in apparatus_map.items():
        if keyword in question_lower:
            detected_apparatus = apparatus
            break
    
    # デフォルトは床運動
    if not detected_apparatus:
        detected_apparatus = "FX"
    
    # 難度値を抽出
    difficulty_pattern = r'([a-j])難度|([a-j])\s*difficulty'
    matches = re.findall(difficulty_pattern, question_lower)
    difficulties = []
    for match in matches:
        diff = (match[0] or match[1]).upper()
        difficulties.append(diff)
    
    # 技数を抽出して難度を複製
    number_pattern = r'([a-j]難度)(\d+)技|(\d+)技.*?([a-j]難度)'
    number_matches = re.findall(number_pattern, question_lower)
    for match in number_matches:
        if match[0] and match[1]:  # D難度2技の形式
            diff = match[0][0].upper()
            count = int(match[1])
            # その難度を指定回数追加
            for _ in range(count - 1):  # 既に1つあるので、追加分のみ
                difficulties.append(diff)
        elif match[2] and match[3]:  # 2技D難度の形式
            diff = match[3][0].upper()
            count = int(match[2])
            for _ in range(count - 1):
                difficulties.append(diff)
    
    # グループ情報を抽出（簡単な例）
    group_pattern = r'グループ(\d+)|group\s*(\d+)'
    group_matches = re.findall(group_pattern, question_lower)
    groups = []
    for match in group_matches:
        group = int(match[0] or match[1])
        groups.append(group)
    
    # 技の構成を生成（簡単な例）
    if difficulties:
        skills_list = []
        for i, diff in enumerate(difficulties):
            group = groups[i] if i < len(groups) else (2 if detected_apparatus == "FX" else 1)  # デフォルトグループ
            skills_list.append({
                "value_letter": diff,
                "group": group,
                "id": f"demo_{i}",
                "name": f"{diff}難度技{i+1}",
                "description": f"デモ用{diff}難度技",
                "apparatus": detected_apparatus,
                "value": d_score_calculator.DIFFICULTY_VALUES.get(diff, 0.0)
            })
        
        # 計算デモンストレーションを実行
        demo_result = d_score_calculator.calculate_demo_score(detected_apparatus, skills_list, lang)
        if demo_result:
            if lang == "ja":
                return f"""ご質問の技構成について、実際の計算を行いました：

{demo_result}

この計算は実際のアプリのDスコア計算機能と同じルールを使用しています。より正確な計算のためには、アプリのDスコア計算機能で実際の技を選択してください。"""
            else:
                return f"""I've calculated the D-score for your skill combination:

{demo_result}

This calculation uses the same rules as the app's D-score calculation feature. For more accurate calculations, please use the actual skill selection in the app."""
    
    # 技の抽出ができなかった場合の一般的な回答
    if lang == "ja":
        return f"""計算例をお示しするために、より具体的な技の情報が必要です。

例えば：
「床でD難度の技を2つ連続したら何点？」
「あん馬でC難度3技とD難度1技の構成は何点？」

のように、種目、難度、技数を含めて質問していただけると、実際の計算例をお示しできます。

アプリのDスコア計算機能では、実際の技を選択して正確な計算を行うことができます。"""
    else:
        return f"""To provide a calculation example, I need more specific skill information.

For example:
"What's the score for two D-difficulty skills in sequence on floor?"
"How much for 3 C-difficulty and 1 D-difficulty skills on pommel horse?"

Please include apparatus, difficulty levels, and number of skills in your question for an actual calculation demonstration.

You can use the app's D-score calculation feature to select actual skills for precise calculations."""

def get_connection_rules_answer(question: str, lang: str) -> str:
    """
    後方互換性のため残存 - 新しい動的システムに移行
    """
    return get_dynamic_rule_answer(question, lang, "connection") 