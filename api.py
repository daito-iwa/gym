from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from fastapi.responses import JSONResponse
from pydantic import BaseModel, validator
from typing import Dict, Any, List
import re
from datetime import timedelta, datetime
import hashlib
import json
import logging
import traceback
import base64
import hmac
import smtplib
import secrets
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# AIロジックをインポート
import rulebook_ai 
import d_score_calculator
import auth
# テスト用ユーザーを初期化
auth.initialize_test_users()

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# カスタム例外クラス
class APIError(Exception):
    def __init__(self, message: str, status_code: int = 500, error_code: str = "INTERNAL_ERROR"):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        super().__init__(message)

class ValidationError(APIError):
    def __init__(self, message: str):
        super().__init__(message, status_code=400, error_code="VALIDATION_ERROR")

class AuthenticationError(APIError):
    def __init__(self, message: str):
        super().__init__(message, status_code=401, error_code="AUTH_ERROR")

class RateLimitError(APIError):
    def __init__(self, message: str):
        super().__init__(message, status_code=429, error_code="RATE_LIMIT_ERROR")

# グローバル変数として会話チェーンを保持する辞書
# key: session_id, value: ConversationalRetrievalChain
chat_sessions: Dict[str, Any] = {}

# スキルデータベースをキャッシュするためのグローバル変数
# key: lang, value: skill_database
skill_databases: Dict[str, Any] = {}

# パスワードリセット用のトークンを保存するためのグローバル変数
# key: email, value: {"token": str, "timestamp": datetime, "username": str}
password_reset_tokens: Dict[str, Dict[str, Any]] = {}

# --- APIキャッシュシステム ---
class APICache:
    def __init__(self, ttl_minutes: int = 30):
        self.cache: Dict[str, Dict[str, Any]] = {}
        self.ttl_minutes = ttl_minutes
    
    def _generate_key(self, endpoint: str, **kwargs) -> str:
        """リクエストパラメータからキャッシュキーを生成"""
        params = json.dumps(kwargs, sort_keys=True)
        return hashlib.md5(f"{endpoint}:{params}".encode()).hexdigest()
    
    def get(self, endpoint: str, **kwargs) -> Any:
        """キャッシュからデータを取得"""
        key = self._generate_key(endpoint, **kwargs)
        if key in self.cache:
            cache_entry = self.cache[key]
            # TTLチェック
            if datetime.now() - cache_entry['timestamp'] < timedelta(minutes=self.ttl_minutes):
                return cache_entry['data']
            else:
                # 期限切れのエントリを削除
                del self.cache[key]
        return None
    
    def set(self, endpoint: str, data: Any, **kwargs) -> None:
        """データをキャッシュに保存"""
        key = self._generate_key(endpoint, **kwargs)
        self.cache[key] = {
            'data': data,
            'timestamp': datetime.now()
        }
    
    def clear(self) -> None:
        """キャッシュを全削除"""
        self.cache.clear()
    
    def get_stats(self) -> Dict[str, Any]:
        """キャッシュ統計情報を取得"""
        active_entries = 0
        expired_entries = 0
        
        for entry in self.cache.values():
            if datetime.now() - entry['timestamp'] < timedelta(minutes=self.ttl_minutes):
                active_entries += 1
            else:
                expired_entries += 1
        
        return {
            'total_entries': len(self.cache),
            'active_entries': active_entries,
            'expired_entries': expired_entries,
            'ttl_minutes': self.ttl_minutes
        }

# キャッシュインスタンスを作成
api_cache = APICache(ttl_minutes=30)

app = FastAPI(
    title="Gymnastics AI API",
    description="API for gymnastics rulebook chat and D-score calculation.",
    version="0.1.0",
)

# 例外ハンドラーの定義
@app.exception_handler(APIError)
async def api_error_handler(request: Request, exc: APIError):
    logger.error(f"API Error: {exc.message} - Status: {exc.status_code} - Path: {request.url.path}")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "message": exc.message,
                "code": exc.error_code,
                "timestamp": datetime.now().isoformat(),
                "path": str(request.url.path)
            }
        }
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.error(f"HTTP Exception: {exc.detail} - Status: {exc.status_code} - Path: {request.url.path}")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "message": exc.detail,
                "code": "HTTP_ERROR",
                "timestamp": datetime.now().isoformat(),
                "path": str(request.url.path)
            }
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unexpected error: {str(exc)} - Path: {request.url.path}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "message": "Internal server error",
                "code": "INTERNAL_ERROR",
                "timestamp": datetime.now().isoformat(),
                "path": str(request.url.path)
            }
        }
    )

# --- データモデルの定義 ---

