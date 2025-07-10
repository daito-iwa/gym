#!/usr/bin/env python3
"""
体操アプリのデモ用自動テスト
ブラウザを開いて、実際の操作を見えるように実行
"""

import time
import subprocess
import webbrowser
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

def open_app_manually():
    """手動でアプリを開く"""
    print("🌐 ブラウザでアプリを開きます...")
    
    # 複数の可能なURLを試行
    urls = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8080"
    ]
    
    for url in urls:
        print(f"🔗 {url} を開こうとしています...")
        try:
            webbrowser.open(url)
            print(f"✅ {url} をブラウザで開きました")
            break
        except Exception as e:
            print(f"❌ {url} を開けませんでした: {e}")
    
    print("\n👀 ブラウザでアプリが開いているはずです！")
    print("📱 以下の機能をテストしてください:")
    print("  1. ボトムナビゲーション（AIチャット/Dスコア計算）")
    print("  2. チャット機能でメッセージ送信")
    print("  3. Dスコア計算で技の追加")

def automated_visual_test():
    """視覚的な自動テスト"""
    print("\n🤖 自動テストを開始します...")
    
    options = Options()
    options.add_argument("--window-size=1200,800")
    options.add_argument("--start-maximized")
    
    driver = None
    try:
        driver = webdriver.Chrome(options=options)
        
        # Flutter Webアプリにアクセス
        print("🔗 アプリにアクセス中...")
        driver.get("http://localhost:3000")
        time.sleep(5)
        
        print("📸 初期画面のスクリーンショット撮影...")
        driver.save_screenshot("01_initial_screen.png")
        
        # ページタイトル確認
        title = driver.title
        print(f"📄 ページタイトル: {title}")
        
        # 画面をスクロールして全体を表示
        print("📜 画面スクロールテスト...")
        for i in range(3):
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(1)
            driver.execute_script("window.scrollTo(0, 0);")
            time.sleep(1)
        
        driver.save_screenshot("02_after_scroll.png")
        print("📸 スクロール後のスクリーンショット撮影...")
        
        # モバイル表示に切り替え
        print("📱 モバイル表示テスト...")
        driver.set_window_size(375, 812)  # iPhone画面サイズ
        time.sleep(2)
        driver.save_screenshot("03_mobile_view.png")
        print("📸 モバイル表示のスクリーンショット撮影...")
        
        # デスクトップサイズに戻す
        driver.set_window_size(1200, 800)
        time.sleep(2)
        
        print("\n🎯 自動テスト完了！以下のスクリーンショットが保存されました:")
        print("  - 01_initial_screen.png (初期画面)")
        print("  - 02_after_scroll.png (スクロール後)")
        print("  - 03_mobile_view.png (モバイル表示)")
        
        print("\n👁️ ブラウザは開いたままにします。手動でテストしてください！")
        print("⚠️ このウィンドウを閉じずに、実際のアプリ動作を確認してみてください。")
        
        # ユーザーの確認を待つ
        input("\n⏸️ テスト確認後、Enterキーを押してください...")
        
    except Exception as e:
        print(f"❌ テストエラー: {e}")
    finally:
        if driver:
            print("🔚 ブラウザを閉じます...")
            driver.quit()

def main():
    print("🎭 体操アプリ デモテストツール")
    print("=" * 50)
    
    # まず手動でブラウザを開く
    open_app_manually()
    
    # 少し待ってから自動テスト
    print("\n⏰ 5秒後に自動テストを開始します...")
    time.sleep(5)
    
    # 自動化テスト実行
    automated_visual_test()
    
    print("\n🎉 全テスト完了！")

if __name__ == "__main__":
    main()