#!/usr/bin/env python3
"""
Gym App Web Dashboard Launcher
管理者用Webダッシュボードを起動するスクリプト
"""

import subprocess
import sys
import os
import time
import webbrowser
from pathlib import Path

def check_dependencies():
    """必要なパッケージがインストールされているかチェック"""
    required_packages = ['streamlit', 'plotly', 'pandas', 'requests']
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package} - インストール済み")
        except ImportError:
            missing_packages.append(package)
            print(f"❌ {package} - インストールが必要")
    
    if missing_packages:
        print(f"\n以下のパッケージをインストールしてください:")
        for package in missing_packages:
            print(f"  pip install {package}")
        return False
    
    return True

def start_api_server():
    """APIサーバーを起動"""
    print("🚀 APIサーバーを起動中...")
    
    # Check if server is already running
    import requests
    try:
        response = requests.get("http://127.0.0.1:8000/", timeout=2)
        if response.status_code == 200:
            print("✅ APIサーバーは既に起動しています")
            return None
    except:
        pass
    
    # Start API server
    api_process = subprocess.Popen([
        sys.executable, "-m", "uvicorn", "api:app", 
        "--reload", "--host", "127.0.0.1", "--port", "8000"
    ])
    
    # Wait for server to start
    print("⏳ APIサーバーの起動を待機中...")
    time.sleep(5)
    
    return api_process

def start_dashboard():
    """Streamlit ダッシュボードを起動"""
    print("🌐 Webダッシュボードを起動中...")
    
    dashboard_process = subprocess.Popen([
        sys.executable, "-m", "streamlit", "run", "web_dashboard.py",
        "--server.port", "8501",
        "--server.address", "127.0.0.1"
    ])
    
    # Wait for dashboard to start
    print("⏳ ダッシュボードの起動を待機中...")
    time.sleep(3)
    
    return dashboard_process

def main():
    print("🏃‍♂️ Gym App Web Dashboard Launcher")
    print("=" * 50)
    
    # Check current directory
    current_dir = Path.cwd()
    if not (current_dir / "web_dashboard.py").exists():
        print("❌ web_dashboard.py が見つかりません")
        print("   正しいディレクトリで実行してください")
        sys.exit(1)
    
    # Check dependencies
    print("📦 依存関係をチェック中...")
    if not check_dependencies():
        print("\n❌ 必要なパッケージがインストールされていません")
        sys.exit(1)
    
    print("\n✅ 全ての依存関係が満たされています")
    
    # Start API server
    api_process = start_api_server()
    
    # Start dashboard
    dashboard_process = start_dashboard()
    
    # Open browser
    print("\n🌐 ブラウザでダッシュボードを開いています...")
    webbrowser.open("http://127.0.0.1:8501")
    
    print("\n" + "=" * 50)
    print("🎉 ダッシュボードが起動しました!")
    print("📊 URL: http://127.0.0.1:8501")
    print("🔑 管理者ログイン: admin / admin123")
    print("💡 Ctrl+C で終了")
    print("=" * 50)
    
    try:
        # Wait for processes
        dashboard_process.wait()
    except KeyboardInterrupt:
        print("\n🛑 ダッシュボードを停止中...")
        
        # Stop dashboard
        dashboard_process.terminate()
        
        # Stop API server if we started it
        if api_process:
            api_process.terminate()
        
        print("✅ 正常に停止しました")

if __name__ == "__main__":
    main()