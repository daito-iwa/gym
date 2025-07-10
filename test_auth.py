#!/usr/bin/env python3
"""
認証システムのテストコード
FastAPI 認証機能の動作を確認するためのテストスイート
"""

import pytest
import os
import sys
from fastapi.testclient import TestClient
from datetime import datetime, timedelta
import json

# プロジェクトのルートディレクトリをパスに追加
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# テスト用に環境変数を設定
os.environ["SECRET_KEY"] = "test-secret-key-for-testing-only"
os.environ["ACCESS_TOKEN_EXPIRE_MINUTES"] = "30"

import auth
from api import app

# テストクライアントの作成
client = TestClient(app)

class TestAuthentication:
    """認証システムのテストクラス"""
    
    def setup_method(self):
        """各テストメソッドの前に実行される"""
        # テスト用ユーザーデータをクリア
        auth.fake_users_db.clear()
        
    def test_signup_success(self):
        """正常なユーザー登録のテスト"""
        response = client.post("/signup", json={
            "username": "testuser",
            "password": "testpass123",
            "email": "test@example.com",
            "full_name": "Test User"
        })
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        assert data["email"] == "test@example.com"
        assert data["full_name"] == "Test User"
        assert "hashed_password" not in data  # パスワードは返されない
        
    def test_signup_duplicate_username(self):
        """重複するユーザー名での登録エラーテスト"""
        # 最初のユーザー登録
        client.post("/signup", json={
            "username": "testuser",
            "password": "testpass123",
            "email": "test@example.com",
            "full_name": "Test User"
        })
        
        # 同じユーザー名で再度登録
        response = client.post("/signup", json={
            "username": "testuser",
            "password": "anotherpass123",
            "email": "another@example.com",
            "full_name": "Another User"
        })
        assert response.status_code == 400
        assert "Username already registered" in response.json()["detail"]
        
    def test_login_success(self):
        """正常なログインのテスト"""
        # ユーザー登録
        client.post("/signup", json={
            "username": "testuser",
            "password": "testpass123",
            "email": "test@example.com",
            "full_name": "Test User"
        })
        
        # ログイン
        response = client.post("/token", data={
            "username": "testuser",
            "password": "testpass123"
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        
    def test_login_invalid_credentials(self):
        """無効な認証情報でのログインエラーテスト"""
        response = client.post("/token", data={
            "username": "nonexistent",
            "password": "wrongpassword"
        })
        assert response.status_code == 401
        assert "Incorrect username or password" in response.json()["detail"]
        
    def test_protected_endpoint_without_token(self):
        """認証が必要なエンドポイントへのトークンなしアクセステスト"""
        response = client.post("/chat", json={
            "session_id": "test-session",
            "question": "test question",
            "lang": "ja"
        })
        assert response.status_code == 401
        
    def test_protected_endpoint_with_valid_token(self):
        """認証が必要なエンドポイントへの有効なトークンでのアクセステスト"""
        # ユーザー登録
        client.post("/signup", json={
            "username": "testuser",
            "password": "testpass123",
            "email": "test@example.com",
            "full_name": "Test User"
        })
        
        # ログイン
        login_response = client.post("/token", data={
            "username": "testuser",
            "password": "testpass123"
        })
        token = login_response.json()["access_token"]
        
        # 認証が必要なエンドポイントにアクセス
        response = client.get("/users/me", headers={
            "Authorization": f"Bearer {token}"
        })
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "testuser"
        
    def test_protected_endpoint_with_invalid_token(self):
        """無効なトークンでのアクセステスト"""
        response = client.get("/users/me", headers={
            "Authorization": "Bearer invalid-token"
        })
        assert response.status_code == 401
        
    def test_password_hashing(self):
        """パスワードハッシュ化の動作テスト"""
        password = "testpassword123"
        hashed = auth.get_password_hash(password)
        
        # パスワードとハッシュが異なることを確認
        assert password != hashed
        
        # ハッシュ化されたパスワードの検証
        assert auth.verify_password(password, hashed) == True
        assert auth.verify_password("wrongpassword", hashed) == False
        
    def test_token_creation_and_validation(self):
        """JWTトークン生成と検証のテスト"""
        # トークン生成
        token_data = {"sub": "testuser"}
        token = auth.create_access_token(token_data)
        
        # トークンが生成されていることを確認
        assert isinstance(token, str)
        assert len(token) > 0
        
        # トークンの検証（実際の検証はauth.get_current_userで行われる）
        from jose import jwt
        payload = jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        assert payload["sub"] == "testuser"
        assert "exp" in payload  # 有効期限が設定されている

class TestAuthenticationFlow:
    """認証フローの統合テスト"""
    
    def setup_method(self):
        """各テストメソッドの前に実行される"""
        auth.fake_users_db.clear()
        
    def test_complete_authentication_flow(self):
        """完全な認証フローのテスト"""
        # 1. ユーザー登録
        signup_response = client.post("/signup", json={
            "username": "flowtest",
            "password": "flowpass123",
            "email": "flow@example.com",
            "full_name": "Flow Test User"
        })
        assert signup_response.status_code == 200
        
        # 2. ログイン
        login_response = client.post("/token", data={
            "username": "flowtest",
            "password": "flowpass123"
        })
        assert login_response.status_code == 200
        token = login_response.json()["access_token"]
        
        # 3. 認証が必要なエンドポイントにアクセス
        protected_response = client.get("/users/me", headers={
            "Authorization": f"Bearer {token}"
        })
        assert protected_response.status_code == 200
        user_data = protected_response.json()
        assert user_data["username"] == "flowtest"
        assert user_data["email"] == "flow@example.com"
        
if __name__ == "__main__":
    """テストの実行"""
    print("認証システムのテストを実行中...")
    print("=" * 50)
    
    # 簡単なテストケース実行
    test_auth = TestAuthentication()
    test_flow = TestAuthenticationFlow()
    
    try:
        # セットアップ
        test_auth.setup_method()
        print("✓ ユーザー登録テスト開始")
        test_auth.test_signup_success()
        print("✓ 正常なユーザー登録テスト: 成功")
        
        test_auth.setup_method()
        test_auth.test_signup_duplicate_username()
        print("✓ 重複ユーザー名テスト: 成功")
        
        test_auth.setup_method()
        test_auth.test_login_success()
        print("✓ 正常なログインテスト: 成功")
        
        test_auth.setup_method()
        test_auth.test_login_invalid_credentials()
        print("✓ 無効な認証情報テスト: 成功")
        
        test_auth.setup_method()
        test_auth.test_password_hashing()
        print("✓ パスワードハッシュ化テスト: 成功")
        
        test_auth.setup_method()
        test_auth.test_token_creation_and_validation()
        print("✓ トークン生成・検証テスト: 成功")
        
        test_flow.setup_method()
        test_flow.test_complete_authentication_flow()
        print("✓ 完全な認証フローテスト: 成功")
        
        print("=" * 50)
        print("🎉 全てのテストが成功しました！")
        
    except Exception as e:
        print(f"❌ テストエラー: {e}")
        import traceback
        traceback.print_exc()