class HealthCheck(BaseModel):
    status: str

class ChatRequest(BaseModel):
    session_id: str
    question: str
    lang: str = "ja"
    
    @validator('session_id')
    def validate_session_id(cls, v):
        if not v or len(v) < 10:
            raise ValueError('Invalid session ID format')
        return v
    
    @validator('question')
    def validate_question(cls, v):
        if not v or not v.strip():
            raise ValueError('Question cannot be empty')
        if len(v) > 2000:
            raise ValueError('Question too long (max 2000 characters)')
        return v.strip()
    
    @validator('lang')
    def validate_lang(cls, v):
        if v not in ['ja', 'en']:
            raise ValueError('Language must be "ja" or "en"')
        return v

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
    # 着地成功時の参考情報
    landing_bonus_potential: float = 0.0  # 着地成功時の追加可能点数
    d_score_with_landing: float = 0.0     # 着地成功時の参考合計スコア

class UserSignup(BaseModel):
    username: str
    password: str
    email: str | None = None
    full_name: str | None = None

class PasswordResetRequest(BaseModel):
    email: str

class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str


# --- パスワードリセット用ヘルパー関数 ---

def send_reset_email(email: str, token: str) -> bool:
    """
    パスワードリセット用のメールを送信する
    """
    try:
        # メール設定（実際の使用時にはより安全な認証方法を使用）
        smtp_server = "smtp.gmail.com"
        smtp_port = 587
        sender_email = "your-email@gmail.com"  # 実際のメールアドレスに変更
        sender_password = "your-app-password"  # Gmail App Passwordを使用
        
        # メール本文を作成
        subject = "【大東体操クラブ】パスワードリセット"
        body = f"""
大東体操クラブアプリをご利用いただきありがとうございます。

パスワードリセットのご要求を受け付けました。
以下のリセットコードをアプリに入力してください：

リセットコード: {token}

このコードは10分間有効です。
心当たりがない場合は、このメールを無視してください。

大東体操クラブ
"""
        
        # メッセージを作成
        message = MIMEMultipart()
        message["From"] = sender_email
        message["To"] = email
        message["Subject"] = subject
        message.attach(MIMEText(body, "plain", "utf-8"))
        
        # メール送信（開発環境ではログに出力）
        logger.info(f"Password reset email would be sent to {email}")
        logger.info(f"Reset token: {token}")
        
        # 実際の本番環境では以下のコードを有効化
        # with smtplib.SMTP(smtp_server, smtp_port) as server:
        #     server.starttls()
        #     server.login(sender_email, sender_password)
        #     server.send_message(message)
        
        return True
        
    except Exception as e:
        logger.error(f"Failed to send reset email: {e}")
        return False

def generate_reset_token() -> str:
    """
    パスワードリセット用のトークンを生成する
    """
    return secrets.token_urlsafe(32)

def cleanup_expired_tokens():
    """
    期限切れのリセットトークンを削除する
    """
    current_time = datetime.now()
    expired_emails = []
    
    for email, token_info in password_reset_tokens.items():
        if current_time - token_info['timestamp'] > timedelta(minutes=10):
            expired_emails.append(email)
    
    for email in expired_emails:
        del password_reset_tokens[email]

# --- APIエンドポイントの定義 ---

@app.get("/", tags=["Health Check"])
def health_check() -> HealthCheck:
    """
    APIサーバーの状態を確認するためのエンドポイント
    """
    return HealthCheck(status="ok")

@app.get("/cache/stats", tags=["Cache Management"])
def get_cache_stats():
    """
    キャッシュ統計情報を取得
    """
    return api_cache.get_stats()

@app.post("/cache/clear", tags=["Cache Management"])
def clear_cache():
    """
    キャッシュを全削除
    """
    api_cache.clear()
    return {"message": "Cache cleared successfully"}

