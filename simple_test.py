#!/usr/bin/env python3
"""
体操アプリの簡単自動テスト
既に開いているChromeブラウザでテストを実行
"""

import time
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

def test_apis():
    """APIの基本動作テスト"""
    print("🔍 API動作テスト開始...")
    
    # ヘルスチェック
    try:
        response = requests.get("http://localhost:8000/")
        print(f"✅ ヘルスチェック: {response.json()}")
    except Exception as e:
        print(f"❌ ヘルスチェック失敗: {e}")
        return False
    
    # チャットAPI テスト
    try:
        chat_data = {
            "session_id": "test_session",
            "question": "テストメッセージです",
            "lang": "ja"
        }
        response = requests.post("http://localhost:8000/chat", json=chat_data)
        result = response.json()
        print(f"✅ チャットAPI: {result['answer'][:50]}...")
    except Exception as e:
        print(f"❌ チャットAPI失敗: {e}")
    
    # 技データ取得テスト
    try:
        response = requests.get("http://localhost:8000/skills/ja/FX")
        skills = response.json()
        print(f"✅ 技データ取得: {len(skills)}件の技データ")
    except Exception as e:
        print(f"❌ 技データ取得失敗: {e}")
    
    # Dスコア計算テスト
    try:
        routine_data = {
            "routine": [[{
                "id": "FX001",
                "name": "Sample Floor Skill A", 
                "group": 1,
                "value_letter": "A",
                "description": "Test skill",
                "apparatus": "FX",
                "value": 0.1
            }]]
        }
        response = requests.post("http://localhost:8000/calculate_d_score/FX", json=routine_data)
        result = response.json()
        print(f"✅ Dスコア計算: {result['d_score']}")
    except Exception as e:
        print(f"❌ Dスコア計算失敗: {e}")
    
    return True

def automated_browser_test():
    """ブラウザ自動操作テスト"""
    print("\n🌐 ブラウザ自動操作テスト開始...")
    
    options = Options()
    options.add_argument("--remote-debugging-port=9222")
    
    driver = None
    try:
        # 新しいChromeウィンドウを起動
        driver = webdriver.Chrome(options=options)
        
        # Flutter Webアプリを開く
        # 現在動作中のlocalhost URLを試行
        test_urls = [
            "http://localhost:3001",
            "http://localhost:3000",
            "http://localhost:8080", 
            "http://localhost:5000",
            "http://127.0.0.1:3001"
        ]
        
        app_loaded = False
        for url in test_urls:
            try:
                print(f"🔗 {url} にアクセス中...")
                driver.get(url)
                time.sleep(3)
                
                # ページタイトル確認
                title = driver.title
                if "gym" in title.lower() or "gymnastics" in title.lower() or title:
                    print(f"✅ アプリ読み込み成功: {title}")
                    app_loaded = True
                    break
            except Exception as e:
                print(f"❌ {url} アクセス失敗: {e}")
                continue
        
        if not app_loaded:
            print("⚠️ Flutterアプリに直接アクセスできません")
            print("💡 手動でブラウザを開いて http://localhost:3000 をお試しください")
            return
        
        # スクリーンショット撮影
        driver.save_screenshot("app_screenshot.png")
        print("📸 スクリーンショット撮影: app_screenshot.png")
        
        # 画面操作のデモ
        print("🎯 自動操作デモ開始...")
        
        # 画面をスクロール
        for i in range(3):
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(1)
            driver.execute_script("window.scrollTo(0, 0);")
            time.sleep(1)
        
        print("✅ 自動操作デモ完了")
        
        # ブラウザを残して操作確認
        print("\n👀 ブラウザが開いています。手動で操作をご確認ください。")
        print("🎯 以下の操作をお試しください:")
        print("  1. ボトムナビゲーション（AIチャット/Dスコア計算）の切り替え")
        print("  2. チャット機能でメッセージ送信")
        print("  3. Dスコア計算で種目選択と技追加")
        
        input("\n⏸️ 確認完了後、Enterキーを押してブラウザを閉じてください...")
        
    except Exception as e:
        print(f"❌ ブラウザテストエラー: {e}")
    finally:
        if driver:
            driver.quit()
            print("🔚 ブラウザ終了")

def main():
    print("🤖 体操アプリ自動テストツール（簡易版）")
    print("=" * 60)
    
    # API動作テスト
    if test_apis():
        print("\n" + "=" * 60)
        # ブラウザ自動操作テスト
        automated_browser_test()
    
    print("\n🎉 テスト完了!")

if __name__ == "__main__":
    main()