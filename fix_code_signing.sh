#!/bin/bash
# fix_code_signing.sh
# Xcode コードサイン エラー修正スクリプト

echo "🔧 Xcode コードサイン エラーを修正しています..."

# プロジェクトディレクトリに移動
cd /Users/iwasakihiroto/Desktop/gym

# クリーンアップ
echo "📦 クリーンアップ中..."
flutter clean
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/Podfile.lock

# 依存関係の再インストール
echo "📲 依存関係を再インストール中..."
flutter pub get

# iOS設定
echo "🍎 iOS設定を更新中..."
cd ios
pod install --repo-update

# Bundle Identifier の確認
echo "🔍 Bundle Identifier を確認中..."
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Runner/Info.plist 2>/dev/null || echo "not found")
echo "現在のBundle ID: $BUNDLE_ID"

if [ "$BUNDLE_ID" != "com.daito.gym" ]; then
    echo "⚠️  Bundle ID を修正しています..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.daito.gym" Runner/Info.plist
    echo "✅ Bundle ID を com.daito.gym に変更しました"
fi

# iOS deployment target の確認
echo "🎯 iOS deployment target を確認中..."
DEPLOYMENT_TARGET=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" Runner/Info.plist 2>/dev/null || echo "not found")
echo "現在のDeployment Target: $DEPLOYMENT_TARGET"

if [ "$DEPLOYMENT_TARGET" != "13.0" ]; then
    echo "⚠️  iOS deployment target を修正しています..."
    /usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 13.0" Runner/Info.plist
    echo "✅ iOS deployment target を 13.0 に変更しました"
fi

# プロジェクト設定の確認
echo "🔍 プロジェクト設定を確認中..."
cd ..

# Podfile の確認
echo "📋 Podfile を確認中..."
if [ -f "ios/Podfile" ]; then
    echo "✅ Podfile が見つかりました"
else
    echo "⚠️  Podfile が見つかりません"
fi

# Flutter設定の確認
echo "📱 Flutter設定を確認中..."
if [ -f "pubspec.yaml" ]; then
    echo "✅ pubspec.yaml が見つかりました"
    # アプリ名の確認
    APP_NAME=$(grep "name:" pubspec.yaml | cut -d' ' -f2)
    echo "アプリ名: $APP_NAME"
else
    echo "⚠️  pubspec.yaml が見つかりません"
fi

# コードサイン設定の確認
echo "🔐 コードサイン設定を確認中..."
cd ios

# project.pbxproj の確認
if [ -f "Runner.xcodeproj/project.pbxproj" ]; then
    echo "✅ project.pbxproj が見つかりました"
    
    # Bundle Identifier の確認
    PBXPROJ_BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" Runner.xcodeproj/project.pbxproj | head -1 | cut -d'=' -f2 | tr -d ' ";')
    echo "project.pbxproj内のBundle ID: $PBXPROJ_BUNDLE_ID"
    
    # 必要に応じて修正
    if [ "$PBXPROJ_BUNDLE_ID" != "com.daito.gym" ]; then
        echo "⚠️  project.pbxproj のBundle IDを修正しています..."
        sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = com.daito.gym;/g' Runner.xcodeproj/project.pbxproj
        echo "✅ project.pbxproj のBundle IDを修正しました"
    fi
else
    echo "⚠️  project.pbxproj が見つかりません"
fi

# エンタイトルメントファイルの確認
echo "🔑 エンタイトルメントファイルを確認中..."
if [ -f "Runner/Runner.entitlements" ]; then
    echo "✅ Runner.entitlements が見つかりました"
else
    echo "⚠️  Runner.entitlements を作成しています..."
    cat > Runner/Runner.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-payments</key>
    <true/>
</dict>
</plist>
EOF
    echo "✅ Runner.entitlements を作成しました"
fi

# ビルドテスト
echo "🧪 ビルドテストを実行中..."
cd ..
flutter build ios --debug --no-codesign

if [ $? -eq 0 ]; then
    echo "✅ ビルドテストが成功しました"
else
    echo "⚠️  ビルドテストでエラーが発生しました"
    echo "Xcodeで手動確認が必要です"
fi

echo ""
echo "🎉 コードサイン修正が完了しました"
echo ""
echo "次の手順:"
echo "1. Xcode でプロジェクトを開く:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "2. Signing & Capabilities でチーム設定を確認:"
echo "   - 正しいApple Developer Teamを選択"
echo "   - 'Automatically manage signing' をチェック"
echo "   - Bundle Identifier が 'com.daito.gym' になっていることを確認"
echo ""
echo "3. 必要なCapabilitiesを追加:"
echo "   - In-App Purchase"
echo "   - Associated Domains (必要に応じて)"
echo ""
echo "4. ビルドを実行:"
echo "   Product → Clean Build Folder"
echo "   Product → Build"
echo ""
echo "5. 実機テスト:"
echo "   デバイスを接続して Product → Run"
echo ""
echo "📚 詳細なガイド: xcode_code_signing_fix.md を参照してください"