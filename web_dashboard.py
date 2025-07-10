import streamlit as st
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import json
import time
from typing import Dict, List, Any

# Page configuration
st.set_page_config(
    page_title="Gym App - Admin Dashboard",
    page_icon="🏃‍♂️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# API Base URL
API_BASE_URL = "http://127.0.0.1:8000"

# Custom CSS
st.markdown("""
<style>
    .main-header {
        background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
        padding: 1rem;
        border-radius: 10px;
        margin-bottom: 2rem;
    }
    .metric-card {
        background: #f8f9fa;
        padding: 1rem;
        border-radius: 8px;
        border-left: 4px solid #667eea;
        margin-bottom: 1rem;
    }
    .status-active {
        color: #28a745;
        font-weight: bold;
    }
    .status-inactive {
        color: #dc3545;
        font-weight: bold;
    }
    .subscription-premium {
        background: #fff3cd;
        padding: 0.25rem 0.5rem;
        border-radius: 4px;
        color: #856404;
        font-weight: bold;
    }
    .subscription-free {
        background: #d4edda;
        padding: 0.25rem 0.5rem;
        border-radius: 4px;
        color: #155724;
        font-weight: bold;
    }
</style>
""", unsafe_allow_html=True)

class DashboardAPI:
    def __init__(self):
        self.base_url = API_BASE_URL
        self.session = requests.Session()
        self.token = None
    
    def authenticate(self, username: str, password: str) -> bool:
        """管理者認証"""
        try:
            response = self.session.post(
                f"{self.base_url}/token",
                data={"username": username, "password": password},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                self.session.headers.update({"Authorization": f"Bearer {self.token}"})
                return True
            return False
        except Exception as e:
            st.error(f"認証エラー: {e}")
            return False
    
    def get_analytics(self) -> Dict[str, Any]:
        """アナリティクスデータ取得"""
        try:
            response = self.session.get(f"{self.base_url}/admin/analytics")
            if response.status_code == 200:
                return response.json()
            return {}
        except Exception as e:
            st.error(f"アナリティクス取得エラー: {e}")
            return {}
    
    def get_users(self) -> List[Dict[str, Any]]:
        """ユーザー一覧取得"""
        try:
            response = self.session.get(f"{self.base_url}/admin/users")
            if response.status_code == 200:
                data = response.json()
                return data.get("users", [])
            return []
        except Exception as e:
            st.error(f"ユーザー取得エラー: {e}")
            return []
    
    def update_user_subscription(self, username: str, subscription_data: Dict[str, Any]) -> bool:
        """ユーザーサブスクリプション更新"""
        try:
            response = self.session.put(
                f"{self.base_url}/admin/users/{username}/subscription",
                json=subscription_data
            )
            return response.status_code == 200
        except Exception as e:
            st.error(f"サブスクリプション更新エラー: {e}")
            return False

def login_page():
    """ログイン画面"""
    st.markdown("""
    <div class="main-header">
        <h1 style="color: white; text-align: center; margin: 0;">
            🏃‍♂️ Gym App Admin Dashboard
        </h1>
        <p style="color: white; text-align: center; margin: 0;">
            管理者専用ダッシュボード
        </p>
    </div>
    """, unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col2:
        st.markdown("### 🔐 管理者ログイン")
        
        with st.form("login_form"):
            username = st.text_input("ユーザー名", placeholder="admin")
            password = st.text_input("パスワード", type="password", placeholder="admin123")
            submit_button = st.form_submit_button("ログイン")
            
            if submit_button:
                if username and password:
                    api = DashboardAPI()
                    if api.authenticate(username, password):
                        st.session_state.authenticated = True
                        st.session_state.api = api
                        st.success("ログイン成功！")
                        st.rerun()
                    else:
                        st.error("ユーザー名またはパスワードが正しくありません")
                else:
                    st.error("ユーザー名とパスワードを入力してください")

def main_dashboard():
    """メインダッシュボード"""
    api = st.session_state.api
    
    # Header
    st.markdown("""
    <div class="main-header">
        <h1 style="color: white; margin: 0;">📊 管理者ダッシュボード</h1>
        <p style="color: white; margin: 0;">リアルタイムアプリ統計とユーザー管理</p>
    </div>
    """, unsafe_allow_html=True)
    
    # Sidebar
    with st.sidebar:
        st.markdown("### 🎛️ コントロールパネル")
        
        if st.button("🔄 データ更新", use_container_width=True):
            st.rerun()
        
        if st.button("🚪 ログアウト", use_container_width=True):
            st.session_state.authenticated = False
            st.session_state.api = None
            st.rerun()
        
        st.markdown("---")
        st.markdown("### 📋 機能メニュー")
        
        page = st.selectbox(
            "表示ページ",
            ["📊 概要", "👥 ユーザー管理", "💰 売上分析", "📱 アプリ統計"]
        )
    
    # Get data
    analytics_data = api.get_analytics()
    users_data = api.get_users()
    
    # Main content based on selected page
    if page == "📊 概要":
        show_overview(analytics_data, users_data)
    elif page == "👥 ユーザー管理":
        show_user_management(users_data, api)
    elif page == "💰 売上分析":
        show_revenue_analysis(analytics_data, users_data)
    elif page == "📱 アプリ統計":
        show_app_statistics(analytics_data)

def show_overview(analytics_data: Dict[str, Any], users_data: List[Dict[str, Any]]):
    """概要ページ"""
    st.markdown("## 📊 アプリ概要")
    
    # Key metrics
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        total_users = len(users_data)
        st.metric("総ユーザー数", total_users, delta="📈")
    
    with col2:
        premium_users = sum(1 for user in users_data if user.get("subscription_tier") == "premium")
        st.metric("プレミアムユーザー", premium_users, delta="💎")
    
    with col3:
        conversion_rate = (premium_users / total_users * 100) if total_users > 0 else 0
        st.metric("コンバージョン率", f"{conversion_rate:.1f}%", delta="🎯")
    
    with col4:
        monthly_revenue = premium_users * 500
        st.metric("月間売上予測", f"¥{monthly_revenue:,}", delta="💰")
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 🥧 ユーザー層分析")
        
        # User tier distribution
        free_users = total_users - premium_users
        
        if total_users > 0:
            fig = px.pie(
                values=[free_users, premium_users],
                names=["無料", "プレミアム"],
                color_discrete_map={"無料": "#28a745", "プレミアム": "#ffc107"},
                title="ユーザー層の割合"
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("データがありません")
    
    with col2:
        st.markdown("### 📈 登録推移")
        
        # Registration trend (mock data)
        if users_data:
            dates = pd.date_range(start="2024-01-01", end=datetime.now().date(), freq="D")
            cumulative_users = list(range(1, len(dates) + 1))
            
            fig = px.line(
                x=dates,
                y=cumulative_users,
                title="累計ユーザー数の推移",
                labels={"x": "日付", "y": "累計ユーザー数"}
            )
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("データがありません")

def show_user_management(users_data: List[Dict[str, Any]], api: DashboardAPI):
    """ユーザー管理ページ"""
    st.markdown("## 👥 ユーザー管理")
    
    if not users_data:
        st.info("ユーザーデータがありません")
        return
    
    # User table
    st.markdown("### 📋 ユーザー一覧")
    
    # Convert to DataFrame
    df = pd.DataFrame(users_data)
    
    # Display table
    for i, user in enumerate(users_data):
        with st.expander(f"👤 {user['username']} - {user.get('subscription_tier', 'free').title()}"):
            col1, col2 = st.columns(2)
            
            with col1:
                st.markdown(f"**ユーザー名:** {user['username']}")
                st.markdown(f"**メール:** {user.get('email', 'N/A')}")
                st.markdown(f"**フルネーム:** {user.get('full_name', 'N/A')}")
                st.markdown(f"**作成日:** {user.get('created_at', 'N/A')}")
                
                # Subscription status
                tier = user.get('subscription_tier', 'free')
                if tier == 'premium':
                    st.markdown('<span class="subscription-premium">🌟 プレミアム</span>', unsafe_allow_html=True)
                else:
                    st.markdown('<span class="subscription-free">🆓 無料</span>', unsafe_allow_html=True)
            
            with col2:
                if tier == 'premium':
                    start_date = user.get('subscription_start', 'N/A')
                    end_date = user.get('subscription_end', 'N/A')
                    st.markdown(f"**開始日:** {start_date}")
                    st.markdown(f"**終了日:** {end_date}")
                
                # Admin actions
                st.markdown("**🔧 管理操作**")
                
                if st.button(f"プレミアム付与", key=f"grant_{i}"):
                    subscription_data = {
                        "subscription_tier": "premium",
                        "subscription_start": datetime.now().isoformat(),
                        "subscription_end": (datetime.now() + timedelta(days=30)).isoformat()
                    }
                    
                    if api.update_user_subscription(user['username'], subscription_data):
                        st.success("プレミアムを付与しました")
                        st.rerun()
                    else:
                        st.error("更新に失敗しました")
                
                if st.button(f"無料に戻す", key=f"revoke_{i}"):
                    subscription_data = {
                        "subscription_tier": "free",
                        "subscription_start": None,
                        "subscription_end": None
                    }
                    
                    if api.update_user_subscription(user['username'], subscription_data):
                        st.success("無料に変更しました")
                        st.rerun()
                    else:
                        st.error("更新に失敗しました")

def show_revenue_analysis(analytics_data: Dict[str, Any], users_data: List[Dict[str, Any]]):
    """売上分析ページ"""
    st.markdown("## 💰 売上分析")
    
    premium_users = sum(1 for user in users_data if user.get("subscription_tier") == "premium")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        monthly_revenue = premium_users * 500
        st.metric("今月の売上", f"¥{monthly_revenue:,}")
    
    with col2:
        annual_revenue = monthly_revenue * 12
        st.metric("年間売上予測", f"¥{annual_revenue:,}")
    
    with col3:
        avg_revenue_per_user = monthly_revenue / len(users_data) if users_data else 0
        st.metric("ユーザー当たり売上", f"¥{avg_revenue_per_user:.0f}")
    
    # Revenue chart
    st.markdown("### 📊 売上推移")
    
    months = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"]
    revenue_data = [monthly_revenue * (i + 1) * 0.8 for i in range(12)]  # Mock data
    
    fig = px.bar(
        x=months,
        y=revenue_data,
        title="月別売上推移",
        labels={"x": "月", "y": "売上 (¥)"}
    )
    st.plotly_chart(fig, use_container_width=True)

def show_app_statistics(analytics_data: Dict[str, Any]):
    """アプリ統計ページ"""
    st.markdown("## 📱 アプリ統計")
    
    # Mock statistics
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 📊 機能使用状況")
        
        feature_usage = {
            "AIチャット": 95,
            "D-Score計算": 65,
            "全種目分析": 45,
            "アナリティクス": 30
        }
        
        fig = px.bar(
            x=list(feature_usage.keys()),
            y=list(feature_usage.values()),
            title="機能別使用率 (%)",
            labels={"x": "機能", "y": "使用率 (%)"}
        )
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.markdown("### 🎯 エンゲージメント")
        
        engagement_metrics = {
            "日間アクティブユーザー": 150,
            "週間アクティブユーザー": 300,
            "月間アクティブユーザー": 500,
            "平均セッション時間": "15分"
        }
        
        for metric, value in engagement_metrics.items():
            st.metric(metric, value)

def main():
    """メイン関数"""
    # Initialize session state
    if 'authenticated' not in st.session_state:
        st.session_state.authenticated = False
    if 'api' not in st.session_state:
        st.session_state.api = None
    
    # Show appropriate page
    if st.session_state.authenticated:
        main_dashboard()
    else:
        login_page()

if __name__ == "__main__":
    main()