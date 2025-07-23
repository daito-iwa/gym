# 🧪 最終リリーステストガイド

## 📋 本番環境テスト項目

### 1. 🌐 Webアプリケーションテスト

#### 基本機能テスト
```bash
# テストURL例: https://app.gymnastics-ai.com

✅ テスト項目:
□ アプリ起動・初期表示
□ レスポンシブデザイン (PC/タブレット/モバイル)  
□ 各種目の技選択・表示
□ Dスコア計算の正確性
□ 結果の保存・読み込み
□ オフライン動作確認
```

#### 認証機能テスト
```bash
□ 新規ユーザー登録
□ メールアドレス認証  
□ ログイン・ログアウト
□ Google Sign-In動作
□ Apple Sign-In動作 (iOS Safari)
□ パスワードリセット機能
□ セッション管理・自動ログアウト
```

#### AI機能テスト  
```bash
□ AIチャット基本動作
□ 体操ルール質問応答
□ 技の組み合わせ提案
□ 日本語・英語切り替え
□ レスポンス時間 (< 10秒)
□ エラーハンドリング
□ 使用制限 (無料ユーザー: 5回/日)
```

#### プレミアム機能テスト
```bash  
□ プレミアムアップグレード画面
□ 決済処理 (テストカード)
□ サブスクリプション管理
□ プレミアム機能解除 (無制限AI等)
□ 解約処理
□ 日割り計算確認
```

### 2. 📱 モバイルアプリテスト

#### iOS アプリ
```bash
# TestFlightベータ版テスト
□ App Store Connect アップロード
□ TestFlightビルド処理
□ ベータテスター招待
□ インストール・起動確認
□ プッシュ通知動作  
□ Face ID/Touch ID認証
□ In-App Purchase動作
□ バックグラウンド動作
```

#### Android アプリ
```bash  
# Play Console内部テスト
□ Google Play Console アップロード
□ 内部テストトラック配信
□ インストール・起動確認
□ 生体認証動作
□ Google Play 課金動作
□ バックグラウンド動作
□ Android各バージョン対応
```

### 3. 🔧 バックエンドAPIテスト

#### API エンドポイントテスト
```python
# api_test.py
import requests
import json

BASE_URL = "https://api.gymnastics-ai.com"

def test_health_check():
    """ヘルスチェック"""
    response = requests.get(f"{BASE_URL}/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"

def test_authentication():
    """認証テスト"""
    # ユーザー登録
    register_data = {
        "username": "test_user_001",
        "email": "test@example.com", 
        "password": "TestPassword123!"
    }
    response = requests.post(f"{BASE_URL}/signup", json=register_data)
    assert response.status_code == 200
    
    # ログイン
    login_data = {
        "username": "test_user_001",
        "password": "TestPassword123!"
    }
    response = requests.post(f"{BASE_URL}/token", data=login_data)
    assert response.status_code == 200
    token = response.json()["access_token"]
    
    return token

def test_ai_chat(token):
    """AIチャット機能テスト"""
    headers = {"Authorization": f"Bearer {token}"}
    chat_data = {
        "session_id": "test-session-001",
        "question": "床運動の終末技について教えて",
        "lang": "ja"
    }
    
    response = requests.post(f"{BASE_URL}/chat", json=chat_data, headers=headers)
    assert response.status_code == 200
    assert "answer" in response.json()
    assert len(response.json()["answer"]) > 10

def test_d_score_calculation(token):
    """Dスコア計算テスト"""
    headers = {"Authorization": f"Bearer {token}"}
    calc_data = {
        "skills": [
            {"id": "1", "value": 0.4},
            {"id": "2", "value": 0.5}, 
            {"id": "3", "value": 0.6}
        ]
    }
    
    response = requests.post(f"{BASE_URL}/calculate_d_score/fx", json=calc_data, headers=headers)
    assert response.status_code == 200
    assert "d_score" in response.json()

# テスト実行
if __name__ == "__main__":
    print("🧪 API テスト開始...")
    test_health_check()
    print("✅ ヘルスチェック OK")
    
    token = test_authentication()
    print("✅ 認証テスト OK") 
    
    test_ai_chat(token)
    print("✅ AIチャットテスト OK")
    
    test_d_score_calculation(token)
    print("✅ Dスコア計算テスト OK")
    
    print("🎉 全テスト完了!")
```

### 4. 🚀 パフォーマンステスト