@app.get("/skills/{lang}/{apparatus}", tags=["D-Score Calculator"], response_model=List[Skill])
def get_skills(lang: str, apparatus: str) -> List[Skill]:
    """
    指定された言語と種目に合致する技のリストを返す（キャッシュ対応）
    """
    try:
        # 入力値検証
        if lang not in ['ja', 'en']:
            raise ValidationError(f"Unsupported language: {lang}")
        
        apparatus_upper = apparatus.upper()
        valid_apparatus = ['FX', 'PH', 'SR', 'VT', 'PB', 'HB']
        if apparatus_upper not in valid_apparatus:
            raise ValidationError(f"Invalid apparatus: {apparatus}. Must be one of: {', '.join(valid_apparatus)}")
        
        logger.info(f"Getting skills for {lang}/{apparatus_upper}")
        
        # キャッシュから取得を試行
        cached_skills = api_cache.get("skills", lang=lang, apparatus=apparatus_upper)
        if cached_skills is not None:
            logger.info(f"Cache hit for skills {lang}/{apparatus_upper}")
            return cached_skills
        
        # キャッシュされたスキルデータベースをチェック
        if lang not in skill_databases:
            logger.info(f"Loading skill database for {lang}")
            try:
                skill_databases[lang] = d_score_calculator.load_skills_from_csv(lang)
            except Exception as e:
                logger.error(f"Failed to load skills database for {lang}: {e}")
                raise APIError(f"Failed to load skills database: {str(e)}")
        
        skill_db = skill_databases[lang]
        skills = skill_db.get(apparatus_upper, [])
        
        try:
            skill_models = [Skill(**s) for s in skills]
        except Exception as e:
            logger.error(f"Failed to create skill models: {e}")
            raise APIError(f"Failed to process skills data: {str(e)}")
        
        # キャッシュに保存
        api_cache.set("skills", skill_models, lang=lang, apparatus=apparatus_upper)
        
        logger.info(f"Successfully retrieved {len(skill_models)} skills for {lang}/{apparatus_upper}")
        return skill_models
        
    except (ValidationError, APIError):
        raise
    except Exception as e:
        logger.error(f"Unexpected error in get_skills: {e}", exc_info=True)
        raise APIError(f"Unexpected error: {str(e)}")

@app.post("/calculate_d_score/{apparatus}", tags=["D-Score Calculator"], response_model=DScoreResponse)
def calculate_d_score_api(apparatus: str, request: RoutineRequest) -> DScoreResponse:
    """
    技の構成を受け取り、Dスコアを計算して返す（キャッシュ対応）
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
    
    # キャッシュキー用のルーチンデータをハッシュ化
    routine_hash = hashlib.md5(json.dumps(routine_data, sort_keys=True).encode()).hexdigest()
    
    # キャッシュから取得を試行
    cached_result = api_cache.get("d_score", apparatus=apparatus, routine_hash=routine_hash)
    if cached_result is not None:
        return cached_result
    
    d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills, landing_bonus_potential, d_score_with_landing = d_score_calculator.calculate_d_score(
        apparatus.upper(),
        routine_data
    )

    result = DScoreResponse(
        d_score=d_score,
        status=DScoreStatus(**status_info),
        difficulty_value=difficulty_value,
        group_bonus=group_bonus,
        connection_bonus=connection_bonus,
        total_skills_in_routine=total_skills,
        landing_bonus_potential=landing_bonus_potential,
        d_score_with_landing=d_score_with_landing
    )
    
    # キャッシュに保存
    api_cache.set("d_score", result, apparatus=apparatus, routine_hash=routine_hash)
    
    return result

@app.post("/chat", tags=["AI Chat"])
def chat(request: ChatRequest, current_user: auth.User = Depends(auth.get_current_active_user)) -> ChatResponse:
    """
    ルールブックに関する質問を受け取り、AIが回答を生成するエンドポイント (要認証)
    優先順位: 1. ルールブック → 2. D-score計算システム → 3. 一般知識
    """
    import os
    
    session_id = request.session_id
    lang = request.lang
    
    # 一般的なルールブック質問についてキャッシュを確認
    # セッション固有でない質問のみキャッシュ対象
    if _is_cacheable_question(request.question):
        cached_response = api_cache.get("chat", question=request.question, lang=lang)
        if cached_response is not None:
            # セッションIDを更新してレスポンス
            cached_response.session_id = session_id
            return cached_response
    
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
    
    # セッションIDに対応する会話チェーンが存在しない場合は新規作成
    if session_id not in chat_sessions:
        print(f"新しいセッションを開始します: {session_id}")
        # 1. ベクトルストアをロード
        vectorstore = rulebook_ai.setup_vectorstore(lang=lang)
        # 2. 会話チェーンを作成
        chat_sessions[session_id] = rulebook_ai.create_conversational_chain(vectorstore, lang=lang)

    # 会話チェーンを取得
    qa_chain = chat_sessions[session_id]
    
    # 1. 第1優先: ルールブックからの回答を取得
    result = qa_chain({"question": request.question})
    
    # 2. 第2優先: D-score計算システムからの補完情報を取得
    dscore_supplement = get_dscore_supplement(request.question, lang)
    
    # 3. 統合回答を生成
    integrated_answer = integrate_answers(result["answer"], dscore_supplement, lang)
    
    # レスポンスを作成
    response = ChatResponse(
        session_id=session_id,
        answer=integrated_answer,
        source_documents=[doc.dict() for doc in result.get("source_documents", [])]
    )
    
    # キャッシュ可能な質問の場合、レスポンスをキャッシュ
    if _is_cacheable_question(request.question):
        # セッションIDを一時的にクリアしてキャッシュ
        cache_response = ChatResponse(
            session_id="",
            answer=integrated_answer,
            source_documents=[doc.dict() for doc in result.get("source_documents", [])]
        )
        api_cache.set("chat", cache_response, question=request.question, lang=lang)
    
    return response

def _is_cacheable_question(question: str) -> bool:
    """
    キャッシュ可能な質問かどうかを判定する
    セッション固有でない一般的なルールブック質問のみキャッシュ対象
    """
    question_lower = question.lower()
    
    # キャッシュ対象外パターン（セッション固有または個人的な質問）
    uncacheable_patterns = [
        r'私の', r'私は', r'私が', r'my ', r'i ', r'me ',
        r'前回', r'先ほど', r'さっき', r'earlier', r'before', r'previous',
        r'セッション', r'session',
        r'続き', r'続けて', r'continue', r'continuing',
        r'この計算', r'この技', r'this calculation', r'this skill'
    ]
    
    if any(re.search(pattern, question_lower) for pattern in uncacheable_patterns):
        return False
    
    # キャッシュ対象パターン（一般的なルールブック質問）
    cacheable_patterns = [
        r'ルール', r'規則', r'rule', r'regulation',
        r'難度', r'difficulty', r'value',
        r'連続技', r'connection', r'bonus',
        r'グループ', r'group',
        r'終末技', r'dismount',
        r'着地', r'landing',
        r'体操', r'gymnastics',
        r'[a-j]難度', r'[a-j]\s*difficulty',
        r'何点', r'how much', r'how many',
        r'計算', r'calculation'
    ]
    
    return any(re.search(pattern, question_lower) for pattern in cacheable_patterns)

def is_concise_answer_needed(question: str) -> bool:
    """
    簡潔な回答が必要な質問かを判定する
    """
    concise_patterns = [
        r'[a-j]難度.*?場合',
        r'[a-j]難度.*?は.*?[？?]',
        r'何点',
        r'いくつ',
        r'どのくらい',
        r'いくら',
        r'[a-j]difficulty.*?case',
        r'how much',
        r'how many'
    ]
    
    question_lower = question.lower()
    return any(re.search(pattern, question_lower) for pattern in concise_patterns)

def get_dscore_supplement(question: str, lang: str) -> str:
    """
    D-score計算システムからの補完情報を取得する
    """
    question_lower = question.lower()
    
    # 連続技に関する質問
    connection_keywords = ["連続技", "連続", "コンビネーション", "connection", "combination"]
    connection_bonus_keywords = ["連続技ボーナス", "連続ボーナス", "connection bonus"]
    is_connection_question = (any(keyword in question_lower for keyword in connection_keywords) or 
                             any(keyword in question_lower for keyword in connection_bonus_keywords))
    
    if is_connection_question:
        return get_dynamic_rule_answer(question, lang, "connection")
    
    # 着地を止めた場合の加点に関する質問
    landing_bonus_keywords = ["着地.*止め.*加点", "着地.*止まっ.*加点", "landing.*stuck.*bonus"]
    is_landing_bonus_question = any(re.search(pattern, question_lower) for pattern in landing_bonus_keywords)
    
    # 終末技に関する質問
    dismount_keywords = ["終末技", "終末", "dismount"]
    is_dismount_question = any(keyword in question_lower for keyword in dismount_keywords)
    
    if is_landing_bonus_question or is_dismount_question:
        return get_dynamic_rule_answer(question, lang, "dismount")
    
    # 計算デモに関する質問
    specific_demo_patterns = [
        r'[a-j]難度.*?[a-j]難度.*?何点',
        r'もし.*?[a-j]難度.*?連続',
        r'例えば.*?[a-j]難度.*?計算'
    ]
    is_specific_demo = any(re.search(pattern, question_lower) for pattern in specific_demo_patterns)
    
    if is_specific_demo:
        return get_calculation_demo_answer(question, lang)
    
    # 種目別ルールに関する質問
    apparatus_keywords = ["床", "あん馬", "つり輪", "跳馬", "平行棒", "鉄棒", "fx", "ph", "sr", "vt", "pb", "hb", "floor", "pommel", "rings", "vault", "parallel", "horizontal"]
    rule_keywords = ["技数", "グループ", "制限", "必要", "ルール", "rules", "groups", "skills", "limit"]
    if any(ak in question_lower for ak in apparatus_keywords) and any(rk in question_lower for rk in rule_keywords):
        return get_dynamic_rule_answer(question, lang, "apparatus")
    
    # 難度値に関する質問
    difficulty_keywords = ["難度値", "価値", "点数", "difficulty", "value", "points"]
    difficulty_only = ["a難度", "b難度", "c難度", "d難度", "e難度", "f難度", "g難度", "h難度", "i難度", "j難度"]
    if any(keyword in question_lower for keyword in difficulty_keywords) or any(keyword in question_lower for keyword in difficulty_only):
        return get_dynamic_rule_answer(question, lang, "difficulty")
    
    # Dスコア計算全般に関する質問
    dscore_keywords = ["dスコア", "d-score", "計算", "calculation", "体操", "gymnastics"]
    if any(keyword in question_lower for keyword in dscore_keywords):
        return get_dynamic_rule_answer(question, lang, "overview")
    
    return ""  # 該当しない場合は空文字を返す

def has_specific_useful_answer(dscore_supplement: str) -> bool:
    """
    D-score補完情報が具体的で有用な回答を含んでいるかを判定する
    """
    if not dscore_supplement:
        return False
    
    # 具体的な数値や計算結果が含まれているかチェック
    useful_indicators = [
        r'\d+\.?\d*点',  # 数値+点
        r'合計：.*点',   # 合計の記載
        r'難度価値点：', # 具体的な構成要素
        r'グループ加点：',
        r'着地加点：',
        r'\d+ pts',      # 英語版
        r'Total:.*pts'
    ]
    
    return any(re.search(pattern, dscore_supplement) for pattern in useful_indicators)

def integrate_answers(rulebook_answer: str, dscore_supplement: str, lang: str) -> str:
    """
    ルールブックの回答とD-score計算システムの補完情報を統合する
    """
    if not dscore_supplement:
        # D-score計算システムからの補完情報がない場合はルールブックの回答をそのまま返す
        return rulebook_answer
    
    # D-score補完情報が具体的で有用な場合は、それを主回答として使用
    if has_specific_useful_answer(dscore_supplement):
        return dscore_supplement
    
    # そうでない場合は従来通り統合
    if lang == "ja":
        integrated = f"""{rulebook_answer}

