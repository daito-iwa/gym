# Xcode コードサイン エラー修正ガイド

## 問題の概要

Xcodeでのコードサイン エラーは、iOS アプリ開発において最も一般的な問題の一つです。このガイドでは、大東体操クラブアプリで発生する可能性のあるコードサイン エラーの解決方法を説明します。

## 一般的なコードサイン エラー

### 1. 証明書が見つからない/期限切れ
```
error: Code signing is required for product type 'Application' in SDK 'iOS 13.0'
```

### 2. プロビジョニングプロファイルの問題
```
error: Provisioning profile "iOS Team Provisioning Profile" doesn't support the In-App Purchase capability
```

### 3. Bundle Identifier の不一致
```
error: The bundle identifier "com.example.daito" doesn't match the bundle identifier "com.daito.gym"
```

## 解決手順

### Step 1: 開発者証明書の確認

1. **Xcode を開く**
2. **Preferences → Accounts** に移動
3. Apple ID アカウントを確認
4. **Download Manual Profiles** をクリック

### Step 2: プロジェクト設定の確認

1. **プロジェクトファイル** を選択
2. **Target** → **大東体操クラブアプリ** を選択
3. **Signing & Capabilities** タブを開く

#### 基本設定
- **Team**: 正しい開発者チームを選択
- **Bundle Identifier**: `com.daito.gym`
- **Automatically manage signing**: チェック

### Step 3: Bundle Identifier の修正

#### iOS設定ファイル修正
```bash
# iOS/Runner/Info.plist の確認
cd /Users/iwasakihiroto/Desktop/gym/ios/Runner
grep -A 1 "CFBundleIdentifier" Info.plist
```

#### Flutter設定修正
```bash
# pubspec.yaml の確認
grep -A 5 "flutter:" /Users/iwasakihiroto/Desktop/gym/pubspec.yaml
```

### Step 4: 必要な Capabilities の追加

#### In-App Purchase
1. **Signing & Capabilities** で **+ Capability** をクリック
2. **In-App Purchase** を検索して追加

#### Associated Domains (オプション)
- `applinks:daito.gym`
- `applinks:www.daito.gym`

### Step 5: プロビジョニングプロファイルの再生成

```bash
# 古いプロファイルを削除
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

# Xcode で再生成
# Product → Clean Build Folder
# Product → Build
```

### Step 6: 証明書の更新

#### 開発証明書
1. **Keychain Access** を開く
2. **Certificate Assistant** → **Request a Certificate from a Certificate Authority**
3. **Apple Developer Portal** で新しい証明書を作成

#### 配布証明書
1. **App Store Connect** にログイン
2. **Certificates, Identifiers & Profiles** に移動
3. **Distribution Certificate** を作成

## 具体的な修正コマンド

### 1. 既存設定のクリーンアップ
```bash
cd /Users/iwasakihiroto/Desktop/gym

# iOS ビルドフォルダをクリーンアップ
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/Podfile.lock

# Flutter クリーンアップ
flutter clean
flutter pub get
```

### 2. iOS設定の更新
```bash
# iOS プロジェクトディレクトリに移動
cd ios

# Pod 再インストール
pod install --repo-update
```

### 3. 手動でのBundle Identifier確認
```bash
# Info.plist の Bundle Identifier 確認
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" ios/Runner/Info.plist

# 必要に応じて修正
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.daito.gym" ios/Runner/Info.plist
```

## トラブルシューティング

### エラー: "No signing certificate found"

**解決方法:**
1. **Xcode** → **Preferences** → **Accounts**
2. Apple ID を再度サインイン
3. **Download Manual Profiles** をクリック
4. プロジェクトで **Automatically manage signing** をオフにしてからオンに戻す

### エラー: "Provisioning profile doesn't support capability"

**解決方法:**
1. **Apple Developer Portal** にログイン
2. **Identifiers** で App ID を確認
3. 必要な Capabilities を有効化
4. プロビジョニングプロファイルを再生成

### エラー: "Code signing is required for product type 'Application'"

**解決方法:**
```bash
# iOS設定を確認
cd /Users/iwasakihiroto/Desktop/gym/ios

# project.pbxproj のコードサイン設定を確認
grep -n "CODE_SIGN" Runner.xcodeproj/project.pbxproj
```

## 本番環境での注意点

### 1. 配布証明書の設定
- **Archive** 用の配布証明書を設定
- **App Store** 配布用のプロビジョニングプロファイル

### 2. エンタイトルメントの確認
```xml
<!-- ios/Runner/Runner.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-payments</key>
    <true/>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```

### 3. Info.plist の最終確認
```xml
<!-- 必要な設定項目 -->
<key>CFBundleIdentifier</key>
<string>com.daito.gym</string>
<key>CFBundleName</key>
<string>大東体操クラブ</string>
<key>CFBundleDisplayName</key>
<string>大東体操クラブ</string>
```

## 自動化スクリプト

### コードサイン修正スクリプト
```bash
#!/bin/bash
# fix_code_signing.sh

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
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Runner/Info.plist)
echo "現在のBundle ID: $BUNDLE_ID"

if [ "$BUNDLE_ID" != "com.daito.gym" ]; then
    echo "⚠️  Bundle ID を修正しています..."
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.daito.gym" Runner/Info.plist
fi

echo "✅ コードサイン修正が完了しました"
echo "次の手順:"
echo "1. Xcode でプロジェクトを開く"
echo "2. Signing & Capabilities でチーム設定を確認"
echo "3. Product → Clean Build Folder を実行"
echo "4. プロジェクトをビルド"
```

### 使用方法
```bash
# スクリプトを実行可能にする
chmod +x fix_code_signing.sh

# スクリプトを実行
./fix_code_signing.sh
```

## 検証方法

### 1. ビルドテスト
```bash
cd /Users/iwasakihiroto/Desktop/gym

# iOS ビルドテスト
flutter build ios --debug
```

### 2. Archive テスト
1. **Xcode** でプロジェクトを開く
2. **Product** → **Archive** を実行
3. エラーが発生しないことを確認

### 3. 実機テスト
1. 実機をMacに接続
2. **Product** → **Run** を実行
3. アプリが正常に起動することを確認

## 予防策

### 1. 定期的なメンテナンス
- 証明書の有効期限を確認
- プロビジョニングプロファイルの更新
- Xcode の最新版への更新

### 2. バックアップ
- 正常動作する設定のバックアップ
- 証明書ファイルの安全な保存

### 3. チーム開発での注意点
- 共有する証明書の管理
- Bundle Identifier の統一
- 開発環境の標準化

## 参考リンク

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Code Signing Guide](https://developer.apple.com/library/content/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Flutter iOS Deployment](https://flutter.dev/docs/deployment/ios)

---

**最終更新日: 2025年1月**