#### ロードテスト
```python
# load_test.py
import concurrent.futures
import requests
import time

def load_test():
    """負荷テスト"""
    BASE_URL = "https://api.gymnastics-ai.com"
    
    def single_request():
        start_time = time.time()
        response = requests.get(f"{BASE_URL}/")
        end_time = time.time()
        return response.status_code, end_time - start_time
    
    # 50並行リクエスト
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as executor:
        futures = [executor.submit(single_request) for _ in range(100)]
        results = [future.result() for future in futures]
    
    # 結果分析
    success_count = len([r for r in results if r[0] == 200])
    avg_response_time = sum([r[1] for r in results]) / len(results)
    
    print(f"成功率: {success_count/len(results)*100:.1f}%")
    print(f"平均応答時間: {avg_response_time:.3f}秒")
    
    # 基準値チェック
    assert success_count/len(results) > 0.99  # 99%以上成功
    assert avg_response_time < 2.0  # 2秒以内

if __name__ == "__main__":
    load_test()
```

### 5. 🔒 セキュリティテスト

#### 基本セキュリティチェック
```bash
□ HTTPS強制リダイレクト
□ セキュリティヘッダー設定確認
□ API認証必須エンドポイント確認  
□ SQLインジェクション対策確認
□ XSS対策確認
□ CSRF対策確認
□ 機密情報ログ出力なし確認
□ APIレート制限動作確認
```

#### SSL/TLS設定確認
```bash
# SSL Labs テスト
curl https://www.ssllabs.com/ssltest/analyze.html?d=api.gymnastics-ai.com

# 期待結果: A+評価
□ TLS 1.2/1.3対応
□ 強力な暗号化スイート
□ HSTS設定
□ セキュリティヘッダー
```

### 6. 📊 分析・監視テスト

#### Analytics動作確認
```bash
□ Firebase Analytics イベント送信
□ カスタムイベント動作 (d_score_calculation等)
□ ユーザー行動分析データ
□ コンバージョン追跡
□ リアルタイムユーザー数
□ エラー追跡・アラート
```

#### 監視システム確認
```bash
□ Cloud Monitoring ダッシュボード
□ アラート通知設定 (Slack/Email)
□ ログ集約・検索
□ パフォーマンス指標
□ 可用性監視
```

## 🎯 テスト自動化スクリプト

### E2E テストスクリプト
```bash
#!/bin/bash
# e2e_test.sh

echo "🧪 Gymnastics AI E2E テスト開始..."

# 1. Web アプリテスト  
echo "📱 Webアプリテスト..."
cd test/e2e
npm test

# 2. API テスト
echo "🔌 API テスト..."
python3 api_test.py

# 3. 負荷テスト
echo "⚡ 負荷テスト..."
python3 load_test.py

# 4. セキュリティテスト
echo "🔒 セキュリティテスト..."  
nmap -sV --script ssl-enum-ciphers api.gymnastics-ai.com

# 5. モバイルアプリテスト (Appium)
echo "📱 モバイルアプリテスト..."
python3 mobile_test.py

echo "✅ E2Eテスト完了!"
```

### テスト結果レポート生成
```python
# test_report.py
import json
from datetime import datetime

def generate_test_report(test_results):
    """テスト結果レポート生成"""
    report = {
        "test_date": datetime.now().isoformat(),
        "environment": "production",
        "summary": {
            "total_tests": len(test_results),
            "passed": len([t for t in test_results if t["status"] == "passed"]),
            "failed": len([t for t in test_results if t["status"] == "failed"]),
        },
        "details": test_results
    }
    
    # JSON出力
    with open("test_report.json", "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    # Markdown出力
    with open("test_report.md", "w") as f:
        f.write("# 🧪 Gymnastics AI テスト結果\n\n")
        f.write(f"**実施日時:** {report['test_date']}\n\n")
        f.write(f"**成功率:** {report['summary']['passed']}/{report['summary']['total']} ({report['summary']['passed']/report['summary']['total']*100:.1f}%)\n\n")
        
        for test in test_results:
            status_icon = "✅" if test["status"] == "passed" else "❌"
            f.write(f"{status_icon} {test['name']}: {test['status']}\n")
```

## ✅ リリース承認基準

### 必須条件 (全て✅が必要)
- [ ] 全E2Eテストpass (95%以上)
- [ ] API応答時間 < 3秒
- [ ] SSL Labs評価 A以上
- [ ] セキュリティテスト全pass
- [ ] iOS/Android テストアプリ正常動作

### 推奨条件
- [ ] 負荷テスト100並行pass
- [ ] Analytics正常動作
- [ ] 監視・アラート動作確認
- [ ] ドキュメント最新化
- [ ] バックアップ・復旧テスト

---

**リリース判定:** 全必須条件クリア時に本番リリース実行可能 ✅