---

**このアプリでの実装について:**
{dscore_supplement}"""
    else:
        integrated = f"""{rulebook_answer}

---

**Implementation in this app:**
{dscore_supplement}"""
    
    return integrated

def get_dynamic_rule_answer(question: str, lang: str, question_type: str) -> str:
    """
    実装されたルールに基づいて動的に回答を生成する
    整合性保証とフォールバック機能を含む
    """
    try:
        question_lower = question.lower()
        
        # 簡潔な回答が必要かチェック
        need_concise = is_concise_answer_needed(question)
        
        if question_type == "dismount":
            if need_concise:
                # 簡潔版を使用
                return d_score_calculator.get_dismount_rules_explanation_concise(question, lang)
            else:
                # 詳細版を使用
                return d_score_calculator.get_dismount_rules_explanation(lang)
        
        elif question_type == "connection":
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
        
        elif question_type == "dismount":
            result = d_score_calculator.get_dismount_rules_explanation(lang)
            return result if result else _fallback_response(lang, "dismount")
        
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
        
        elif question_type == "dismount":
            return f"""{base_message}

終末技・着地については、C難度以上の終末技で着地を止めた場合に0.1点の加点があります（あん馬除く）。詳細はアプリのDスコア計算機能やルールブックをご確認ください。"""
        
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
        
        elif question_type == "dismount":
            return f"""{base_message}

For dismount and landing rules, there's a 0.1 point bonus for C difficulty or higher dismounts with stuck landings (except pommel horse). Please check the app's D-score feature or rulebook for details."""
        
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

# --- 認証関連のエンドポイント ---

@app.post("/signup", response_model=auth.User, tags=["Authentication"])
async def signup(user_data: UserSignup):
    """
    新しいユーザーを登録する
    """
    db_user = auth.get_user(auth.fake_users_db, username=user_data.username)
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    hashed_password = auth.get_password_hash(user_data.password)
    user_in_db = auth.UserInDB(
        username=user_data.username,
        hashed_password=hashed_password,
        email=user_data.email,
        full_name=user_data.full_name,
        disabled=False,
    )
    auth.fake_users_db[user_data.username] = user_in_db.model_dump()
    return user_in_db

@app.post("/token", response_model=auth.Token, tags=["Authentication"])
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    ユーザー名とパスワードでログインし、アクセストークンを取得する
    """
    user = auth.get_user(auth.fake_users_db, form_data.username)
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=auth.User, tags=["Authentication"])
async def read_users_me(current_user: auth.User = Depends(auth.get_current_active_user)):
    """
    認証されたユーザー自身の情報を取得する
    """
    return current_user

