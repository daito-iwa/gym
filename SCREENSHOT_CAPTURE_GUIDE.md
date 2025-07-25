# 📸 アプリスクリーンショット撮影ガイド

## 🎯 撮影対象画面

### 現在稼働中のWeb版を使用
- **URL**: http://localhost:9000
- **状態**: 完全動作中 ✅
- **AI機能**: OpenAI統合完了 ✅

## 📱 必要なスクリーンショット

### 1. ヒーロー/メイン画面
**撮影内容**: アプリの第一印象となる画面
- アプリロゴ・タイトル
- 主要機能の概要
- 「始める」ボタンなど

**メッセージ例**: 
```
📱 Gym AI
体操競技のDスコア計算とAI技術指導

正確な計算 × 最先端AI = あなたの技術向上
```

### 2. 種目選択画面  
**撮影内容**: 6種目の選択画面
- 床運動（FX）
- あん馬（PH）
- つり輪（SR）
- 跳馬（VT）
- 平行棒（PB）
- 鉄棒（HB）

**アピールポイント**: 全種目対応の専門性

### 3. 技データベース画面
**撮影内容**: 技選択・検索画面
- 豊富な技のリスト
- 技の詳細情報（難度、グループなど）
- 検索・フィルター機能

**アピールポイント**: 1000技以上の豊富なデータ

### 4. Dスコア計算結果画面
**撮影内容**: 計算結果の表示
- 選択した技のリスト
- 計算されたDスコア
- 内訳詳細（難度点、グループボーナスなど）

**アピールポイント**: 正確で詳細な計算結果

### 5. AIチャット機能画面
**撮影内容**: AI技術指導のデモ
- ユーザーの質問例: 「床運動の終末技について教えて」
- AIの詳細な回答
- チャット履歴

**アピールポイント**: 最先端AI技術による指導

### 6. 演技分析画面
**撮影内容**: 演技構成の分析結果
- グラフィカルな分析結果
- 改善提案
- 統計情報

**アピールポイント**: 科学的なデータ分析

### 7. プレミアム機能紹介
**撮影内容**: アップグレード画面
- プレミアム機能の一覧
- 料金プラン
- 無料体験の案内

**アピールポイント**: 付加価値の提示

### 8. ユーザープロフィール/設定
**撮影内容**: パーソナライゼーション機能
- ユーザー情報
- 設定オプション
- 利用統計

**アピールポイント**: 個人最適化機能

## 📐 技術仕様

### iOS App Store用
```yaml
iPhone 6.7インチ (必須):
サイズ: 1290 x 2796 pixels
形式: PNG または JPEG
最大: 10枚

iPad 12.9インチ (推奨):  
サイズ: 2048 x 2732 pixels
形式: PNG または JPEG
最大: 10枚
```

### Google Play Store用
```yaml
Phone:
サイズ: 1080 x 1920 pixels 以上
アスペクト比: 16:9 ～ 2:1
形式: PNG または JPEG
最大: 8枚

7インチタブレット:
サイズ: 1200 x 1600 pixels 推奨
最大: 8枚

10インチタブレット:
サイズ: 1536 x 2048 pixels 推奨  
最大: 8枚
```

## 🛠️ 撮影手順

### 準備作業
1. Web版アプリの起動確認 (localhost:9000)
2. バックエンドAPI動作確認 (localhost:8000)
3. ブラウザの開発者ツールでモバイル表示に切り替え
4. 適切な画面サイズに調整

### 撮影作業
```bash
# 1. ブラウザでlocalhost:9000を開く
# 2. 開発者ツール (F12) を起動
# 3. デバイスシミュレーション ON
# 4. iPhone Pro Max または iPad Pro サイズに設定
# 5. 各画面を順次撮影
```

### 品質チェックポイント
- [ ] 画面内のテキストが鮮明に読める
- [ ] UIが正しく表示されている
- [ ] アスペクト比が正確
- [ ] ファイルサイズが適切（各画像10MB以下）
- [ ] 個人情報が映り込んでいない

## 🎨 撮影のコツ

### 魅力的な画面構成
- **明るい配色**: ユーザーにポジティブな印象
- **クリーンなUI**: 整理された画面レイアウト
- **実際のデータ**: 意味のある技名・数値を表示
- **アクション誘導**: 次の操作が分かりやすい

### アプリの価値を伝える
- **専門性**: 体操競技特化の機能性
- **正確性**: 信頼できる計算結果  
- **先進性**: AI技術の活用
- **使いやすさ**: 直感的なインターフェース

## 📝 撮影完了後のチェックリスト

### ファイル整理
- [ ] 各プラットフォーム用のフォルダ分け
- [ ] 適切なファイル名付け
- [ ] サイズ・形式の最終確認

### App Store Connect アップロード
- [ ] iPhone用スクリーンショット (1290x2796)
- [ ] iPad用スクリーンショット (2048x2732)
- [ ] 各画面の説明文作成

### Google Play Console アップロード  
- [ ] Phone用スクリーンショット
- [ ] Tablet用スクリーンショット
- [ ] 機能グラフィック作成 (1024x500)

---

**撮影対象**: http://localhost:9000 で稼働中のWeb版アプリ**

現在、完全にオンライン・AI機能付きで動作しているため、実際のユーザー体験をそのまま撮影できます！ 📱✨