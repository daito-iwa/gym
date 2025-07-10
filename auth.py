import os
import time
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, Field

# --- 設定 ---
# セキュリティ強化: 環境変数から読み込み、フォールバック値を強化
SECRET_KEY = os.getenv("SECRET_KEY", "gym-d-score-jwt-secret-key-development-only-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# パスワードのハッシュ化コンテキスト
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2の認証スキーム
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- Pydanticモデル ---

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    disabled: Optional[bool] = None
    subscription_tier: Optional[str] = "free"
    subscription_start: Optional[str] = None
    subscription_end: Optional[str] = None
    role: Optional[str] = "free"

class UserInDB(User):
    hashed_password: str

class PurchaseRecord(BaseModel):
    id: str
    username: str
    product_id: str
    transaction_id: str
    purchase_date: datetime
    amount: float
    currency: str = "JPY"
    platform: str  # "ios" or "android"
    status: str = "completed"  # "completed", "pending", "cancelled", "refunded"
    receipt_data: Optional[str] = None
    
class PurchaseHistory(BaseModel):
    username: str
    purchases: List[PurchaseRecord]
    total_spent: float
    subscription_status: str
    next_billing_date: Optional[datetime] = None

# --- データベースの代わり (インメモリ) ---
# 本番環境では実際のデータベースに置き換えること
fake_users_db: Dict[str, Dict[str, Any]] = {}
fake_purchases_db: Dict[str, List[Dict[str, Any]]] = {}  # username -> [purchase_records]

# テスト用ユーザーを初期化する関数
def initialize_test_users():
    """テスト用のユーザーアカウントを初期化"""
    global fake_users_db
    fake_users_db.update({
        "testuser": {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "hashed_password": get_password_hash("test123"),
            "disabled": False,
            "subscription_tier": "free",
            "subscription_start": None,
            "subscription_end": None,
            "role": "free",
        },
        "freeuser": {
            "username": "freeuser",
            "email": "free@example.com", 
            "full_name": "Free User",
            "hashed_password": get_password_hash("free123"),
            "disabled": False,
            "subscription_tier": "free",
            "subscription_start": None,
            "subscription_end": None,
            "role": "free",
        },
        "premiumuser": {
            "username": "premiumuser",
            "email": "premium@example.com",
            "full_name": "Premium User", 
            "hashed_password": get_password_hash("premium123"),
            "disabled": False,
            "subscription_tier": "premium",
            "subscription_start": "2025-01-01",
            "subscription_end": "2025-12-31",
            "role": "premium",
        },
        "admin": {
            "username": "admin",
            "email": "admin@daito.gym",
            "full_name": "Administrator", 
            "hashed_password": get_password_hash("admin123"),
            "disabled": False,
            "subscription_tier": "premium",
            "subscription_start": "2025-01-01",
            "subscription_end": "2030-12-31",
            "role": "admin",
        }
    })
    
    # 課金履歴のテストデータを初期化
    initialize_test_purchases()

def initialize_test_purchases():
    """テスト用課金履歴データを初期化"""
    global fake_purchases_db
    
    # テスト用課金履歴データを作成
    test_purchases = [
        {
            "id": "purchase_001",
            "username": "premiumuser",
            "product_id": "gym_premium_monthly",
            "transaction_id": "txn_001_2025_01_01",
            "purchase_date": datetime(2025, 1, 1, 10, 0, 0),
            "amount": 500.0,
            "currency": "JPY",
            "platform": "ios",
            "status": "completed",
            "receipt_data": "mock_receipt_data_001"
        },
        {
            "id": "purchase_002",
            "username": "premiumuser",
            "product_id": "gym_premium_monthly",
            "transaction_id": "txn_002_2025_02_01",
            "purchase_date": datetime(2025, 2, 1, 10, 0, 0),
            "amount": 500.0,
            "currency": "JPY",
            "platform": "ios",
            "status": "completed",
            "receipt_data": "mock_receipt_data_002"
        },
        {
            "id": "purchase_003",
            "username": "admin",
            "product_id": "gym_premium_monthly",
            "transaction_id": "txn_003_2025_01_15",
            "purchase_date": datetime(2025, 1, 15, 14, 30, 0),
            "amount": 500.0,
            "currency": "JPY",
            "platform": "android",
            "status": "completed",
            "receipt_data": "mock_receipt_data_003"
        },
        {
            "id": "purchase_004",
            "username": "testuser",
            "product_id": "gym_premium_monthly",
            "transaction_id": "txn_004_2025_01_20",
            "purchase_date": datetime(2025, 1, 20, 16, 45, 0),
            "amount": 500.0,
            "currency": "JPY",
            "platform": "ios",
            "status": "refunded",
            "receipt_data": "mock_receipt_data_004"
        }
    ]
    
    # ユーザーごとに課金履歴を整理
    fake_purchases_db.clear()
    for purchase in test_purchases:
        username = purchase["username"]
        if username not in fake_purchases_db:
            fake_purchases_db[username] = []
        fake_purchases_db[username].append(purchase)

def get_user_purchases(username: str) -> List[Dict[str, Any]]:
    """ユーザーの課金履歴を取得"""
    return fake_purchases_db.get(username, [])

def get_purchase_history(username: str) -> PurchaseHistory:
    """ユーザーの課金履歴サマリーを取得"""
    purchases = get_user_purchases(username)
    
    # 完了した課金の合計金額を計算
    total_spent = sum(
        purchase["amount"] for purchase in purchases 
        if purchase["status"] == "completed"
    )
    
    # サブスクリプションステータスを判定
    active_purchases = [
        p for p in purchases 
        if p["status"] == "completed" and p["product_id"] == "gym_premium_monthly"
    ]
    
    if active_purchases:
        # 最新の課金日から次の課金日を計算
        latest_purchase = max(active_purchases, key=lambda x: x["purchase_date"])
        next_billing_date = latest_purchase["purchase_date"] + timedelta(days=30)
        subscription_status = "active"
    else:
        next_billing_date = None
        subscription_status = "inactive"
    
    return PurchaseHistory(
        username=username,
        purchases=[PurchaseRecord(**purchase) for purchase in purchases],
        total_spent=total_spent,
        subscription_status=subscription_status,
        next_billing_date=next_billing_date
    )

def add_purchase_record(purchase_data: Dict[str, Any]) -> bool:
    """新しい課金レコードを追加"""
    try:
        username = purchase_data["username"]
        
        # 課金レコードを作成
        purchase_record = {
            "id": purchase_data.get("id", f"purchase_{int(time.time())}"),
            "username": username,
            "product_id": purchase_data["product_id"],
            "transaction_id": purchase_data["transaction_id"],
            "purchase_date": purchase_data.get("purchase_date", datetime.now()),
            "amount": purchase_data["amount"],
            "currency": purchase_data.get("currency", "JPY"),
            "platform": purchase_data["platform"],
            "status": purchase_data.get("status", "completed"),
            "receipt_data": purchase_data.get("receipt_data")
        }
        
        # データベースに追加
        if username not in fake_purchases_db:
            fake_purchases_db[username] = []
        
        fake_purchases_db[username].append(purchase_record)
        return True
        
    except Exception:
        return False

def get_user(db: Dict[str, Dict[str, Any]], username: str) -> Optional[UserInDB]:
    if username in db:
        user_dict = db[username]
        return UserInDB(**user_dict)
    return None

# --- パスワード関連 ---

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """平文パスワードとハッシュ化されたパスワードを比較する"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """パスワードをハッシュ化する"""
    return pwd_context.hash(password)

# --- JWTトークン関連 ---

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """アクセストークンを生成する"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- 認証済みユーザー取得 ---

async def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    """トークンを検証し、現在のユーザー情報を返す"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    
    user = get_user(fake_users_db, username=token_data.username)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)) -> User:
    """無効化されていないアクティブなユーザーかチェックする"""
    if current_user.disabled:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

async def get_admin_user(current_user: User = Depends(get_current_active_user)) -> User:
    """管理者権限を持つユーザーかチェックする"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required"
        )
    return current_user 