@app.post("/password-reset-request", tags=["Authentication"])
async def request_password_reset(request: PasswordResetRequest):
    """
    パスワードリセットのリクエストを送信する
    """
    try:
        # 期限切れトークンをクリーンアップ
        cleanup_expired_tokens()
        
        # メールアドレスからユーザーを検索
        user_found = None
        for username, user_data in auth.fake_users_db.items():
            if user_data.get("email") == request.email:
                user_found = {"username": username, "email": request.email}
                break
        
        if not user_found:
            # セキュリティ上、メールアドレスが見つからない場合でも成功メッセージを返す
            return {"message": "パスワードリセットメールを送信しました。メールをご確認ください。"}
        
        # リセットトークンを生成
        reset_token = generate_reset_token()
        
        # トークンを保存
        password_reset_tokens[request.email] = {
            "token": reset_token,
            "timestamp": datetime.now(),
            "username": user_found["username"]
        }
        
        # メールを送信
        if send_reset_email(request.email, reset_token):
            return {"message": "パスワードリセットメールを送信しました。メールをご確認ください。"}
        else:
            raise HTTPException(
                status_code=500,
                detail="メール送信に失敗しました。しばらくしてからもう一度お試しください。"
            )
            
    except Exception as e:
        logger.error(f"Password reset request failed: {e}")
        raise HTTPException(
            status_code=500,
            detail="パスワードリセットの処理に失敗しました。"
        )

