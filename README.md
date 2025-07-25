# 体操D-スコア計算アプリ (Gymnastics D-Score Calculator)

体操競技のD-スコア（演技価値点）を計算し、AIチャットによる体操ルールブック質問応答機能を提供するFlutterアプリケーションです。

## 🏅 主な機能

### AIチャット機能 
- **体操ルールブック質問応答**: OpenAI GPTを活用した日本語・英語対応のAIチャット
- **技術的な質問対応**: 演技構成、技の認定、減点項目などの専門的な質問に対応
- **リアルタイム応答**: 迅速で正確な回答を提供

### D-スコア計算機能 (プレミアム)
- **6種目対応**: ゆか、あん馬、つり輪、跳馬、平行棒、鉄棒
- **自動最適化**: 技数上限を超えた場合の最適な技選択アルゴリズム
- **グループボーナス計算**: 各種目のグループ要求に基づくボーナス計算
- **接続ボーナス**: 鉄棒での技の接続ボーナス自動計算

### 演技構成分析 (プレミアム)
- **全種目一覧**: 各種目の技を技術的な詳細と共に表示
- **演技構成保存**: 作成した演技構成の保存・読み込み機能
- **統計分析**: 演技の統計情報とパフォーマンス分析

### アナリティクス機能 (プレミアム)
- **使用統計**: アプリ使用状況の詳細分析
- **演技データ**: 保存された演技構成の統計情報
- **パフォーマンス追跡**: 演技レベルの向上追跡

### 課金システム
- **プレミアム機能**: アプリ内課金による機能拡張
- **iOS/Android対応**: プラットフォーム別の課金システム統合
- **サブスクリプション管理**: 月額課金の自動更新

### 多言語対応
- **日本語**: ✅ 完全実装済み（リリース準備完了）
- **英語**: 🚧 開発中（サンプルデータのみ）
- **地域化対応**: 各地域に適した表示形式

## 🛠 技術仕様

### フロントエンド
- **Framework**: Flutter 3.x
- **言語**: Dart
- **状態管理**: StatefulWidget
- **UI設計**: Material Design

### バックエンド
- **Framework**: FastAPI (Python)
- **AI統合**: OpenAI API
- **データベース**: Chroma (ベクターデータベース)
- **認証**: JWT Bearer Token

### インフラ・ツール
- **課金システム**: Google Play Billing, App Store Connect
- **広告**: Google Mobile Ads
- **データ永続化**: Flutter Secure Storage, SharedPreferences
- **ファイル操作**: File Picker
- **チャート表示**: FL Chart
- **CSV出力**: CSV パッケージ

## 📱 対応プラットフォーム

- **iOS**: iPhone/iPad対応
- **Android**: Android 5.0以上
- **Web**: ブラウザ対応 (開発中)

## 🚀 セットアップ手順

### 前提条件
- Flutter SDK 3.x以上
- Python 3.8以上
- OpenAI APIキー

### 1. リポジトリクローン
```bash
git clone <repository-url>
cd gym
```

### 2. 環境変数設定
`.env.example`を参考に`.env`ファイルを作成：
```bash
cp .env.example .env
```

`.env`ファイルを編集：
```env
OPENAI_API_KEY=your_openai_api_key_here
ENVIRONMENT=development
API_PORT=8000
WEB_PORT=3000
CHROMA_PERSIST_DIR=./db_ja
CHROMA_PERSIST_DIR_EN=./db_en
```

### 3. バックエンド起動
```bash
# Python仮想環境作成・アクティベート
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 依存関係インストール
pip install -r requirements.txt

# APIサーバー起動
python api.py
```

### 4. フロントエンド起動
```bash
# 依存関係インストール
flutter pub get

# アプリ起動
flutter run
```

## 🏗 プロジェクト構造

```
gym/
├── lib/
│   ├── main.dart              # メインアプリケーション
│   ├── config.dart            # 環境設定
│   ├── auth_screen.dart       # 認証画面
│   └── d_score_calculator.dart # D-スコア計算ロジック
├── api.py                     # FastAPI バックエンド
├── rulebook_ai.py            # AI チャット機能
├── auth.py                   # 認証システム
├── .env.example              # 環境変数テンプレート
└── README.md                 # このファイル
```

## 🔒 セキュリティ

- **認証**: JWT Bearer Token による安全な認証
- **データ保護**: Flutter Secure Storage によるトークン暗号化
- **API セキュリティ**: CORS設定とレート制限
- **環境分離**: 開発・ステージング・本番環境の完全分離

## 📊 環境設定

### 開発環境
- **API URL**: `http://localhost:8000` (Web) / `http://192.168.40.218:8000` (ネイティブ)
- **デバッグログ**: 有効
- **API タイムアウト**: 60秒

### 本番環境
- **API URL**: `https://api.your-domain.com`
- **アナリティクス**: 有効
- **API タイムアウト**: 30秒

環境の切り替えは `lib/config.dart` の `_environment` を変更します。

## 🧪 テスト

```bash
# ユニットテスト実行
flutter test

# 統合テスト実行
flutter drive --target=test_driver/app.dart
```

## 📈 今後の開発予定

- [ ] プッシュ通知機能
- [ ] オフライン対応
- [ ] 詳細なアナリティクス
- [ ] ソーシャルログイン対応
- [ ] 動画解析機能

## 🤝 コントリビューション

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

## 📞 サポート

質問やバグ報告は [Issues](https://github.com/your-username/gym/issues) からお願いします。

---

**注意**: このアプリケーションは体操競技の技術的な参考情報を提供するものであり、公式な競技判定の代替ではありません。実際の競技では公式ルールブックと審判の判定に従ってください。
# Trigger workflow
