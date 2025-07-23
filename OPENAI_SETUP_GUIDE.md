# 🤖 体操AI - OpenAI APIキー設定ガイド

## 📋 現在の状況
- ✅ ルールブック読み込み: **完全動作**（144ページ、2025年版FIG採点規則）
- ✅ チャンク分割: **最適化済み**（1200文字、300オーバーラップ）
- ✅ キーワード検索: **正常**（鉄棒、難度、減点、着地など検出）
- ❌ AI機能: **APIキー必須**

## 🔑 OpenAI APIキー設定手順

### 1. OpenAI APIキーの取得
1. https://platform.openai.com/account/api-keys にアクセス
2. 新しいAPIキーを作成
3. APIキーをコピー（後で確認できないため注意）

### 2. 環境変数の設定

**方法A: 環境変数ファイル作成**
```bash
# .envファイルを作成
echo "OPENAI_API_KEY=your-actual-api-key-here" > .env
```

**方法B: 直接環境変数設定**
```bash
export OPENAI_API_KEY="your-actual-api-key-here"
```

### 3. AIシステムの初期化
```bash
# ベクトルデータベース構築
python3 -c "
import os
from rulebook_ai import setup_vectorstore
vectorstore = setup_vectorstore('ja')  # 日本語版
vectorstore = setup_vectorstore('en')  # 英語版
print('✅ ベクトルデータベース構築完了！')
"
```

### 4. AI機能テスト
```bash
# AIチャット機能テスト
python3 -c "
from rulebook_ai import create_conversational_chain, setup_vectorstore
vectorstore = setup_vectorstore('ja')
chain = create_conversational_chain(vectorstore, 'ja')
result = chain({'question': '鉄棒の手放し技について教えて'})
print('AI応答:', result['answer'])
"
```

## 📊 期待される改善効果

**OpenAI APIキー設定後:**
- 🎯 **高精度AI応答**: 2025年版FIG規則に基づく正確な回答
- 📖 **ルールブック参照**: 144ページから関連情報を自動抽出
- 🏅 **専門コーチング**: 世界レベルの体操技術アドバイス
- 💬 **多言語対応**: 日本語・英語での詳細な技術指導

## 💰 コスト目安
- **GPT-4o-mini**: 約$0.15/1Mトークン（入力）
- **Embeddings**: 約$0.02/1Mトークン
- **月間予想コスト**: $5-20（使用頻度による）

## 🚀 実装完了後の機能
1. **ルールブック質問応答**（FIG規則の即座の検索・回答）
2. **技術構成アドバイス**（D-score最適化提案）
3. **多言語サポート**（日英の専門用語対応）
4. **文脈理解**（継続的な会話での技術指導）

---

📞 **サポート**: 設定でお困りの場合はお声がけください。