@app.post("/password-reset-confirm", tags=["Authentication"])
async def confirm_password_reset(request: PasswordResetConfirm):
    """
    パスワードリセットトークンを確認し、新しいパスワードを設定する
    """
    try:
        # 期限切れトークンをクリーンアップ
        cleanup_expired_tokens()
        
        # トークンを検証
        token_info = None
        user_email = None
        
        for email, info in password_reset_tokens.items():
            if info["token"] == request.token:
                token_info = info
                user_email = email
                break
        
        if not token_info:
            raise HTTPException(
                status_code=400,
                detail="無効なリセットトークンです。もう一度リセットを要求してください。"
            )
        
        # トークンの有効期限を確認
        if datetime.now() - token_info["timestamp"] > timedelta(minutes=10):
            del password_reset_tokens[user_email]
            raise HTTPException(
                status_code=400,
                detail="リセットトークンの有効期限が切れています。もう一度リセットを要求してください。"
            )
        
        # パスワードを更新
        username = token_info["username"]
        if username not in auth.fake_users_db:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません。")
        
        # 新しいパスワードのハッシュ化
        new_password_hash = auth.get_password_hash(request.new_password)
        
        # データベースを更新
        auth.fake_users_db[username]["hashed_password"] = new_password_hash
        
        # 使用済みトークンを削除
        del password_reset_tokens[user_email]
        
        logger.info(f"Password reset completed for user: {username}")
        
        return {"message": "パスワードが正常に更新されました。新しいパスワードでログインしてください。"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Password reset confirm failed: {e}")
        raise HTTPException(
            status_code=500,
            detail="パスワードリセットの確認に失敗しました。"
        )

# --- 管理者専用エンドポイント ---

@app.get("/admin/users", tags=["Admin"])
async def get_all_users(admin_user: auth.User = Depends(auth.get_admin_user)):
    """
    管理者用：全ユーザー情報を取得する
    """
    users_list = []
    for username, user_data in auth.fake_users_db.items():
        # パスワードハッシュを除外して返す
        safe_user_data = {k: v for k, v in user_data.items() if k != 'hashed_password'}
        users_list.append(safe_user_data)
    
    return {
        "total_users": len(users_list),
        "users": users_list
    }

@app.put("/admin/users/{username}/subscription", tags=["Admin"])
async def update_user_subscription(
    username: str,
    subscription_data: dict,
    admin_user: auth.User = Depends(auth.get_admin_user)
):
    """
    管理者用：ユーザーのサブスクリプション情報を更新する
    """
    if username not in auth.fake_users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_data = auth.fake_users_db[username]
    
    # サブスクリプション情報を更新
    if "subscription_tier" in subscription_data:
        user_data["subscription_tier"] = subscription_data["subscription_tier"]
        user_data["role"] = subscription_data["subscription_tier"]  # roleも同期
    
    if "subscription_start" in subscription_data:
        user_data["subscription_start"] = subscription_data["subscription_start"]
    
    if "subscription_end" in subscription_data:
        user_data["subscription_end"] = subscription_data["subscription_end"]
    
    return {"message": f"User {username} subscription updated successfully"}

@app.get("/admin/analytics", tags=["Admin"])
async def get_analytics(admin_user: auth.User = Depends(auth.get_admin_user)):
    """
    管理者用：システム分析データを取得する
    """
    total_users = len(auth.fake_users_db)
    free_users = sum(1 for user_data in auth.fake_users_db.values() 
                    if user_data.get("subscription_tier") == "free")
    premium_users = sum(1 for user_data in auth.fake_users_db.values() 
                       if user_data.get("subscription_tier") == "premium")
    admin_users = sum(1 for user_data in auth.fake_users_db.values() 
                     if user_data.get("role") == "admin")
    
    return {
        "total_users": total_users,
        "free_users": free_users,
        "premium_users": premium_users,
        "admin_users": admin_users,
        "conversion_rate": (premium_users / total_users * 100) if total_users > 0 else 0,
        "timestamp": datetime.now().isoformat()
    }

@app.put("/admin/users/{username}/status", tags=["Admin"])
async def update_user_status(
    username: str,
    status_data: dict,
    admin_user: auth.User = Depends(auth.get_admin_user)
):
    """
    管理者用：ユーザーのアカウント状態（有効/無効）を更新する
    """
    if username not in auth.fake_users_db:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_data = auth.fake_users_db[username]
    
    if "disabled" in status_data:
        user_data["disabled"] = status_data["disabled"]
    
    return {"message": f"User {username} status updated successfully"}

# 購入検証システム
class PurchaseVerificationRequest(BaseModel):
    platform: str  # "ios" or "android"
    receipt_data: str  # Base64エンコードされたレシート
    transaction_id: str
    product_id: str
    purchase_token: str = None  # Android用

class PurchaseVerificationResponse(BaseModel):
    success: bool
    message: str
    subscription_expires_at: datetime = None
    subscription_active: bool = False

@app.post("/purchase/verify", tags=["Purchase"], response_model=PurchaseVerificationResponse)
async def verify_purchase(
    request: PurchaseVerificationRequest,
    current_user: auth.User = Depends(auth.get_current_user)
):
    """
    アプリ内課金の購入検証を行う
    """
    try:
        if request.platform == "ios":
            # App Store購入検証
            verification_result = await verify_app_store_receipt(request.receipt_data)
        elif request.platform == "android":
            # Google Play購入検証
            verification_result = await verify_google_play_purchase(
                request.product_id, 
                request.purchase_token
            )
        else:
            raise HTTPException(status_code=400, detail="Unsupported platform")
        
        if verification_result["success"]:
            # データベースでユーザーのサブスクリプション状態を更新
            await update_user_subscription(
                current_user.username,
                request.product_id,
                verification_result["expires_date"]
            )
            
            return PurchaseVerificationResponse(
                success=True,
                message="Purchase verified successfully",
                subscription_expires_at=verification_result["expires_date"],
                subscription_active=True
            )
        else:
            return PurchaseVerificationResponse(
                success=False,
                message=verification_result["message"]
            )
            
    except Exception as e:
        logger.error(f"Purchase verification error: {e}")
        return PurchaseVerificationResponse(
            success=False,
            message=f"Verification failed: {str(e)}"
        )

async def verify_app_store_receipt(receipt_data: str) -> dict:
    """
    App Storeのレシート検証
    """
    # App Store Connect API を使用した検証
    # 本番環境では実際のApp Store Server API を使用
    
    # テスト用のモック検証
    if receipt_data.startswith("test_"):
        return {
            "success": True,
            "expires_date": datetime.now() + timedelta(days=30),
            "message": "Test purchase verified"
        }
    
    # 実際の検証ロジック（本番環境で実装）
    # sandbox_url = "https://sandbox.itunes.apple.com/verifyReceipt"
    # production_url = "https://buy.itunes.apple.com/verifyReceipt"
    
    return {
        "success": False,
        "message": "Receipt verification not implemented"
    }

async def verify_google_play_purchase(product_id: str, purchase_token: str) -> dict:
    """
    Google Play の購入検証
    """
    # Google Play Developer API を使用した検証
    # 本番環境では実際のGoogle Play Developer API を使用
    
    # テスト用のモック検証
    if purchase_token.startswith("test_"):
        return {
            "success": True,
            "expires_date": datetime.now() + timedelta(days=30),
            "message": "Test purchase verified"
        }
    
    # 実際の検証ロジック（本番環境で実装）
    # Google Play Developer APIを使用
    
    return {
        "success": False,
        "message": "Google Play verification not implemented"
    }

async def update_user_subscription(username: str, product_id: str, expires_date: datetime):
    """
    ユーザーのサブスクリプション状態を更新
    """
    if username in auth.fake_users_db:
        user_data = auth.fake_users_db[username]
        user_data["subscription_tier"] = "premium"
        user_data["subscription_start"] = datetime.now().isoformat()
        user_data["subscription_end"] = expires_date.isoformat()
        
        logger.info(f"Updated subscription for user {username}, expires: {expires_date}")
    else:
        logger.error(f"User {username} not found for subscription update")

# --- 課金履歴管理エンドポイント ---

@app.get("/users/me/purchase-history", response_model=auth.PurchaseHistory, tags=["Purchase History"])
async def get_user_purchase_history(
    current_user: auth.User = Depends(auth.get_current_active_user)
):
    """
    現在のユーザーの課金履歴を取得
    """
    try:
        purchase_history = auth.get_purchase_history(current_user.username)
        return purchase_history
    except Exception as e:
        logger.error(f"Error getting purchase history for {current_user.username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve purchase history")

@app.get("/users/me/purchases", response_model=List[auth.PurchaseRecord], tags=["Purchase History"])
async def get_user_purchases(
    current_user: auth.User = Depends(auth.get_current_active_user)
):
    """
    現在のユーザーの課金記録一覧を取得
    """
    try:
        purchases = auth.get_user_purchases(current_user.username)
        return [auth.PurchaseRecord(**purchase) for purchase in purchases]
    except Exception as e:
        logger.error(f"Error getting purchases for {current_user.username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve purchases")

@app.post("/users/me/purchase", tags=["Purchase History"])
async def add_purchase_record(
    purchase_data: dict,
    current_user: auth.User = Depends(auth.get_current_active_user)
):
    """
    新しい課金記録を追加
    """
    try:
        # ユーザー名を自動設定
        purchase_data["username"] = current_user.username
        
        # 課金記録を追加
        success = auth.add_purchase_record(purchase_data)
        
        if success:
            return {"message": "Purchase record added successfully"}
        else:
            raise HTTPException(status_code=400, detail="Failed to add purchase record")
            
    except Exception as e:
        logger.error(f"Error adding purchase record for {current_user.username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to add purchase record")

# --- 管理者専用課金履歴エンドポイント ---

@app.get("/admin/purchases", tags=["Admin Purchase History"])
async def get_all_purchases(admin_user: auth.User = Depends(auth.get_admin_user)):
    """
    管理者用：全ユーザーの課金履歴を取得
    """
    try:
        all_purchases = []
        for username in auth.fake_purchases_db:
            user_purchases = auth.get_user_purchases(username)
            all_purchases.extend(user_purchases)
        
        return {
            "total_purchases": len(all_purchases),
            "purchases": [auth.PurchaseRecord(**purchase) for purchase in all_purchases]
        }
    except Exception as e:
        logger.error(f"Error getting all purchases: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve purchases")

@app.get("/admin/purchases/{username}", response_model=auth.PurchaseHistory, tags=["Admin Purchase History"])
async def get_user_purchase_history_admin(
    username: str,
    admin_user: auth.User = Depends(auth.get_admin_user)
):
    """
    管理者用：特定ユーザーの課金履歴を取得
    """
    try:
        purchase_history = auth.get_purchase_history(username)
        return purchase_history
    except Exception as e:
        logger.error(f"Error getting purchase history for {username}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve purchase history")

@app.get("/admin/analytics/revenue", tags=["Admin Analytics"])
async def get_revenue_analytics(admin_user: auth.User = Depends(auth.get_admin_user)):
    """
    管理者用：売上分析データを取得
    """
    try:
        total_revenue = 0
        monthly_revenue = 0
        completed_purchases = 0
        refunded_purchases = 0
        
        current_month = datetime.now().replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        for username in auth.fake_purchases_db:
            user_purchases = auth.get_user_purchases(username)
            
            for purchase in user_purchases:
                if purchase["status"] == "completed":
                    total_revenue += purchase["amount"]
                    completed_purchases += 1
                    
                    # 今月の売上を計算
                    purchase_date = purchase["purchase_date"]
                    if isinstance(purchase_date, str):
                        purchase_date = datetime.fromisoformat(purchase_date)
                    
                    if purchase_date >= current_month:
                        monthly_revenue += purchase["amount"]
                
                elif purchase["status"] == "refunded":
                    refunded_purchases += 1
        
        return {
            "total_revenue": total_revenue,
            "monthly_revenue": monthly_revenue,
            "completed_purchases": completed_purchases,
            "refunded_purchases": refunded_purchases,
            "average_revenue_per_purchase": total_revenue / completed_purchases if completed_purchases > 0 else 0,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Error getting revenue analytics: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve revenue analytics")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info") 