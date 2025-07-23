#!/usr/bin/env python3
"""
Gymnastics AI 簡易サーバー
FastAPI を使用した基本的なAPIサーバー
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import uvicorn
import jwt
import datetime
import hashlib
import json
import os

app = FastAPI(title="Gymnastics AI API", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 簡易データベース（実際の運用ではPostgreSQLを使用）
fake_db = {
    "users": {},
    "subscriptions": {},
    "routines": {},
    "chat_history": {}
}

SECRET_KEY = os.getenv("JWT_SECRET", "gymnastics-ai-secret-key-2024")

# データモデル
class UserSignup(BaseModel):
    username: str
    password: str
    email: str
    full_name: str

class UserLogin(BaseModel):
    username: str
    password: str

class PurchaseVerification(BaseModel):
    platform: str
    receipt_data: str
    transaction_id: str
    product_id: str
    purchase_token: Optional[str] = None

class ChatMessage(BaseModel):
    message: str
    conversation_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None

class RoutineData(BaseModel):
    name: str
    apparatus: str
    skills: List[Dict[str, Any]]
    connection_groups: List[List[int]]

class SocialAuthRequest(BaseModel):
    provider: str
    id_token: Optional[str] = None
    access_token: Optional[str] = None
    email: Optional[str] = None
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    user_identifier: Optional[str] = None

# ユーティリティ関数
def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def create_jwt_token(user_id: str) -> str:
    payload = {
        "user_id": user_id,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def verify_jwt_token(token: str) -> str:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload["user_id"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_user(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    
    token = authorization.split(" ")[1]
    user_id = verify_jwt_token(token)
    
    if user_id not in fake_db["users"]:
        raise HTTPException(status_code=401, detail="User not found")
    
    return fake_db["users"][user_id]

def get_daily_chat_limit(subscription_tier: str) -> int:
    """サブスクリプション層に基づくチャット制限回数を返す"""
    limits = {
        "guest": 3,
        "registered": 10, 
        "premium": 100,
        "pro": -1  # 無制限
    }
    return limits.get(subscription_tier, 3)

def get_user_daily_chat_count(user_id: str) -> int:
    """ユーザーの今日のチャット使用回数を返す（簡易実装）"""
    # 実際の実装では日付を考慮したカウントが必要
    return 0  # 簡易的に0を返す

async def generate_gymnastics_ai_response(message: str, conversation_id: str = None, context: dict = None) -> str:
    """体操AI応答生成（rulebook_ai.py統合）"""
    try:
        # rulebook_ai.pyをインポート
        from rulebook_ai import setup_vectorstore, create_conversational_chain
        
        # 日本語を優先的に検出
        is_japanese = any(ord(char) > 127 for char in message)
        lang = "ja" if is_japanese else "en"
        
        # ベクトルストアとチェーンを設定
        vectorstore = setup_vectorstore(lang)
        chain = create_conversational_chain(vectorstore, lang)
        
        # AI応答生成
        result = chain.invoke({"question": message})
        return result.get("answer", "申し訳ございませんが、応答の生成中にエラーが発生しました。")
        
    except ImportError:
        return f"体操AIより: {message}についてお答えします。現在システムメンテナンス中のため、基本的な回答のみ提供しています。"
    except Exception as e:
        print(f"AI Response Error: {e}")
        return "申し訳ございませんが、現在AIシステムが一時的に利用できません。しばらく経ってから再度お試しください。"

# APIエンドポイント

@app.get("/")
async def root():
    return {"message": "Gymnastics AI API Server", "version": "1.0.0", "status": "running"}

@app.get("/health")
async def health_check():
    """ヘルスチェックエンドポイント（Cloud Run用）"""
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.post("/signup")
async def signup(user_data: UserSignup):
    """ユーザー登録"""
    # ユーザー名の重複チェック
    for user_id, user in fake_db["users"].items():
        if user["username"] == user_data.username:
            raise HTTPException(status_code=400, detail="Username already exists")
    
    # 新しいユーザーを作成
    user_id = f"user_{len(fake_db['users']) + 1}"
    user = {
        "id": user_id,
        "username": user_data.username,
        "email": user_data.email,
        "full_name": user_data.full_name,
        "password_hash": hash_password(user_data.password),
        "subscription_tier": "registered",
        "subscription_start": None,
        "subscription_end": None,
        "created_at": datetime.datetime.utcnow().isoformat()
    }
    
    fake_db["users"][user_id] = user
    
    # JWTトークンを生成
    token = create_jwt_token(user_id)
    
    return {
        "access_token": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "subscription_tier": user["subscription_tier"],
            "subscription_start": user["subscription_start"],
            "subscription_end": user["subscription_end"]
        }
    }

@app.post("/login")
async def login(login_data: UserLogin):
    """ユーザーログイン"""
    # ユーザーを検索
    user = None
    user_id = None
    for uid, u in fake_db["users"].items():
        if u["username"] == login_data.username:
            user = u
            user_id = uid
            break
    
    if not user:
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    # パスワード確認
    if user["password_hash"] != hash_password(login_data.password):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    
    # JWTトークンを生成
    token = create_jwt_token(user_id)
    
    return {
        "access_token": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
            "subscription_tier": user["subscription_tier"],
            "subscription_start": user["subscription_start"],
            "subscription_end": user["subscription_end"]
        }
    }

@app.get("/users/me")
async def get_current_user_info(current_user = Depends(get_current_user)):
    """現在のユーザー情報取得"""
    return {
        "id": current_user["id"],
        "username": current_user["username"],
        "email": current_user["email"],
        "subscription_tier": current_user["subscription_tier"],
        "subscription_start": current_user["subscription_start"],
        "subscription_end": current_user["subscription_end"]
    }

@app.post("/purchase/verify")
async def verify_purchase(purchase_data: PurchaseVerification, current_user = Depends(get_current_user)):
    """購入検証（強化版）"""
    try:
        # プラットフォーム別の検証
        if purchase_data.platform == "ios":
            return await _verify_ios_purchase(purchase_data, current_user)
        elif purchase_data.platform == "android":
            return await _verify_android_purchase(purchase_data, current_user)
        else:
            return {"success": False, "message": "Unsupported platform"}
    
    except Exception as e:
        print(f"Purchase verification error: {e}")
        return {"success": False, "message": f"Verification failed: {str(e)}"}

async def _verify_ios_purchase(purchase_data: PurchaseVerification, current_user):
    """iOS購入の検証"""
    # 実際の運用では、App Store Server-to-Server APIを使用
    print(f"iOS purchase verification: {purchase_data.product_id}")
    
    # プロダクトID検証
    valid_ios_products = [
        "com.daito.gym.premium_monthly_subscription"
    ]
    
    if purchase_data.product_id not in valid_ios_products:
        return {"success": False, "message": "Invalid iOS product ID"}
    
    # レシートデータの基本検証（実際はApp Store APIで検証）
    if not purchase_data.receipt_data or len(purchase_data.receipt_data) < 10:
        return {"success": False, "message": "Invalid receipt data"}
    
    # トランザクションIDの重複チェック
    transaction_id = purchase_data.transaction_id
    
    # 既存の取引をチェック（実際はデータベースで）
    for user_id, user_data in fake_db["users"].items():
        validation_history = fake_db.get("validation_history", {}).get(user_id, [])
        for validation in validation_history:
            if validation.get("transaction_id") == transaction_id:
                return {"success": False, "message": "Transaction already processed"}
    
    # サブスクリプションを付与
    user_id = current_user["id"]
    current_user["subscription_tier"] = "premium"
    current_user["subscription_start"] = datetime.datetime.utcnow().isoformat()
    current_user["subscription_end"] = (datetime.datetime.utcnow() + datetime.timedelta(days=30)).isoformat()
    
    fake_db["users"][user_id] = current_user
    
    return {
        "success": True,
        "message": "iOS purchase verified successfully",
        "platform": "ios",
        "subscription": {
            "tier": "premium",
            "start_date": current_user["subscription_start"],
            "end_date": current_user["subscription_end"]
        }
    }

async def _verify_android_purchase(purchase_data: PurchaseVerification, current_user):
    """Android購入の検証（強化版）"""
    # 実際の運用では、Google Play Developer APIを使用
    print(f"Android purchase verification: {purchase_data.product_id}")
    
    # プロダクトID検証
    valid_android_products = [
        "premium_monthly_subscription"
    ]
    
    if purchase_data.product_id not in valid_android_products:
        return {"success": False, "message": "Invalid Android product ID"}
    
    # Purchase tokenの基本検証
    if not purchase_data.purchase_token or len(purchase_data.purchase_token) < 10:
        return {"success": False, "message": "Invalid purchase token"}
    
    # Purchase tokenの重複チェック（詐欺防止）
    user_id = current_user["id"]
    purchase_token = purchase_data.purchase_token
    
    # 既存の取引をチェック
    for existing_user_id, user_data in fake_db["users"].items():
        validation_history = fake_db.get("validation_history", {}).get(existing_user_id, [])
        for validation in validation_history:
            if validation.get("purchase_token") == purchase_token:
                return {"success": False, "message": "Purchase token already processed"}
    
    # Google Play形式の詳細検証（本番環境では実際のGoogle Play APIを使用）
    validation_result = _simulate_google_play_validation(purchase_data)
    
    if not validation_result["valid"]:
        return {"success": False, "message": f"Google Play validation failed: {validation_result['reason']}"}
    
    # サブスクリプションを付与
    subscription_duration = validation_result.get("subscription_duration_days", 30)
    current_user["subscription_tier"] = "premium"
    current_user["subscription_start"] = datetime.datetime.utcnow().isoformat()
    current_user["subscription_end"] = (datetime.datetime.utcnow() + datetime.timedelta(days=subscription_duration)).isoformat()
    
    fake_db["users"][user_id] = current_user
    
    # 検証履歴を保存
    if user_id not in fake_db.get("validation_history", {}):
        fake_db.setdefault("validation_history", {})[user_id] = []
    
    validation_metadata = {
        "platform": "android",
        "purchase_token": purchase_token,
        "transaction_id": purchase_data.transaction_id,
        "product_id": purchase_data.product_id,
        "validation_status": "verified",
        "order_id": validation_result.get("order_id"),
        "auto_renewing": validation_result.get("auto_renewing", True),
        "purchase_state": validation_result.get("purchase_state", 0),
        "last_validated": datetime.datetime.utcnow().isoformat()
    }
    
    fake_db["validation_history"][user_id].append(validation_metadata)
    
    return {
        "success": True,
        "message": "Android purchase verified successfully", 
        "platform": "android",
        "validation_details": validation_result,
        "subscription": {
            "tier": "premium",
            "start_date": current_user["subscription_start"],
            "end_date": current_user["subscription_end"]
        }
    }

def _simulate_google_play_validation(purchase_data: PurchaseVerification):
    """Google Play検証のシミュレーション（本番環境では実際のAPIを使用）"""
    # 基本的な検証ロジック
    purchase_token = purchase_data.purchase_token
    product_id = purchase_data.product_id
    
    # Purchase tokenの形式チェック（実際のGoogle Playトークンは特定の形式）
    if len(purchase_token) < 20:
        return {"valid": False, "reason": "Invalid purchase token format"}
    
    # プロダクトIDの検証
    if product_id not in ["premium_monthly_subscription"]:
        return {"valid": False, "reason": "Product ID not found"}
    
    # 正常な検証結果をシミュレート
    return {
        "valid": True,
        "purchase_state": 0,  # Purchased
        "auto_renewing": True,
        "order_id": f"GPA.{purchase_token[:12]}..{purchase_token[-8:]}",
        "subscription_duration_days": 30,
        "country_code": "JP",
        "price_currency_code": "JPY",
        "price_amount_micros": 500000000,  # 500円 in micros
        "expiry_time": (datetime.datetime.utcnow() + datetime.timedelta(days=30)).isoformat()
    }

@app.post("/purchase/sync-validation")
async def sync_purchase_validation(validation_data: dict, current_user = Depends(get_current_user)):
    """iOS購入検証結果の同期"""
    try:
        # 検証結果をユーザーレコードに保存
        user_id = current_user["id"]
        
        # サブスクリプション情報の更新
        if validation_data.get('expires_date'):
            current_user["subscription_end"] = validation_data['expires_date']
            current_user["subscription_tier"] = "premium"
            current_user["subscription_start"] = datetime.datetime.utcnow().isoformat()
        
        # 追加の検証メタデータを保存
        validation_metadata = {
            "platform": validation_data.get('platform'),
            "transaction_id": validation_data.get('transaction_id'),
            "original_transaction_id": validation_data.get('original_transaction_id'),
            "validation_status": validation_data.get('validation_status'),
            "auto_renew_status": validation_data.get('auto_renew_status'),
            "is_trial": validation_data.get('is_trial'),
            "last_validated": datetime.datetime.utcnow().isoformat()
        }
        
        # ユーザーレコードを更新
        fake_db["users"][user_id] = current_user
        
        # 検証履歴を保存（実際の運用ではデータベースに保存）
        if user_id not in fake_db.get("validation_history", {}):
            fake_db.setdefault("validation_history", {})[user_id] = []
        
        fake_db["validation_history"][user_id].append(validation_metadata)
        
        print(f"iOS validation synced for user {user_id}: {validation_data.get('transaction_id')}")
        
        return {
            "success": True,
            "message": "Validation synced successfully",
            "subscription_tier": current_user["subscription_tier"],
            "subscription_end": current_user["subscription_end"]
        }
        
    except Exception as e:
        print(f"Validation sync error: {e}")
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")

@app.post("/subscription/sync")
async def sync_subscription(current_user = Depends(get_current_user)):
    """サブスクリプション状態同期"""
    return {
        "subscription_tier": current_user["subscription_tier"],
        "subscription_start": current_user["subscription_start"],
        "subscription_end": current_user["subscription_end"],
        "is_active": current_user["subscription_tier"] == "premium" and 
                    current_user["subscription_end"] and
                    datetime.datetime.fromisoformat(current_user["subscription_end"]) > datetime.datetime.utcnow()
    }

@app.post("/subscription/realtime-sync")
async def realtime_sync_subscription(sync_data: dict, current_user = Depends(get_current_user)):
    """リアルタイムサブスクリプション同期"""
    try:
        local_state = sync_data.get("local_state", {})
        sync_type = sync_data.get("sync_type", "periodic")
        client_timestamp = sync_data.get("client_timestamp")
        
        print(f"Real-time sync request from user {current_user['id']}: {sync_type}")
        
        # 現在のサーバー状態を構築
        server_state = {
            "subscription_state": current_user["subscription_tier"],
            "subscription_tier": current_user["subscription_tier"],
            "expiry_date": current_user.get("subscription_end"),
            "is_active": current_user["subscription_tier"] == "premium" and 
                        current_user.get("subscription_end") and
                        datetime.datetime.fromisoformat(current_user["subscription_end"]) > datetime.datetime.utcnow(),
            "grace_period": False,  # 実際の実装では詳細チェック
            "billing_retry": False,
            "last_updated": datetime.datetime.utcnow().isoformat(),
            "server_timestamp": datetime.datetime.utcnow().isoformat(),
        }
        
        # 状態の差分チェック
        local_subscription_state = local_state.get("subscription_state", "unknown")
        server_subscription_state = server_state["subscription_state"]
        
        # 状態変化の検出
        state_changed = local_subscription_state != server_subscription_state
        
        if state_changed:
            print(f"State change detected: {local_subscription_state} -> {server_subscription_state}")
            server_state["state_changed"] = True
            server_state["previous_state"] = local_subscription_state
        
        # リモート設定の追加（オプション）
        server_state["remote_config"] = {
            "sync_interval": 900,  # 15分
            "heartbeat_interval": 300,  # 5分
            "feature_flags": {
                "enhanced_sync": True,
                "push_notifications": True
            }
        }
        
        # サーバーからの通知
        notifications = []
        
        # プレミアム期限が近い場合の通知
        if current_user.get("subscription_end"):
            expiry_date = datetime.datetime.fromisoformat(current_user["subscription_end"])
            days_until_expiry = (expiry_date - datetime.datetime.utcnow()).days
            
            if 0 < days_until_expiry <= 3:
                notifications.append({
                    "type": "subscription_expiring",
                    "message": f"プレミアムサブスクリプションが{days_until_expiry}日後に期限切れになります",
                    "action": "renewal_reminder"
                })
        
        if notifications:
            server_state["notifications"] = notifications
        
        # 同期履歴の記録
        user_id = current_user["id"]
        if "sync_history" not in fake_db:
            fake_db["sync_history"] = {}
        
        if user_id not in fake_db["sync_history"]:
            fake_db["sync_history"][user_id] = []
        
        sync_record = {
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "sync_type": sync_type,
            "client_timestamp": client_timestamp,
            "local_state": local_state,
            "server_state": server_state,
            "state_changed": state_changed
        }
        
        fake_db["sync_history"][user_id].append(sync_record)
        
        # 履歴の制限（最新の100件のみ保持）
        if len(fake_db["sync_history"][user_id]) > 100:
            fake_db["sync_history"][user_id] = fake_db["sync_history"][user_id][-100:]
        
        return {
            "success": True,
            "server_state": server_state,
            "sync_timestamp": datetime.datetime.utcnow().isoformat(),
            "state_changed": state_changed
        }
        
    except Exception as e:
        print(f"Real-time sync error: {e}")
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")

@app.post("/subscription/heartbeat")
async def subscription_heartbeat(heartbeat_data: dict, current_user = Depends(get_current_user)):
    """サブスクリプション同期ハートビート"""
    try:
        timestamp = heartbeat_data.get("timestamp")
        status = heartbeat_data.get("status", "unknown")
        
        # ハートビート情報の記録
        user_id = current_user["id"]
        
        if "heartbeats" not in fake_db:
            fake_db["heartbeats"] = {}
        
        fake_db["heartbeats"][user_id] = {
            "last_heartbeat": datetime.datetime.utcnow().isoformat(),
            "client_timestamp": timestamp,
            "status": status,
            "user_agent": "GymnasticsAI/1.3.0"
        }
        
        # シンプルなレスポンス
        return {
            "success": True,
            "server_timestamp": datetime.datetime.utcnow().isoformat(),
            "status": "alive"
        }
        
    except Exception as e:
        print(f"Heartbeat error: {e}")
        raise HTTPException(status_code=500, detail=f"Heartbeat failed: {str(e)}")

@app.get("/purchase/cross-device-sync")
async def cross_device_purchase_sync(current_user = Depends(get_current_user)):
    """デバイス間購入同期"""
    try:
        user_id = current_user["id"]
        
        # ユーザーの全購入履歴を取得
        validation_history = fake_db.get("validation_history", {}).get(user_id, [])
        
        purchases = []
        for validation in validation_history:
            if validation.get("validation_status") == "verified":
                purchases.append({
                    "product_id": validation.get("product_id"),
                    "platform": validation.get("platform"),
                    "expiration_date": current_user.get("subscription_end"),
                    "transaction_id": validation.get("transaction_id"),
                    "last_validated": validation.get("last_validated")
                })
        
        return {
            "success": True,
            "purchases": purchases,
            "sync_timestamp": datetime.datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        print(f"Cross-device sync error: {e}")
        raise HTTPException(status_code=500, detail=f"Cross-device sync failed: {str(e)}")

@app.post("/purchase/restore")
async def restore_purchases(restore_data: dict, current_user = Depends(get_current_user)):
    """購入復元処理"""
    try:
        platform = restore_data.get("platform")
        device_id = restore_data.get("device_id")
        user_id = current_user["id"]
        
        print(f"Purchase restoration request from user {user_id} on {platform}")
        
        # ユーザーの購入履歴を確認
        validation_history = fake_db.get("validation_history", {}).get(user_id, [])
        
        restored_purchases = []
        for validation in validation_history:
            if validation.get("validation_status") == "verified":
                # アクティブなサブスクリプションのチェック
                subscription_end = current_user.get("subscription_end")
                if subscription_end:
                    expiry_date = datetime.datetime.fromisoformat(subscription_end)
                    if expiry_date > datetime.datetime.utcnow():
                        restored_purchases.append({
                            "product_id": validation.get("product_id"),
                            "platform": validation.get("platform"),
                            "transaction_id": validation.get("transaction_id"),
                            "expiration_date": subscription_end,
                            "status": "restored"
                        })
        
        # 復元結果の記録
        restore_record = {
            "user_id": user_id,
            "platform": platform,
            "device_id": device_id,
            "restored_count": len(restored_purchases),
            "restore_timestamp": datetime.datetime.utcnow().isoformat()
        }
        
        if "restore_history" not in fake_db:
            fake_db["restore_history"] = []
        
        fake_db["restore_history"].append(restore_record)
        
        return {
            "success": True,
            "restored_purchases": restored_purchases,
            "message": f"Successfully restored {len(restored_purchases)} purchase(s)",
            "restore_timestamp": datetime.datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        print(f"Purchase restoration error: {e}")
        raise HTTPException(status_code=500, detail=f"Purchase restoration failed: {str(e)}")

@app.post("/chat/message")
async def send_chat_message(chat_data: ChatMessage, current_user = Depends(get_current_user)):
    """体操AI専用チャットメッセージ"""
    try:
        # 使用制限チェック
        daily_limit = get_daily_chat_limit(current_user["subscription_tier"])
        usage_count = get_user_daily_chat_count(current_user["id"])
        
        if daily_limit > 0 and usage_count >= daily_limit:
            raise HTTPException(status_code=429, detail="Daily chat limit exceeded")
        
        # AI応答生成（本番環境ではrulebook_ai.pyを統合）
        if os.getenv("OPENAI_API_KEY"):
            # 実際のAI応答（プロダクション環境）
            response_text = await generate_gymnastics_ai_response(
                chat_data.message, 
                chat_data.conversation_id,
                chat_data.context
            )
        else:
            # 開発環境用の擬似応答
            response_text = f"""体操AIコーチより:

質問「{chat_data.message}」について、以下のような観点からお答えできます：

🏅 **技術的アドバイス**: 技の習得方法や改善点
📋 **ルール解説**: FIG規則に基づく正確な情報
💪 **構成提案**: D-score向上のための演技構成
⚠️ **安全指導**: 怪我防止のための注意点

より詳細な情報が必要でしたら、具体的な種目や技名をお聞かせください。"""
        
        conversation_id = chat_data.conversation_id or f"conv_{len(fake_db['chat_history']) + 1}"
        
        # 使用回数を増加（簡易実装）
        # 実際の運用では、データベースに記録
        
        return {
            "response": response_text,
            "conversation_id": conversation_id,
            "usage_count": usage_count + 1,
            "remaining_count": max(0, daily_limit - usage_count - 1) if daily_limit > 0 else -1
        }
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail="AI chat service temporarily unavailable")

@app.get("/chat/conversations")
async def get_conversations(current_user = Depends(get_current_user)):
    """会話履歴取得"""
    return {
        "conversations": [
            {
                "id": "conv_1",
                "title": "体操技について",
                "created_at": datetime.datetime.utcnow().isoformat(),
                "last_message_at": datetime.datetime.utcnow().isoformat()
            }
        ]
    }

@app.post("/routines")
async def save_routine(routine_data: RoutineData, current_user = Depends(get_current_user)):
    """演技構成保存"""
    routine_id = f"routine_{len(fake_db['routines']) + 1}"
    
    routine = {
        "id": routine_id,
        "name": routine_data.name,
        "apparatus": routine_data.apparatus,
        "skills": routine_data.skills,
        "connection_groups": routine_data.connection_groups,
        "user_id": current_user["id"],
        "created_at": datetime.datetime.utcnow().isoformat()
    }
    
    fake_db["routines"][routine_id] = routine
    
    return {
        "id": routine_id,
        "name": routine_data.name,
        "created_at": routine["created_at"]
    }

@app.get("/routines")
async def get_routines(current_user = Depends(get_current_user)):
    """演技構成一覧取得"""
    user_routines = []
    for routine_id, routine in fake_db["routines"].items():
        if routine["user_id"] == current_user["id"]:
            user_routines.append({
                "id": routine["id"],
                "name": routine["name"],
                "apparatus": routine["apparatus"],
                "created_at": routine["created_at"],
                "d_score": 6.5  # 簡易的な値
            })
    
    return {"routines": user_routines}

@app.post("/auth/social")
async def social_authentication(auth_data: SocialAuthRequest):
    """ソーシャル認証処理"""
    try:
        # プロバイダー検証
        if auth_data.provider not in ["google", "apple"]:
            raise HTTPException(status_code=400, detail="Unsupported authentication provider")
        
        # 必要な情報の検証
        if not auth_data.email and not auth_data.user_identifier:
            raise HTTPException(status_code=400, detail="Email or user identifier is required")
        
        # ユーザー識別子の生成
        if auth_data.email:
            user_identifier = auth_data.email
        else:
            user_identifier = f"{auth_data.provider}_{auth_data.user_identifier}"
        
        # 既存ユーザーのチェック
        existing_user = None
        existing_user_id = None
        
        for uid, user in fake_db["users"].items():
            if (user.get("email") == auth_data.email or 
                user.get("social_identifier") == user_identifier):
                existing_user = user
                existing_user_id = uid
                break
        
        if existing_user:
            # 既存ユーザーのログイン
            # ソーシャル認証情報を更新
            existing_user["auth_provider"] = auth_data.provider
            existing_user["last_login"] = datetime.datetime.utcnow().isoformat()
            
            if auth_data.avatar_url:
                existing_user["avatar_url"] = auth_data.avatar_url
            
            fake_db["users"][existing_user_id] = existing_user
            
            # JWTトークンを生成
            token = create_jwt_token(existing_user_id)
            
            return {
                "success": True,
                "access_token": token,
                "user_id": existing_user["id"],
                "username": existing_user["username"],
                "email": existing_user["email"],
                "full_name": existing_user["full_name"],
                "avatar_url": existing_user.get("avatar_url"),
                "provider": auth_data.provider,
                "subscription_tier": existing_user["subscription_tier"],
                "subscription_start": existing_user.get("subscription_start"),
                "subscription_end": existing_user.get("subscription_end"),
                "message": "Successfully signed in with existing account"
            }
        else:
            # 新規ユーザーの作成
            user_id = f"social_{auth_data.provider}_{len(fake_db['users']) + 1}"
            
            # ユーザー名の生成（メールアドレスのローカル部分を使用）
            if auth_data.email:
                username = auth_data.email.split('@')[0]
            else:
                username = f"{auth_data.provider}_user_{len(fake_db['users']) + 1}"
            
            # ユーザー名の重複チェックと調整
            original_username = username
            counter = 1
            while any(user.get("username") == username for user in fake_db["users"].values()):
                username = f"{original_username}_{counter}"
                counter += 1
            
            new_user = {
                "id": user_id,
                "username": username,
                "email": auth_data.email or "",
                "full_name": auth_data.full_name or username,
                "auth_provider": auth_data.provider,
                "social_identifier": user_identifier,
                "avatar_url": auth_data.avatar_url,
                "subscription_tier": "registered",  # ソーシャル認証ユーザーは登録ユーザー扱い
                "subscription_start": None,
                "subscription_end": None,
                "created_at": datetime.datetime.utcnow().isoformat(),
                "last_login": datetime.datetime.utcnow().isoformat()
            }
            
            fake_db["users"][user_id] = new_user
            
            # JWTトークンを生成
            token = create_jwt_token(user_id)
            
            return {
                "success": True,
                "access_token": token,
                "user_id": new_user["id"],
                "username": new_user["username"],
                "email": new_user["email"],
                "full_name": new_user["full_name"],
                "avatar_url": new_user.get("avatar_url"),
                "provider": auth_data.provider,
                "subscription_tier": new_user["subscription_tier"],
                "subscription_start": new_user.get("subscription_start"),
                "subscription_end": new_user.get("subscription_end"),
                "message": "Successfully created new account with social authentication"
            }
            
    except Exception as e:
        print(f"Social authentication error: {e}")
        raise HTTPException(status_code=500, detail=f"Authentication failed: {str(e)}")

@app.post("/auth/social/link")
async def link_social_account(auth_data: SocialAuthRequest, current_user = Depends(get_current_user)):
    """既存アカウントにソーシャル認証をリンク"""
    try:
        user_id = current_user["id"]
        
        # ソーシャル認証情報を既存アカウントに追加
        current_user["auth_provider"] = auth_data.provider
        current_user["social_identifier"] = auth_data.email or f"{auth_data.provider}_{auth_data.user_identifier}"
        
        if auth_data.avatar_url:
            current_user["avatar_url"] = auth_data.avatar_url
        
        fake_db["users"][user_id] = current_user
        
        return {
            "success": True,
            "message": f"{auth_data.provider}アカウントが正常にリンクされました",
            "linked_provider": auth_data.provider
        }
        
    except Exception as e:
        print(f"Social account linking error: {e}")
        raise HTTPException(status_code=500, detail=f"Account linking failed: {str(e)}")

@app.post("/auth/social/unlink")
async def unlink_social_account(provider_data: dict, current_user = Depends(get_current_user)):
    """ソーシャル認証のリンクを解除"""
    try:
        user_id = current_user["id"]
        provider = provider_data.get("provider")
        
        if current_user.get("auth_provider") == provider:
            # ソーシャル認証情報を削除
            current_user["auth_provider"] = None
            current_user["social_identifier"] = None
            current_user.pop("avatar_url", None)
            
            fake_db["users"][user_id] = current_user
            
            return {
                "success": True,
                "message": f"{provider}アカウントのリンクが解除されました"
            }
        else:
            return {
                "success": False,
                "message": "指定されたプロバイダーはリンクされていません"
            }
            
    except Exception as e:
        print(f"Social account unlinking error: {e}")
        raise HTTPException(status_code=500, detail=f"Account unlinking failed: {str(e)}")

def create_test_accounts():
    """テスト用アカウントを作成"""
    # 無料ユーザーのテストアカウント
    free_user_id = "test_free_001"
    if free_user_id not in fake_db["users"]:
        fake_db["users"][free_user_id] = {
            "id": free_user_id,
            "username": "freeuser",
            "email": "freeuser@test.com",
            "full_name": "Free Test User",
            "password_hash": hash_password("test123"),
            "subscription_tier": "registered",
            "subscription_start": None,
            "subscription_end": None,
            "created_at": datetime.datetime.utcnow().isoformat()
        }
        print("✅ Created test account: freeuser (password: test123)")
    
    # プレミアムユーザーのテストアカウント
    premium_user_id = "test_premium_001"
    if premium_user_id not in fake_db["users"]:
        fake_db["users"][premium_user_id] = {
            "id": premium_user_id,
            "username": "premiumuser",
            "email": "premiumuser@test.com",
            "full_name": "Premium Test User",
            "password_hash": hash_password("test123"),
            "subscription_tier": "premium",
            "subscription_start": datetime.datetime.utcnow().isoformat(),
            "subscription_end": (datetime.datetime.utcnow() + datetime.timedelta(days=30)).isoformat(),
            "created_at": datetime.datetime.utcnow().isoformat()
        }
        print("✅ Created test account: premiumuser (password: test123)")

if __name__ == "__main__":
    print("Starting Gymnastics AI API Server...")
    print("Server will be available at: http://localhost:8000")
    print("API Documentation: http://localhost:8000/docs")
    
    # テストアカウントを作成
    create_test_accounts()
    
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )