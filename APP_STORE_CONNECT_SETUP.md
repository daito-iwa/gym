# 📱 App Store Connect 実際の登録作業

## 🍎 iOS App Store Connect 登録手順

### 1. App Store Connect にログイン
1. [App Store Connect](https://appstoreconnect.apple.com/) にアクセス
2. Apple Developer Account でログイン

### 2. 新しいアプリを作成
```yaml
アプリ情報:
プラットフォーム: iOS
名前: Gymnastics AI
プライマリ言語: 日本語
Bundle ID: com.daito.gymnasticsai (選択)
SKU: gymnastics-ai-2025
```

### 3. アプリ情報設定

#### 一般情報
```yaml
アプリ名: Gymnastics AI
サブタイトル: 体操競技のDスコア計算とAIコーチング  
カテゴリ:
  プライマリ: スポーツ
  セカンダリ: 教育
対象年齢: 4+
```

#### 価格とアベイラビリティ
```yaml
価格: 無料
アプリ内課金: あり
利用可能地域: すべて
```

### 4. App Store説明文

#### 日本語版
```
体操競技のDスコア（演技価値点）を正確に計算し、AIが技術指導を行う専門アプリです。

🏅 主な機能
・男子6種目の正確なDスコア計算
・AIによるルールブック解説
・演技構成の最適化提案
・技の詳細データベース

📊 対応種目
床運動、あん馬、つり輪、跳馬、平行棒、鉄棒

🤖 AI機能
・ルールの詳細解説
・技の組み合わせ提案  
・演技構成の分析

✨ プレミアム機能
・無制限AIチャット
・詳細な分析レポート
・カスタム演技作成

このアプリは体操競技者、指導者、審判員の皆様に最適な専門ツールです。
```

#### キーワード
```
体操,gymnastics,Dスコア,体操競技,技,演技,コーチング,スポーツ,AI,ルール
```

### 5. スクリーンショット準備

#### 必要なサイズ
**iPhone 6.7インチ (必須):**
- 1290 x 2796 pixels
- 最大10枚

**iPad Pro 12.9インチ (推奨):**
- 2048 x 2732 pixels
- 最大10枚

#### 撮影する画面
1. **メイン画面** - アプリの概要
2. **種目選択** - 6種目表示
3. **技選択画面** - 技データベース  
4. **Dスコア計算結果** - 計算結果表示
5. **AIチャット** - AI機能デモ
6. **認証画面** - ログイン機能
7. **プレミアム機能** - アップグレード画面

### 6. アプリ内課金設定

#### サブスクリプション設定
```yaml
サブスクリプショングループ: Premium Features

商品設定:
商品ID: com.daito.gym.premium_monthly_subscription
参照名: プレミアム月額プラン
価格: ¥480 / 月
期間: 1ヶ月
```

#### 商品説明
```yaml
表示名: プレミアムプラン
説明: 無制限AIチャット、詳細分析、カスタム演技作成機能をご利用いただけます
```

## 🤖 Google Play Console 登録手順

### 1. Google Play Console にログイン
1. [Google Play Console](https://play.google.com/console/) にアクセス
2. Google Developer Account でログイン

### 2. 新しいアプリを作成
```yaml
アプリの詳細:
アプリ名: Gymnastics AI
デフォルト言語: 日本語
アプリまたはゲーム: アプリ
有料または無料: 無料
```

### 3. アプリの設定

#### アプリの詳細
```yaml
アプリ名: Gymnastics AI
簡潔な説明: 体操競技のDスコア計算とAIコーチング
詳細な説明: 
体操競技のDスコア（演技価値点）を正確に計算し、AIが技術指導を行う専門アプリです。

🏅 主な機能
・男子6種目の正確なDスコア計算
・AIによるルールブック解説
・演技構成の最適化提案
・技の詳細データベース

📊 対応種目
床運動、あん馬、つり輪、跳馬、平行棒、鉄棒

🤖 AI機能
・ルールの詳細解説
・技の組み合わせ提案
・演技構成の分析

このアプリは体操競技者、指導者、審判員の皆様に最適な専門ツールです。
```

#### カテゴリとタグ
```yaml
カテゴリ: スポーツ
タグ: 体操、スポーツ、教育、AI
対象年齢: 全年齢
```

### 4. ストアの設定

#### グラフィック素材
```yaml
アプリアイコン: 512 x 512 PNG
機能グラフィック: 1024 x 500 JPG/PNG
スクリーンショット: 
- Phone: 最大8枚
- 7インチタブレット: 最大8枚  
- 10インチタブレット: 最大8枚
```

## 🎯 実際のアップロード作業

### iOS ビルド & アップロード
```bash
# 1. クリーンビルド
flutter clean
flutter pub get

# 2. iOS依存関係更新
cd ios
pod install --repo-update
cd ..

# 3. リリースビルド作成
flutter build ipa --release

# 4. App Store Connect アップロード
# Xcode > Organizer を使用、または
# Transporter.app を使用してIPAをアップロード
```

### Android ビルド & アップロード  
```bash
# 1. クリーンビルド
flutter clean
flutter pub get

# 2. App Bundle 作成 (推奨)
flutter build appbundle --release

# 3. Google Play Console でアップロード
# build/app/outputs/bundle/release/app-release.aab をアップロード
```

## 📋 リリース前チェックリスト

### App Store Connect
- [ ] アプリ情報入力完了
- [ ] スクリーンショット追加完了
- [ ] アプリ内課金設定完了
- [ ] プライバシーポリシーURL設定
- [ ] 審査向け情報入力
- [ ] TestFlight ベータテスト実施

### Google Play Console  
- [ ] ストアリスト情報入力完了
- [ ] グラフィック素材アップロード完了
- [ ] アプリ内商品設定完了
- [ ] 内部テストトラック設定
- [ ] 本番前レビュー実施

### 共通
- [ ] プライバシーポリシー公開
- [ ] 利用規約公開
- [ ] サポートページ作成
- [ ] 最終動作テスト完了

---

**次のステップ: 実際のアプリビルドとアップロード実行** 🚀