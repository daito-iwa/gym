# 🔑 Android署名キー作成ガイド

## 方法1: Flutter CLIを使用（簡単）

```bash
# 1. Javaをインストール
brew install openjdk@17

# 2. キーストア作成コマンド
keytool -genkey -v -keystore ~/gymnastics-ai-release.keystore -alias gymnastics-ai -keyalg RSA -keysize 2048 -validity 10000
```

## 方法2: オンラインツール使用

1. https://keystore-explorer.org/ をダウンロード
2. GUIで簡単にキーストア作成

## 🔐 キーストア情報（例）

```
Keystore password: GymnAI2024!@#
Key alias: gymnastics-ai
Key password: GymnAI2024!@#
Name: Daito Iwasaki
Organization: Individual
City: Tokyo
Country: JP
```

## ⚠️ 超重要

**このファイルとパスワードは絶対に失くさないでください！**
- クラウドストレージにバックアップ
- パスワードマネージャーに保存
- 複数の場所に保管