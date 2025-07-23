#!/bin/bash

# 🚀 Gymnastics AI 自動リリーススクリプト
# 使用方法: ./release.sh [web|ios|android|all]

set -e  # エラー時に停止

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 設定
PROJECT_NAME="Gymnastics AI"
VERSION=$(grep 'version:' pubspec.yaml | cut -d ' ' -f2)
BUILD_DATE=$(date +"%Y-%m-%d %H:%M")
PLATFORM=${1:-"all"}

log_info "🚀 $PROJECT_NAME リリース開始 (v$VERSION)"
log_info "📅 ビルド日時: $BUILD_DATE"
log_info "🎯 対象プラットフォーム: $PLATFORM"

# 前提条件チェック
check_prerequisites() {
    log_info "🔍 前提条件チェック中..."
    
    # Flutter環境チェック
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter が見つかりません"
        exit 1
    fi
    
    # Git状態チェック
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "未コミットの変更があります"
        read -p "続行しますか? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 環境変数チェック
    if [ ! -f ".env" ]; then
        log_error ".envファイルが見つかりません"
        exit 1
    fi
    
    log_success "前提条件チェック完了"
}

# テスト実行
run_tests() {
    log_info "🧪 テスト実行中..."
    
    # 単体テスト
    flutter test || {
        log_error "単体テスト失敗"
        exit 1
    }
    
    # E2Eテスト (利用可能な場合)
    if [ -d "test/e2e" ]; then
        cd test/e2e
        npm test || {
            log_error "E2Eテスト失敗"
            exit 1
        }
        cd ../..
    fi
    
    log_success "全テスト完了"
}

# Webビルド
build_web() {
    log_info "🌐 Webアプリビルド中..."
    
    # クリーンビルド
    flutter clean
    flutter pub get
    
    # リリースビルド
    flutter build web --release --web-renderer canvaskit
    
    # ビルド結果確認
    if [ ! -f "build/web/index.html" ]; then
        log_error "Webビルド失敗"
        exit 1
    fi
    
    # Firebase デプロイ
    if command -v firebase &> /dev/null; then
        log_info "🔥 Firebase Hosting デプロイ中..."
        firebase deploy --only hosting
        log_success "Firebase デプロイ完了"
    fi
    
    log_success "Webビルド完了"
}

# iOSビルド
build_ios() {
    log_info "📱 iOS アプリビルド中..."
    
    # クリーンビルド
    flutter clean
    flutter pub get
    cd ios && pod install && cd ..
    
    # ビルド実行
    flutter build ipa --release
    
    # App Store Connect アップロード
    if [ -f "build/ios/ipa/*.ipa" ]; then
        log_info "📤 App Store Connect アップロード準備完了"
        log_info "手動でXcodeまたはTransporter.appを使用してアップロードしてください"
        log_info "IPA場所: build/ios/ipa/"
    fi
    
    log_success "iOSビルド完了"
}

# Androidビルド
build_android() {
    log_info "🤖 Android アプリビルド中..."
    
    # クリーンビルド
    flutter clean
    flutter pub get
    
    # App Bundle ビルド (推奨)
    flutter build appbundle --release
    
    # APK ビルド (テスト用)
    flutter build apk --release
    
    # ファイル確認
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        log_success "App Bundle: build/app/outputs/bundle/release/app-release.aab"
    fi
    
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        log_success "APK: build/app/outputs/flutter-apk/app-release.apk"
    fi
    
    log_info "📤 Google Play Console アップロード準備完了"
    
    log_success "Androidビルド完了"
}

# バックエンドデプロイ
deploy_backend() {
    log_info "🔧 バックエンドデプロイ中..."
    
    # Google Cloud デプロイ (利用可能な場合)
    if command -v gcloud &> /dev/null && [ -f "app.yaml" ]; then
        gcloud app deploy --quiet
        log_success "App Engine デプロイ完了"
    else
        log_warning "バックエンドデプロイはスキップされました"
    fi
}

# リリースノート生成
generate_release_notes() {
    log_info "📝 リリースノート生成中..."
    
    # Git コミット履歴から生成
    RELEASE_NOTES="# $PROJECT_NAME v$VERSION

## 📅 リリース日
$BUILD_DATE

## 🆕 新機能・改善
$(git log --since="2024-07-01" --pretty=format:"- %s" --grep="feat\|add\|improve" | head -10)

## 🐛 バグ修正  
$(git log --since="2024-07-01" --pretty=format:"- %s" --grep="fix\|bug" | head -5)

## 🔧 技術的改善
$(git log --since="2024-07-01" --pretty=format:"- %s" --grep="refactor\|perf\|tech" | head -5)

---
自動生成されたリリースノートです。"

    echo "$RELEASE_NOTES" > "RELEASE_NOTES_v$VERSION.md"
    log_success "リリースノート生成完了: RELEASE_NOTES_v$VERSION.md"
}

# Git タグ作成
create_git_tag() {
    log_info "🏷️ Gitタグ作成中..."
    
    git tag -a "v$VERSION" -m "Release v$VERSION - $BUILD_DATE"
    
    # リモートにプッシュ
    read -p "Gitタグをリモートにプッシュしますか? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "v$VERSION"
        log_success "Gitタグプッシュ完了"
    fi
}

# リリース完了処理
finalize_release() {
    log_success "🎉 リリース完了!"
    log_info "📊 リリース情報:"
    log_info "   バージョン: v$VERSION"
    log_info "   ビルド日時: $BUILD_DATE"
    log_info "   対象プラットフォーム: $PLATFORM"
    
    # 次のステップ案内
    echo ""
    log_info "📋 次のステップ:"
    if [ "$PLATFORM" = "web" ] || [ "$PLATFORM" = "all" ]; then
        log_info "   - Firebase Hosting: https://gymnastics-ai-prod.web.app"
    fi
    if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
        log_info "   - App Store Connect でTestFlightテスト実施"
        log_info "   - 審査申請前の最終確認"
    fi
    if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
        log_info "   - Google Play Console で内部テスト実施"
        log_info "   - 段階的ロールアウト設定"
    fi
    
    echo ""
    log_success "Happy releasing! 🚀"
}

# メイン実行
main() {
    # 前提条件チェック
    check_prerequisites
    
    # テスト実行
    run_tests
    
    # プラットフォーム別ビルド
    case $PLATFORM in
        "web")
            build_web
            ;;
        "ios")
            build_ios
            ;;
        "android")
            build_android
            ;;
        "all")
            build_web
            build_ios  
            build_android
            ;;
        *)
            log_error "未対応のプラットフォーム: $PLATFORM"
            log_info "使用方法: ./release.sh [web|ios|android|all]"
            exit 1
            ;;
    esac
    
    # バックエンドデプロイ
    deploy_backend
    
    # リリースノート生成
    generate_release_notes
    
    # Gitタグ作成
    create_git_tag
    
    # 完了処理
    finalize_release
}

# スクリプト実行
main "$@"