from fastapi import FastAPI
import os
from openai import OpenAI
import json
import logging
from typing import Optional, Dict, Any
import asyncio

app = FastAPI()

# ロギング設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenAI設定
openai_client = None
if os.getenv("OPENAI_API_KEY"):
    openai_client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
if not openai_client:
    logger.warning("OPENAI_API_KEY not found. Falling back to local knowledge base only.")

# 包括的知識ベースローダー
class GymnasticsKnowledgeBase:
    def __init__(self):
        self.knowledge_cache = {}
        self.system_prompt = self._create_system_prompt()
    
    def _create_system_prompt(self):
        return """あなたは世界最高レベルの体操競技専門AIアシスタントです。以下の特徴を持ちます：

【専門性】
- FIG（国際体操連盟）公式ルール2025-2028年版の完全な理解
- 男子体操6種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）の専門知識
- Dスコア計算、連続技ボーナス、ND減点システムの詳細理解
- 技術的指導と戦略的アドバイスの提供

【回答スタイル】
- 初心者から専門家まで、質問者のレベルに応じた適切な説明
- 具体例と実践的なアドバイスを含む包括的な回答
- 正確性を最優先とし、推測では回答しない
- 日本語で自然で分かりやすい説明

【対応範囲】
- 体操競技の基礎知識から高度な技術論まで
- ルール・採点システムの詳細説明
- 演技構成の分析と改善提案
- 技術的質問への専門的回答
- 歴史・人物・大会に関する情報

あなたは質問の意図を正確に理解し、豊富な知識ベースから最適な回答を生成してください。"""

    def load_all_knowledge_files(self):
        """全ての知識ファイルを読み込み"""
        knowledge_files = [
            "data/comprehensive_rulebook_analysis.md",
            "data/d_score_master_knowledge.md", 
            "data/rulebook_ja_summary.md",
            "data/rulebook_ja_full.txt",
            "data/apparatus_details.md",
            "data/difficulty_calculation_system.md",
            "data/ai_implementation_guide.md",
            "data/skills_difficulty_tables.md"
        ]
        
        combined_knowledge = ""
        for file_path in knowledge_files:
            try:
                if os.path.exists(file_path):
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        combined_knowledge += f"\n\n=== {file_path} ===\n{content}"
                        logger.info(f"Loaded knowledge file: {file_path}")
            except Exception as e:
                logger.error(f"Error loading {file_path}: {e}")
        
        self.knowledge_cache["full_knowledge"] = combined_knowledge
        return combined_knowledge

knowledge_base = GymnasticsKnowledgeBase()

# インテリジェントな回答システム
class IntelligentGymnasticsAI:
    def __init__(self, knowledge_base: GymnasticsKnowledgeBase):
        self.knowledge_base = knowledge_base
        self.full_knowledge = None
    
    async def get_intelligent_response(self, question: str, context: Dict[str, Any] = None) -> str:
        """OpenAI APIを使用してインテリジェントな回答を生成"""
        try:
            if not openai_client:
                raise Exception("OpenAI API client not available")
            
            # 知識ベースを初回読み込み
            if not self.full_knowledge:
                self.full_knowledge = self.knowledge_base.load_all_knowledge_files()
            
            # コンテキスト情報を準備
            context_info = ""
            if context:
                context_info = f"""
【現在のコンテキスト】
- 種目: {context.get('apparatus', '未選択')}
- D-スコア: {context.get('d_score', 'N/A')}
- 技数: {context.get('skill_count', 'N/A')}
- グループ達成: {context.get('group_fulfillment', 'N/A')}
"""

            # 知識ベースから関連する部分を抽出（トークン制限対応）
            knowledge_excerpt = self._extract_relevant_knowledge(question, self.full_knowledge)

            # OpenAI APIに送信するメッセージを構築
            messages = [
                {"role": "system", "content": self.knowledge_base.system_prompt},
                {"role": "system", "content": f"以下は体操競技に関する専門知識です。この情報を参照して正確な回答をしてください：\n\n{knowledge_excerpt}"},
                {"role": "user", "content": f"{context_info}\n【質問】{question}"}
            ]
            
            # OpenAI API呼び出し（同期版を使用）
            response = openai_client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=messages,
                max_tokens=1500,
                temperature=0.1,  # 正確性を重視
                presence_penalty=0.1,
                frequency_penalty=0.1
            )
            
            ai_response = response.choices[0].message.content.strip()
            logger.info(f"OpenAI response generated for question: {question[:50]}...")
            
            return ai_response
            
        except Exception as e:
            logger.error(f"OpenAI API error: {e}")
            # フォールバックとして改良されたローカル検索を使用
            return self.get_enhanced_local_response(question, context)
    
    def _extract_relevant_knowledge(self, question: str, full_knowledge: str) -> str:
        """質問に関連する知識を抽出してトークン制限に対応"""
        question_lower = question.lower()
        
        # 質問に関連するキーワードを特定
        keywords = []
        if any(word in question_lower for word in ["体操", "gymnastics"]):
            keywords.extend(["体操", "競技", "種目", "6種目"])
        if any(word in question_lower for word in ["床", "floor", "fx"]):
            keywords.extend(["床運動", "FX", "アクロバット"])
        if any(word in question_lower for word in ["あん馬", "pommel", "ph"]):
            keywords.extend(["あん馬", "PH", "旋回"])
        if any(word in question_lower for word in ["つり輪", "rings", "sr"]):
            keywords.extend(["つり輪", "SR", "静止技"])
        if any(word in question_lower for word in ["跳馬", "vault", "vt"]):
            keywords.extend(["跳馬", "VT"])
        if any(word in question_lower for word in ["平行棒", "parallel", "pb"]):
            keywords.extend(["平行棒", "PB"])
        if any(word in question_lower for word in ["鉄棒", "horizontal", "hb"]):
            keywords.extend(["鉄棒", "HB", "手放し"])
        if any(word in question_lower for word in ["dスコア", "d-score", "難度"]):
            keywords.extend(["Dスコア", "難度", "価値点"])
        if any(word in question_lower for word in ["ルール", "採点", "減点"]):
            keywords.extend(["ルール", "採点", "減点"])
        
        # 関連する部分を抽出
        lines = full_knowledge.split('\n')
        relevant_lines = []
        
        for line in lines:
            if any(keyword in line for keyword in keywords):
                # 関連行の前後も含める
                start_idx = max(0, lines.index(line) - 2)
                end_idx = min(len(lines), lines.index(line) + 3)
                relevant_lines.extend(lines[start_idx:end_idx])
        
        # 重複を除去して結合
        relevant_text = '\n'.join(list(dict.fromkeys(relevant_lines)))
        
        # トークン制限（約6000文字）
        if len(relevant_text) > 6000:
            relevant_text = relevant_text[:6000] + "..."
        
        return relevant_text if relevant_text else full_knowledge[:6000]
    
    def get_enhanced_local_response(self, question: str, context: Dict[str, Any] = None) -> str:
        """改良されたローカル知識ベース検索"""
        question_lower = question.lower()
        
        # 基本的な体操に関する質問への対応を強化
        if any(word in question_lower for word in ["体操って", "体操とは", "体操競技とは", "体操について", "gymnastics"]):
            return self._get_comprehensive_gymnastics_explanation()
        
        # その他の質問は既存のロジックを使用（改良版）
        return self._search_knowledge_base_intelligently(question, context)
    
    def _get_comprehensive_gymnastics_explanation(self) -> str:
        """体操競技の包括的説明"""
        return """🏅 **体操競技について**

## 🤸‍♂️ 体操競技とは
体操競技は、人間の身体能力を最大限に引き出す美しく技術的なスポーツです。正確性、力強さ、優美さ、そして芸術性を兼ね備えた総合的な競技として、オリンピックの花形種目の一つとなっています。

## 📊 男子体操競技の6種目
1. **床運動（フロア）** - 12m×12mのマットで行う、宙返りやアクロバット技
2. **あん馬（ポメル）** - 旋回技を中心とした技術と持久力が必要
3. **つり輪（リング）** - 筋力による静止技と振動技の組み合わせ
4. **跳馬（ヴォルト）** - 助走からの跳越技、瞬発力と着地技術
5. **平行棒（パラレル）** - 2本のバーでの支持振動技と倒立技
6. **鉄棒（ハイバー）** - 手放し技と車輪系技、スペクタクルな演技

## ⭐ 採点システム
- **Dスコア（難度点）**: 技の難しさと構成
- **Eスコア（実施点）**: 演技の美しさと正確性
- **最終得点**: D-score + E-score

## 🌟 体操競技の魅力
- **技術の美しさ**: 人間の限界に挑戦する高度な技術
- **芸術性**: 力強さと優美さの完璧なバランス
- **総合性**: 柔軟性、筋力、バランス、協調性すべてが必要
- **進歩性**: 常に新しい技が生まれ続ける革新的スポーツ

## 🏆 競技レベル
ジュニアレベルから世界選手権、オリンピックまで、あらゆるレベルで楽しめるスポーツです。

体操競技について他にもご質問があれば、技術的な詳細から歴史まで、何でもお答えします！"""
    
    def _search_knowledge_base_intelligently(self, question: str, context: Dict[str, Any] = None) -> str:
        """インテリジェントな知識ベース検索（OpenAI利用不可時のフォールバック）"""
        question_lower = question.lower()
        
        # 知識ベースから関連情報を検索
        if not self.full_knowledge:
            self.full_knowledge = self.knowledge_base.load_all_knowledge_files()
        
        # キーワードベースの検索
        search_results = []
        
        # 種目特定キーワード
        apparatus_mapping = {
            "床": "FX", "floor": "FX", "フロア": "FX",
            "あん馬": "PH", "pommel": "PH", "ポメル": "PH",
            "つり輪": "SR", "rings": "SR", "リング": "SR",
            "跳馬": "VT", "vault": "VT", "ヴォルト": "VT",
            "平行棒": "PB", "parallel": "PB", "パラレル": "PB",
            "鉄棒": "HB", "horizontal": "HB", "ハイバー": "HB"
        }
        
        # 種目特定検索
        for keyword, apparatus in apparatus_mapping.items():
            if keyword in question_lower:
                apparatus_info = APPARATUS_KNOWLEDGE.get(apparatus, {})
                if apparatus_info:
                    search_results.append(f"**{apparatus_info.get('name', apparatus)}**の情報:")
                    search_results.append(apparatus_info.get('specific_advice', ''))
                    if 'connection_rules' in apparatus_info:
                        search_results.append(f"\n{apparatus_info['connection_rules']}")
                    break
        
        # 一般的なトピック検索
        topic_keywords = {
            "採点": "採点システム: Dスコア（難度点）+ Eスコア（実施点）で最終得点が決定されます。",
            "難度": "難度は A(0.1) から J(1.0) まで10段階に分かれています。",
            "減点": "減点は小欠点(0.1)、中欠点(0.3)、大欠点(0.5)、落下(1.0)に分類されます。",
            "グループ": "各種目には4つのグループがあり、各グループから最低1技の実施が必要です。",
            "連続技": "連続技ボーナス（CV）は特定の技の組み合わせで加点される仕組みです。"
        }
        
        for keyword, info in topic_keywords.items():
            if keyword in question_lower:
                search_results.append(info)
        
        # 知識ベースからの直接検索
        if self.full_knowledge:
            knowledge_lines = self.full_knowledge.split('\n')
            for line in knowledge_lines[:1000]:  # 最初の1000行から検索
                if any(word in line.lower() for word in question_lower.split()):
                    if len(line.strip()) > 10:
                        search_results.append(line.strip())
                        if len(search_results) >= 5:  # 最大5件まで
                            break
        
        if search_results:
            response = "**検索結果**\n\n" + "\n\n".join(search_results[:3])  # 最大3件表示
            response += "\n\n💡 より詳細な情報については、OpenAI APIが利用可能になり次第、より精密な回答を提供いたします。"
            return response
        
        return f"""「{question}」について、現在利用可能な情報を検索中です。

🤸‍♂️ **基本的な質問には対応可能です:**
• 各種目（床・あん馬・つり輪・跳馬・平行棒・鉄棒）について
• 採点システム（DスコアとEスコア）について  
• 技の難度と価値点について
• ルールと減点システムについて

より具体的にご質問いただければ、詳しくお答えできます。"""

# AI インスタンスを作成
intelligent_ai = IntelligentGymnasticsAI(knowledge_base)

# 種目別専門知識ベース
APPARATUS_KNOWLEDGE = {
    "FX": {
        "name": "床運動",
        "groups": {
            "I": "技術的グループ（筋力・バランス・柔軟性）",
            "II": "前方回転系",
            "III": "後方回転系", 
            "IV": "側方回転系"
        },
        "connection_rules": """【床運動の連続技ルール】
✅ 可能な組み合わせ：
- グループⅡ（前方系）＋ グループⅡまたはⅣ
- グループⅢ（後方系）＋ グループⅢまたはⅣ
- グループⅣ（側方系）＋ グループⅡまたはⅢ

【加点ルール】
- D難度以上 + D難度以上 = +0.2点
- D難度以上 + B/C難度 = +0.1点（双方向有効）

❌ 切り返し系（前方↔後方）は加点されません""",
        "specific_advice": "🤸‍♂️ **床運動特有のポイント**\n・70秒の時間制限を意識した構成\n・全フロアエリアを効果的に使用\n・着地の安定性を重視\n・音楽との調和も重要"
    },
    
    "PH": {
        "name": "あん馬",
        "groups": {
            "I": "シザースとシザース系の技",
            "II": "旋回とそのバリエーション", 
            "III": "移動とシフト",
            "IV": "入れ（フロップ）とシフト",
            "V": "下り技"
        },
        "connection_rules": """【あん馬の連続技特性】
・旋回技の連続性が最重要
・停止は大幅減点の対象
・脚の開閉リズムの一貫性
・移動技とシフト技の組み合わせ

【技術要求】
- 全演技を通じて旋回継続
- 片手支持での移動技
- 両ポメル上での技術的要素""",
        "specific_advice": "🐎 **あん馬特有のポイント**\n・旋回技の連続性が最重要\n・脚の開閉、移動のバランス\n・落下しない安定した構成を\n・停止は避けて流れを重視"
    },
    
    "SR": {
        "name": "つり輪",
        "groups": {
            "I": "けあがりとその変形",
            "II": "静止技（筋力要素）",
            "III": "ほん転系とその変形", 
            "IV": "下り技"
        },
        "connection_rules": """【つり輪の連続技ボーナス】
・十字懸垂(2秒) + 中水平支持(2秒): +0.2点
・倒立(2秒) + 十字懸垂(2秒): +0.1点

【技術要求】
- 静止技は2秒間保持必須
- 振動技との適切な組み合わせ
- 力技と振動技のバランス""",
        "specific_advice": "💍 **つり輪特有のポイント**\n・力技の2秒静止が必須\n・振動技と力技のバランス\n・肩の強化が重要\n・リング（輪）の安定性"
    },
    
    "VT": {
        "name": "跳馬",
        "groups": {
            "1": "前転系",
            "2": "ツカハラ系",
            "3": "ロンダート系",
            "4": "ハンドスプリング系", 
            "5": "ロンダート3/2ひねり系"
        },
        "connection_rules": """【跳馬の特性】
・1技のみで構成
・得点は1.2～5.6点の難度表による
・連続技ボーナスは適用されない

【技術要求】
- 助走の安定性とスピード
- 踏切板での正確な踏切
- 着地の確実性が最重要""",
        "specific_advice": "🏃‍♂️ **跳馬特有のポイント**\n・助走の安定性とスピード\n・踏切のタイミング\n・着地の確実性を最重視\n・1技で全てが決まる"
    },
    
    "PB": {
        "name": "平行棒", 
        "groups": {
            "I": "支持とけあがり",
            "II": "倒立系と静止技",
            "III": "振動技とほん転系",
            "IV": "下り技"
        },
        "connection_rules": """【平行棒の連続技】
・支持振動技の組み合わせ
・倒立技への移行ボーナス
・振動技と静止技の組み合わせ

【技術要求】
- 支持力と振動技の安定性
- 倒立の美しさと保持
- バー間の幅を活用した技""",
        "specific_advice": "🏋️‍♂️ **平行棒特有のポイント**\n・支持振動技の安定性\n・倒立の美しさ\n・力技との組み合わせ\n・バー幅を活用した構成"
    },
    
    "HB": {
        "name": "鉄棒",
        "groups": {
            "I": "長軸まわりの技",
            "II": "けあがりとその変形", 
            "III": "短軸まわりの技",
            "IV": "下り技"
        },
        "connection_rules": """【鉄棒の組合せ加点】
🎯 手放し技同士（グループⅡ + グループⅡ）
- C難度 + D難度以上: +0.10点（双方向）
- D難度 + D難度: +0.10点
- D難度以上 + E難度以上: +0.20点（双方向）

🎯 EGⅠまたはⅢの技 + 手放し技
- D難度以上（EGⅠ/Ⅲ）+ D難度（手放し技）: +0.10点
- D難度以上（EGⅠ/Ⅲ）+ E難度以上（手放し技）: +0.20点（双方向）""",
        "specific_advice": "🤸‍♂️ **鉄棒特有のポイント**\n・手放し技の成功率\n・車輪系技の連続性\n・終末技の着地安定性\n・スペクタクルな構成"
    }
}

# 2025-2028年版 FIG採点規則 専門知識ベース
SCORING_RULES_KNOWLEDGE = {
    "短い演技の減点": """【2025年版】短い演技に対するニュートラルディダクション（D審判適用）

| 技数 | ND減点 |
|------|--------|
| 8技 | 0.0点 |
| 7技 | 0.0点 |
| 6技 | 0.0点 |
| 5技 | 3.0点 |
| 4技 | 4.0点 |
| 3技 | 5.0点 |
| 2技 | 6.0点 |
| 1技 | 7.0点 |
| 0技 | 10.0点 |

※跳馬はND減点の対象外""",

    "角度逸脱減点": """【2025年版】角度逸脱による減点（E審判適用）

**静止技（力技）:**
- 5°未満: 減点なし
- 5°〜20°: -0.1点（小欠点）
- 20°〜45°: -0.3点（中欠点）
- 45°超: -0.5点（大欠点）+ 技の不認定

**振動技・回転技:**
- 15°未満: 減点なし
- 15°〜30°: -0.1点（小欠点）
- 30°〜45°: -0.3点（中欠点）
- 45°超: -0.5点（大欠点）+ 技の不認定

**鉄棒の倒立通過:**
- 30°未満: 減点なし
- 30°〜60°: -0.1点
- 60°〜90°: -0.3点
- 90°超: -0.5点 + 不認定""",

    "静止技要求": """【2025年版】静止技の要求と減点

**静止時間要求:**
- 必須時間: 2秒間
- 2秒以上: 減点なし
- 2秒未満: -0.3点（中欠点）
- 静止しない: -0.5点（大欠点）+ 技の不認定

**つり輪特別規定:**
- 力静止技への持ち込み時、最終姿勢より5°を超えて上がった場合: -0.1点
- 深い握り: -0.3点
- ケーブルにもたれる・足を絡める: 技の不認定""",

    "着地減点": """【2025年版】着地に関する減点

**基本的な着地エラー:**
- 開いた足が肩幅を超える: -0.1点
- 低い着地（腰が膝より下）: -0.5点
- 1歩動く: -0.1点
- 大きく動く: -0.3点
- 落下: -1.0点

**着地ボーナス（2025年新規）:**
- C難度以上の終末技で完璧な着地: +0.1点
- ※あん馬を除く全種目に適用

**ライン減点（ゆか・跳馬）:**
- 片足または片手がエリア外: -0.1点
- 両足・両手・体の他の部分がエリア外: -0.3点""",

    "グループ要求": """【2025年版】グループ要求と価値点

**グループ価値点:**
- D難度以上の技で満たされた各グループ: 0.5点
- A〜C難度の技で満たされた各グループ: 0.3点
- 全種目のグループⅠ: 難度に関わらず0.5点

**Dスコアにカウントされる技:**
- 最高7技 + 終末技 = 計8技（2025年改正）
- 同一グループから最大4技まで
- 跳馬は1技のみ""",

    "技術的減点": """【2025年版】技術的欠点による減点

**姿勢欠点:**
- 伸身姿勢で腰が60°以上曲がる: 屈身姿勢とみなす
- 屈身姿勢で膝が60°以上曲がる: かかえ込み姿勢とみなす
- 膝の曲がりが90°未満（かかえ込み姿勢）: 欠点

**力技・振動技の逆転:**
- 力技を振動で行う: -0.5点
- 振動技を力で行う: -0.5点

**中間振動:**
- 不必要な中間振動: -0.3点""",

    "競技参加者規則": """【2025年版】競技参加者に関する規則

**服装規定（男子）:**
- あん馬、つり輪、平行棒、鉄棒: 長いパンツと靴下着用
- ゆか、跳馬: 短パンツ可
- 体操用シューズまたは靴下着用可
- 黒色、濃い青・茶・緑色の衣服は禁止

**演技開始規則:**
- D1審判の合図（グリーンライト）から30秒以内に開始
- 60秒超過で演技終了とみなす

**落下後の規則:**
- 30秒以内に演技再開必須
- 60秒超過で演技終了とみなす

**コーチ規則:**
- 競技中の声援送信は違反行為
- 審判員との口論: 初回は0.3点減点 + イエローカード
- 平行棒でグリーンライト後もポディウムに留まれるのは安全上の理由のみ""",

    "審判団構成": """【2025年版】審判団の構成

**世界選手権・オリンピック:**
- D審判: 2名（D1、D2）
- E審判: 6名（最高点・最低点除外後、中間4名の平均）

**線審（ゆか）:**
- 4名配置（フロアエリアの4辺を監視）
- ライン減点の判定を担当

**新技認定:**
1. FIG公式競技会での実施
2. 技術委員会による承認
3. 選手名を付与する場合は国際的な知名度が必要""",

    "違反行為と罰則": """【2025年版】違反行為と罰則

**器械への水かけ:**
- あん馬や跳馬への霧吹き使用: 0.3点減点（器械の不適切使用）

**コーチ違反:**
- 競技中に選手に触れて補助: 該当技の難度不認定
- 許可なく競技エリアから離脱: 0.5点減点
- オーダーミス（チーム）: 失格

**プロテクター規則:**
- 断裂による演技中断: 選手にやり直しの権利あり

**跳馬ウォームアップ:**
- 50秒間で規定回数まで試技可能
- 規定超過: 0.3点減点""",

    "床運動詳細規則": """【2025年版】床運動（ゆか）詳細規則

**演技時間:**
- 最大70秒（従来の75秒から短縮）
- 60秒・70秒で音響合図
- 70秒超過: 0.3点減点

**必須要素:**
- 片足平均立ち技: 実施しない場合は0.3点減点
- 終末技: 2回以上の宙返り技必須、実施しない場合は0.3点減点
- カウント8技に含まれる必要あり

**技の制限:**
- 力技: 1演技中1回まで（最大価値1技のみカウント）
- 閉脚・開脚旋回: 1演技中1回まで  
- ロシアン転向技: 1演技中1回まで
- ロンダートから前方系への連続: 禁止

**禁止技:**
- 側方倒立回転1/4ひねり前向き着地（Tinsica）: 認められない
- この動きから実施された技も不認定

**アクロバット要求:**
- アクロバット前の停止: 3秒以上禁止
- D難度以上同士の直接連続: +0.2点
- 宙返りの高さ不足: 小・中・大欠点で判定

**ライン減点:**
- 片足または片手がエリア外: 0.1点
- 両足・両手・体の他部分がエリア外: 0.3点

**十字倒立要求:**
- 頭部が床から30cm以上の高さ必須""",

    "あん馬詳細規則": """【2025年版】あん馬詳細規則

**基本要求:**
- 全演技を通じて連続旋回必須
- 停止は大幅減点の対象

**角度・姿勢要求:**
- 交差技・片足振動で足先が肩の高さ未満: 0.3点減点
- 縦向き旋回で45°超の逸脱: 技の不認定
- 脚開き31°～60°: 0.1点減点

**技の制限:**
- 交差技から倒立: 最大2回（終末技除く）
- 開脚旋回技: 最大4回（終末技除く）  
- ロシアン旋回技: 最大2回（終末技含む）
- ショーン・ベズゴ系: 最大2回
- ブスナリ系: 最大1回

**終末技要求:**
- 倒立を経過しない場合: 肩の高さから60°以上の角度必須
- 落下・大過失: 最大1回やり直し可能

**特別規定:**
- ウ・グォニアン: 両手があん部に達するまでに360°転向完了必須
- フロップとコンバイン: 連続実施可能""",

    "つり輪詳細規則": """【2025年版】つり輪詳細規則

**静止技要求:**
- 全静止技: 2秒間保持必須
- 2秒未満: 0.3点減点
- 静止しない: 0.5点減点 + 技の不認定

**力静止技規定:**
- 持ち込み時、最終姿勢より5°超で上がる: 0.1点減点
- 深い握り: 0.3点減点
- 腕で体を支える（中水平支持）: 0.3点減点

**技の制限:**
- 同一終末姿勢の力静止技: 各グループ1技、合計最大3技
- グループⅡ・Ⅲ技を3回連続後: 振動技を経由してから次の力技実施

**特別ボーナス:**
- 十字懸垂(2秒) + 中水平支持(2秒): +0.2点
- 倒立(2秒) + 十字懸垂(2秒): +0.1点

**禁止事項:**
- ケーブルにもたれる・足を絡める: 技の不認定
- 振動倒立技(2秒)なし: D審判による減点

**ジュニア規定:**
- 十字懸垂・中水平支持: 禁止技""",

    "跳馬詳細規則": """【2025年版】跳馬詳細規則

**難度価値変更:**
- 全技の難度価値が0.4点減少
- 最高難度: 5.6点（従来6.0点から）

**種目別決勝:**
- 2本目に1本目と同じ技実施: 0点
- 技番号事前申告必須（異なる技実施でも減点なし）

**助走・跳越:**
- 助走やり直し: 認められるが0.3点減点
- ウォームアップ50秒中の規定超過: 0.3点減点

**着地エリア:**
- 片足または片手がエリア外: 0.1点減点
- 両足・両手・体の他部分がエリア外: 0.3点減点

**0点となるケース:**
1. 意図的な横向き着地
2. 跳馬台に触れずに跳越
3. 禁止行為の実施""",

    "平行棒詳細規則": """【2025年版】平行棒詳細規則

**演技開始:**
- 片足振りやステップでの開始: 許可されない

**技の方向原則:**
- 後ろ振り倒立後: 同方向への技実施必須

**単棒技規定:**
- 単棒技の倒立: 両手の幅を変えずに実施
- 単棒縦向き倒立からヒーリー系: 難度認定されず
- モイ・後方車輪系で膝曲げ: 体が水平位まで許可

**技の制限:**
- ベーレ系: 最大1回まで難度認定
- 後方車輪倒立技: 最大2回まで難度認定  
- 棒下宙返り倒立技: 最大1回まで難度認定

**マクーツ系規定:**
- 単棒横向き倒立で2秒以上停止: D審判は不認定、E審判は中欠点

**前振り上がり要求:**
- 背中がバーに対して水平必須
- 水平から45°超逸脱: 0.3点減点""",

    "鉄棒詳細規則": """【2025年版】鉄棒詳細規則

**倒立通過技:**
- アドラー・シュタルダーで30°～60°逸脱: 0.1点減点
- クーストで60°～90°逸脱: 0.3点減点

**手放し技:**
- 直接連続実施: 3技目まで認定（2連続の場合のみ）
- トカチェフ系: 最大2回まで実施可能
- コバチ系: 最大2回まで実施可能

**特殊技規定:**
- ツォ・リミン: 最初のひねり90°超逸脱で不認定・0.5点減点
- ヤマワキ: 45°超の腰曲がりで難度降格

**演技開始・終了:**
- 振り出し: 最大3回まで、超過で0.3点減点
- 倒立から懸垂への振り下ろし: 0.3点減点（中間振動）

**技の制限:**
- アドラー系: 最大3回まで実施可能
- 同一手放し技の反復制限あり""",

    "補足規則": """【2025年版】補足規則（A3-1、A4-e、A4-f）

**姿勢の定義（補足A3-1）:**
- 完全な屈身姿勢: 腰が90°以上曲がった姿勢
- 伸身姿勢で腰が60°以上曲がる: 屈身姿勢とみなす
- 屈身姿勢で膝が60°以上曲がる: かかえ込み姿勢とみなす
- かかえ込み姿勢で膝の曲がりが90°未満: 欠点

**ゆかの十字倒立（補足A3-1）:**
- 頭部が床面から最低30cm以上の高さに位置すること

**平行棒の宙返り技（補足A4-e）:**
- 単棒縦向きで握る技: もう一方のバーに移す前に明確な縦向き姿勢を示す必要

**中間姿勢による不認定（補足A4-f）:**
- つり輪で例示される技: 「ヤマワキ」「ジョナサン」
- これらの技で中間姿勢が見られる場合、D審判による不認定となる可能性""",

    "詳細技術規則": """【2025年版】詳細技術規則

**D審判による技の不認定:**
1. 45°を超える角度逸脱
2. 静止技で静止しない場合
3. 規定の姿勢を満たさない場合

**宙返りの高さ判定:**
- 高さ・大きさ不足の判定基準は技の種類と期待される軌道による
- 小欠点（0.1）、中欠点（0.3）、大欠点（0.5）の段階的評価

**技のカウント制限:**
- Dスコアには最高7技＋終末技の計8技がカウント
- 同一グループから最大4技まで有効（2025年改正）

**着地マット構成（つり輪・鉄棒）:**
- FIG規定により適切な厚さと材質の着地マットが必須
- 安全性確保のため規定サイズ以上のマット配置

**ウォームアップ時間:**
- 団体総合予選・決勝: 各種目規定時間のウォームアップ
- 種目別: 跳馬50秒、その他種目は規定による

**鉄棒手放し技の準備:**
- 車輪変形が準備局面の場合、倒立通過なしでも減点されない条件あり"""
}

# 汎用知識ベース（従来の機能を維持）
GYMNASTICS_KNOWLEDGE = {
    "nd減点": """ND（ニュートラルディダクション）減点：

【主なND減点】
- 演技時間超過/不足: 0.1〜0.3点
- ライン減点: 0.1点/回（片足・両足とも）
- 服装違反: 0.3点
- コーチの違反行為: 0.5点
- 器械の不適切な使用: 0.5点

これらは演技実施点とは別に減点されます。""",
    
    "演技構成分析": """演技構成分析のポイント：

【2025年版 Dスコアの構成要素】
1. 難度点合計（最高7技+終末技=計8技、跳馬は1技）
2. グループボーナス（D難度以上0.5点、A-C難度0.3点）
3. 連続技ボーナス（CV）
4. 終末技グループ加点（該当種目のみ）

【最適化のコツ】
- 高難度技を効率的に配置
- 連続技で加点を狙う
- グループ要求を確実に満たす
- 体力配分を考慮した構成"""
}

@app.get("/")
def read_root():
    return {"Hello": "World", "Port": os.getenv("PORT", "8080")}

@app.get("/health")
def health():
    return {"status": "ok"}

def load_knowledge_base():
    """知識ベースファイルを動的に読み込み"""
    knowledge = {}
    knowledge_files = [
        "data/d_score_master_knowledge.md",
        "data/rulebook_ja_summary.md", 
        "data/apparatus_details.md",
        "data/difficulty_calculation_system.md"
    ]
    
    for file_path in knowledge_files:
        try:
            if os.path.exists(file_path):
                with open(file_path, 'r', encoding='utf-8') as f:
                    knowledge[file_path] = f.read()
        except Exception as e:
            print(f"Warning: Could not load {file_path}: {e}")
    
    return knowledge

def analyze_routine_and_suggest_improvements(message):
    """演技構成分析を受けて改善提案を生成 - 高度版"""
    
    # 知識ベースを読み込み
    knowledge_base = load_knowledge_base()
    
    # メッセージから数値データを抽出
    import re
    
    # より詳細なデータ抽出
    d_score_match = re.search(r'Dスコア:\s*([\d.]+)', message)
    difficulty_match = re.search(r'難度点:\s*([\d.]+)', message)
    group_match = re.search(r'グループ要求.*?(\d+)/(\d+)', message)
    connection_match = re.search(r'連続技ボーナス:\s*([\d.]+)', message)
    skill_count_match = re.search(r'技数:\s*(\d+)', message)
    apparatus_match = re.search(r'- 種目:\s*([A-Z]{2})', message)
    nd_match = re.search(r'ND減点:\s*(-?[\d.]+)', message)
    missing_groups_match = re.search(r'不足グループ:\s*(.+)', message)
    
    # 抽出したデータ
    d_score = float(d_score_match.group(1)) if d_score_match else 0.0
    difficulty_value = float(difficulty_match.group(1)) if difficulty_match else 0.0
    fulfilled_groups = int(group_match.group(1)) if group_match else 0
    required_groups = int(group_match.group(2)) if group_match else 4
    connection_bonus = float(connection_match.group(1)) if connection_match else 0.0
    skill_count = int(skill_count_match.group(1)) if skill_count_match else 0
    apparatus = apparatus_match.group(1) if apparatus_match else None
    nd_deduction = float(nd_match.group(1)) if nd_match else 0.0
    missing_groups_text = missing_groups_match.group(1) if missing_groups_match else ""
    
    # 種目が検出できない場合のエラーハンドリング
    if not apparatus:
        return {
            "response": "申し訳ございません。種目情報を正しく読み取れませんでした。分析結果に「- 種目: [種目コード]」の形式で種目情報が含まれているかご確認ください。",
            "conversation_id": "error_001"
        }
    
    # 有効な種目コードのチェック
    valid_apparatus = ["FX", "PH", "SR", "VT", "PB", "HB"]
    if apparatus not in valid_apparatus:
        return {
            "response": f"種目コード「{apparatus}」は認識できません。有効な種目コード：FX（床）、PH（あん馬）、SR（つり輪）、VT（跳馬）、PB（平行棒）、HB（鉄棒）",
            "conversation_id": "error_002"
        }
    
    # 高度な構成分析の実施
    analysis_result = perform_advanced_analysis(
        apparatus, d_score, difficulty_value, fulfilled_groups, required_groups,
        connection_bonus, skill_count, nd_deduction, missing_groups_text, knowledge_base
    )
    
    return {
        "response": analysis_result,
        "conversation_id": "advanced_analysis_001"
    }

def perform_advanced_analysis(apparatus, d_score, difficulty_value, fulfilled_groups, 
                            required_groups, connection_bonus, skill_count, nd_deduction,
                            missing_groups_text, knowledge_base):
    """高度な演技構成分析を実行"""
    
    # 跳馬の特別処理
    if apparatus == "VT":
        return generate_vault_analysis(d_score, skill_count)
    
    # 分析結果の構築
    analysis_sections = []
    
    # 1. 現在の構成評価
    current_status = generate_current_status_analysis(
        apparatus, d_score, difficulty_value, skill_count, fulfilled_groups, required_groups
    )
    analysis_sections.append(current_status)
    
    # 2. 重要な問題点の特定
    critical_issues = identify_critical_issues(
        apparatus, fulfilled_groups, required_groups, nd_deduction, skill_count, connection_bonus
    )
    if critical_issues:
        analysis_sections.append(f"🚨 **緊急改善ポイント**\n{critical_issues}")
    
    # 3. 種目別専門アドバイス
    specialized_advice = generate_apparatus_specific_advice(
        apparatus, fulfilled_groups, required_groups, connection_bonus, knowledge_base
    )
    analysis_sections.append(specialized_advice)
    
    # 4. ND減点の詳細説明
    if nd_deduction > 0:
        nd_explanation = explain_nd_deductions(nd_deduction, apparatus, knowledge_base)
        analysis_sections.append(nd_explanation)
    
    # 5. 具体的改善戦略
    improvement_strategy = generate_improvement_strategy(
        apparatus, d_score, difficulty_value, skill_count, fulfilled_groups, 
        required_groups, connection_bonus, knowledge_base
    )
    analysis_sections.append(improvement_strategy)
    
    # 6. 追加質問への対応
    analysis_sections.append("💬 **さらに詳しく知りたい方へ**\n具体的な技の推奨、練習方法、ルール詳細などご質問ください！")
    
    return "\n\n".join(analysis_sections)

def generate_vault_analysis(d_score, skill_count):
    """跳馬専用分析"""
    if skill_count == 0:
        return "**跳馬技を選択してください**\n\n何かご質問があればお答えします。"
    else:
        return f"""**🤸‍♂️ 跳馬分析結果**

**現在のDスコア: {d_score:.1f}点**

跳馬では1本または2本の技でDスコアが決定されます。
より高難度の技への挑戦で得点向上が可能です。

何かご質問があればお答えします。"""

def generate_current_status_analysis(apparatus, d_score, difficulty_value, skill_count, fulfilled_groups, required_groups):
    """現在の構成状況分析"""
    apparatus_names = {"FX": "床運動", "PH": "あん馬", "SR": "つり輪", "PB": "平行棒", "HB": "鉄棒"}
    apparatus_name = apparatus_names.get(apparatus, apparatus)
    
    avg_difficulty = difficulty_value / skill_count if skill_count > 0 else 0
    group_completion = (fulfilled_groups / required_groups) * 100 if required_groups > 0 else 100
    
    status_emoji = "✅" if group_completion >= 100 and skill_count >= 6 else "⚠️"
    
    return f"""**{status_emoji} {apparatus_name}構成分析結果**

📊 **基本データ**
• Dスコア: {d_score:.1f}点
• 技数: {skill_count}技
• 平均難度: {avg_difficulty:.2f}点
• グループ達成度: {fulfilled_groups}/{required_groups} ({group_completion:.0f}%)"""

def identify_critical_issues(apparatus, fulfilled_groups, required_groups, nd_deduction, skill_count, connection_bonus):
    """重要な問題点を特定"""
    issues = []
    
    # グループ要求不足の深刻度評価
    if fulfilled_groups < required_groups:
        missing = required_groups - fulfilled_groups
        severity = "⛔ 極めて重要" if missing >= 2 else "🔴 重要"
        issues.append(f"{severity}: {missing}グループが不足しています")
    
    # 技数不足チェック
    if skill_count < 6:
        issues.append("🔴 重要: 技数が極端に少ないです（最低6技推奨）")
    
    # ND減点の深刻度
    if nd_deduction > 0.5:
        issues.append(f"⛔ 極めて重要: ND減点が-{nd_deduction:.1f}点と高額です")
    elif nd_deduction > 0:
        issues.append(f"🔴 重要: ND減点-{nd_deduction:.1f}点が発生しています")
    
    # 連続技ボーナス未活用
    if apparatus in ["FX", "HB"] and connection_bonus == 0:
        issues.append("🟡 改善余地: 連続技ボーナスが未活用です")
    
    return "\n".join([f"• {issue}" for issue in issues]) if issues else ""

def generate_apparatus_specific_advice(apparatus, fulfilled_groups, required_groups, connection_bonus, knowledge_base):
    """種目別専門アドバイス（知識ベース活用版）"""
    apparatus_names = {"FX": "床運動", "PH": "あん馬", "SR": "つり輪", "PB": "平行棒", "HB": "鉄棒"}
    apparatus_name = apparatus_names.get(apparatus, apparatus)
    
    advice_sections = [f"🎯 **{apparatus_name}専門アドバイス**"]
    
    # 基本的な種目特性を知識ベースから抽出
    if apparatus in APPARATUS_KNOWLEDGE:
        apparatus_data = APPARATUS_KNOWLEDGE[apparatus]
        advice_sections.append(apparatus_data["specific_advice"])
        
        # グループ要求の詳細説明
        if fulfilled_groups < required_groups:
            missing = required_groups - fulfilled_groups
            advice_sections.append(f"""
🚨 **グループ要求分析**
• 不足: {missing}グループ
• 各グループの特徴:""")
            
            for group, description in apparatus_data["groups"].items():
                advice_sections.append(f"  • グループ{group}: {description}")
    
    # 知識ベースから高度なアドバイスを生成
    advanced_advice = extract_advanced_apparatus_advice(apparatus, knowledge_base)
    if advanced_advice:
        advice_sections.append(advanced_advice)
    
    return "\n".join(advice_sections)

def extract_advanced_apparatus_advice(apparatus, knowledge_base):
    """知識ベースから高度なアドバイスを抽出"""
    apparatus_keywords = {
        "FX": ["床運動", "floor", "タンブリング", "連続技"],
        "PH": ["あん馬", "pommel", "旋回", "シザース"],
        "SR": ["つり輪", "rings", "静止技", "筋力"],
        "PB": ["平行棒", "parallel", "支持", "振動"],
        "HB": ["鉄棒", "horizontal", "手放し", "大車輪"]
    }
    
    if apparatus not in apparatus_keywords:
        return ""
    
    keywords = apparatus_keywords[apparatus]
    advice_parts = []
    
    # 知識ベースから関連情報を検索
    for file_path, content in knowledge_base.items():
        if any(keyword in content for keyword in keywords):
            # 種目関連の重要情報を抽出（簡易版）
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if any(keyword in line for keyword in keywords):
                    # 関連セクションを数行取得
                    section_lines = lines[max(0, i-1):i+3]
                    relevant_text = '\n'.join(section_lines).strip()
                    if len(relevant_text) > 20 and relevant_text not in advice_parts:
                        advice_parts.append(relevant_text[:200] + "..." if len(relevant_text) > 200 else relevant_text)
                        break  # 各ファイルから1つずつ
    
    if advice_parts:
        return f"📚 **公式ルール準拠アドバイス**\n" + "\n\n".join(advice_parts[:2])  # 最大2つまで
    
    return ""

def explain_nd_deductions(nd_deduction, apparatus, knowledge_base):
    """ND減点の詳細説明"""
    explanation = f"⚠️ **ND減点詳細分析 (-{nd_deduction:.1f}点)**\n"
    
    # 一般的なND減点要因
    common_nd_causes = {
        "FX": ["グループ要求不足", "終末技以外での着地", "時間超過・不足"],
        "PH": ["グループ要求不足", "旋回停止", "下り技なし"],
        "SR": ["グループ要求不足", "静止技不足", "下り技なし"],
        "PB": ["グループ要求不足", "下り技なし"],
        "HB": ["グループ要求不足", "手放し技不足", "下り技なし"]
    }
    
    if apparatus in common_nd_causes:
        explanation += "**主な減点要因の可能性:**\n"
        for cause in common_nd_causes[apparatus]:
            explanation += f"• {cause}\n"
    
    # 知識ベースからND減点ルールを検索
    nd_rules = search_nd_rules_in_knowledge_base(apparatus, knowledge_base)
    if nd_rules:
        explanation += f"\n**公式ルール:**\n{nd_rules}"
    
    explanation += f"\n💡 **改善のヒント:** 構成を見直して上記要因を解消すれば{nd_deduction:.1f}点の回復が期待できます。"
    
    return explanation

def search_nd_rules_in_knowledge_base(apparatus, knowledge_base):
    """知識ベースからND減点ルールを検索"""
    search_keywords = ["ND", "減点", "グループ要求", "終末技"]
    
    for file_path, content in knowledge_base.items():
        if "nd" in file_path.lower() or "減点" in content:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if any(keyword in line for keyword in search_keywords):
                    # 関連する数行を抽出
                    section = '\n'.join(lines[max(0, i-1):i+3]).strip()
                    if len(section) > 10:
                        return section[:300] + "..." if len(section) > 300 else section
    
    return ""

def generate_improvement_strategy(apparatus, d_score, difficulty_value, skill_count, 
                                fulfilled_groups, required_groups, connection_bonus, knowledge_base):
    """具体的改善戦略の生成"""
    strategy = "🚀 **改善戦略**\n"
    
    improvements = []
    potential_gain = 0
    
    # 1. グループ要求改善
    if fulfilled_groups < required_groups:
        missing = required_groups - fulfilled_groups
        potential_gain += missing * 0.5  # グループ要求ボーナス
        improvements.append(f"✅ 優先度1: {missing}グループ追加 (+{missing * 0.5:.1f}点期待)")
    
    # 2. 技数追加
    if skill_count < 8:
        additional_skills = min(8 - skill_count, 2)  # 最大2技追加を推奨
        potential_gain += additional_skills * 0.3  # 平均難度想定
        improvements.append(f"✅ 優先度2: {additional_skills}技追加 (+{additional_skills * 0.3:.1f}点期待)")
    
    # 3. 連続技ボーナス
    if apparatus in ["FX", "HB"] and connection_bonus < 0.2:
        bonus_potential = 0.2 - connection_bonus
        potential_gain += bonus_potential
        improvements.append(f"✅ 優先度3: 連続技強化 (+{bonus_potential:.1f}点期待)")
    
    # 4. 難度向上
    avg_difficulty = difficulty_value / skill_count if skill_count > 0 else 0
    if avg_difficulty < 0.4:
        improvements.append("✅ 長期目標: 技の難度向上 (+0.2～0.5点期待)")
        potential_gain += 0.3
    
    if improvements:
        strategy += "\n".join(improvements)
        strategy += f"\n\n📈 **期待効果:** 最大 +{potential_gain:.1f}点 → 目標Dスコア {d_score + potential_gain:.1f}点"
    else:
        strategy += "🌟 現在の構成は既に最適化されています！\n更なる向上には高難度技への挑戦をご検討ください。"
    
    return strategy

def get_apparatus_specific_advice(apparatus, fulfilled_groups, required_groups):
    """従来の種目別アドバイス（互換性維持）"""
    if apparatus not in APPARATUS_KNOWLEDGE:
        return ""
    
    apparatus_data = APPARATUS_KNOWLEDGE[apparatus]
    advice = apparatus_data["specific_advice"]
    
    # グループ要求の詳細分析
    if fulfilled_groups < required_groups:
        missing_groups = required_groups - fulfilled_groups
        group_info = apparatus_data["groups"]
        
        advice += f"\n\n🎯 **グループ要求の詳細**\n"
        advice += f"・現在{fulfilled_groups}/{required_groups}グループを満たしています\n"
        advice += f"・不足している{missing_groups}グループの技を追加してください\n\n"
        
        # 各グループの説明を追加
        advice += "**各グループの特徴**:\n"
        for group, description in group_info.items():
            advice += f"・グループ{group}: {description}\n"
    
    # 連続技ルールの追加
    if "connection_rules" in apparatus_data:
        advice += f"\n\n📋 **連続技ルール**\n{apparatus_data['connection_rules']}"
    
    return advice

@app.post("/chat/message")
async def chat(data: dict):
    try:
        message = data.get("message", "")
        if not message.strip():
            return {"response": "質問を入力してください。", "conversation_id": "error_empty"}
        
        # コンテキスト情報を抽出
        context = {
            "apparatus": data.get("apparatus"),
            "d_score": data.get("d_score"),
            "skill_count": data.get("skill_count"),
            "group_fulfillment": data.get("group_fulfillment")
        }
        
        # インテリジェントAIで回答を生成
        logger.info(f"Processing question: {message[:100]}...")
        response = await intelligent_ai.get_intelligent_response(message, context)
        
        return {
            "response": response,
            "conversation_id": "intelligent_ai_001"
        }
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        # 最終フォールバック
        return {
            "response": """申し訳ございません。一時的にサービスに問題が発生しています。

体操競技について基本的なご質問にはお答えできます：
• 各種目の技術と特徴
• 採点システムとルール
• 演技構成のアドバイス

もう一度お試しください。""",
            "conversation_id": "error_fallback"
        }

# 従来の機能を維持するため、既存のロジックもバックアップとして保持
@app.post("/chat/message/legacy")
def chat_legacy(data: dict):
    
    # 種目別の知識検索
    apparatus_keywords = {
        "あん馬": "PH", "ph": "PH", "pommel": "PH",
        "つり輪": "SR", "sr": "SR", "rings": "SR", "静止技": "SR",
        "跳馬": "VT", "vt": "VT", "vault": "VT",
        "平行棒": "PB", "pb": "PB", "parallel": "PB",
        "鉄棒": "HB", "hb": "HB", "horizontal": "HB", "手放し": "HB",
        "床": "FX", "fx": "FX", "floor": "FX", "ゆか": "FX"
    }
    
    # 種目特有の質問への対応
    for keyword, apparatus in apparatus_keywords.items():
        if keyword in message:
            if apparatus in APPARATUS_KNOWLEDGE:
                apparatus_data = APPARATUS_KNOWLEDGE[apparatus]
                response = f"""**{apparatus_data['name']}**について詳しくお答えします！\n\n"""
                
                # 連続技やルールについての質問
                if any(word in message for word in ["連続技", "ルール", "構成", "要求"]):
                    response += apparatus_data.get("connection_rules", "")
                    response += f"\n\n{apparatus_data['specific_advice']}"
                
                # グループについての質問  
                elif "グループ" in message:
                    response += "**グループ構成**:\n"
                    for group, desc in apparatus_data["groups"].items():
                        response += f"・グループ{group}: {desc}\n"
                    response += f"\n{apparatus_data['specific_advice']}"
                
                # 一般的な質問
                else:
                    response += apparatus_data["specific_advice"]
                    if "connection_rules" in apparatus_data:
                        response += f"\n\n{apparatus_data['connection_rules']}"
                
                return {
                    "response": response,
                    "conversation_id": "apparatus_001"
                }
    
    # 採点規則の詳細検索
    scoring_keywords = {
        "短い演技": "短い演技の減点",
        "技数": "短い演技の減点", 
        "nd減点": "短い演技の減点",
        "ニュートラル": "短い演技の減点",
        "角度": "角度逸脱減点",
        "逸脱": "角度逸脱減点",
        "静止技": "静止技要求",
        "2秒": "静止技要求",
        "静止時間": "静止技要求",
        "着地": "着地減点",
        "ライン": "着地減点",
        "グループ": "グループ要求",
        "価値点": "グループ要求",
        "技術的": "技術的減点",
        "姿勢": "技術的減点",
        "中間振動": "技術的減点",
        "服装": "競技参加者規則",
        "コーチ": "競技参加者規則",
        "グリーンライト": "競技参加者規則",
        "演技開始": "競技参加者規則",
        "落下": "競技参加者規則",
        "審判": "審判団構成",
        "新技": "審判団構成",
        "違反": "違反行為と罰則",
        "霧吹き": "違反行為と罰則",
        "プロテクター": "違反行為と罰則",
        "床運動": "床運動詳細規則",
        "ゆか": "床運動詳細規則",
        "アクロバット": "床運動詳細規則",
        "片足平均": "床運動詳細規則",
        "70秒": "床運動詳細規則",
        "あん馬": "あん馬詳細規則",
        "旋回": "あん馬詳細規則",
        "交差技": "あん馬詳細規則",
        "ショーン": "あん馬詳細規則",
        "ベズゴ": "あん馬詳細規則",
        "つり輪": "つり輪詳細規則",
        "十字懸垂": "つり輪詳細規則",
        "中水平": "つり輪詳細規則",
        "跳馬": "跳馬詳細規則",
        "助走": "跳馬詳細規則",
        "種目別決勝": "跳馬詳細規則",
        "平行棒": "平行棒詳細規則",
        "単棒": "平行棒詳細規則",
        "ヒーリー": "平行棒詳細規則",
        "ベーレ": "平行棒詳細規則",
        "マクーツ": "平行棒詳細規則",
        "鉄棒": "鉄棒詳細規則",
        "手放し": "鉄棒詳細規則",
        "アドラー": "鉄棒詳細規則",
        "トカチェフ": "鉄棒詳細規則",
        "コバチ": "鉄棒詳細規則",
        "補足": "補足規則",
        "屈身姿勢": "補足規則",
        "十字倒立": "補足規則",
        "30cm": "補足規則",
        "ヤマワキ": "補足規則",
        "ジョナサン": "補足規則",
        "90度": "補足規則",
        "60度": "補足規則",
        "tinsica": "床運動詳細規則",
        "側方倒立": "床運動詳細規則",
        "不認定": "詳細技術規則",
        "着地マット": "詳細技術規則",
        "ウォームアップ": "詳細技術規則",
        "団体総合": "詳細技術規則",
        "車輪変形": "詳細技術規則"
    }
    
    for keyword, rule_key in scoring_keywords.items():
        if keyword in message:
            if rule_key in SCORING_RULES_KNOWLEDGE:
                return {
                    "response": SCORING_RULES_KNOWLEDGE[rule_key],
                    "conversation_id": "scoring_001"
                }
    
    # 汎用知識ベースから検索
    for keyword, knowledge in GYMNASTICS_KNOWLEDGE.items():
        if keyword in message:
            return {
                "response": knowledge,
                "conversation_id": "test_001"
            }
    
    # つり輪の技について（詳細版）
    if "つり輪" in message and ("d難度" in message or "d級" in message):
        return {
            "response": """つり輪のD難度技（0.4点）詳細：

【主要なD難度技】
• **中水平** - 両腕を水平に保つ静止技（2秒保持）
• **後方車輪倒立** - 後方回転から倒立位へ
• **前方車輪倒立** - 前方回転から倒立位へ
• **ホンマ1回ひねり** - 懸垂から1回ひねって倒立
• **振動倒立** - 大きな振動から倒立位へ
• **アザリアン** - 十字懸垂から押し上げて支持

【採点ポイント】
- 静止技は2秒間の保持が必須
- 振動技は正確な技術実施が重要
- 力技と振動技のバランスが評価される""",
            "conversation_id": "test_001"
        }
    
    # 床運動について（詳細版）
    if "床" in message and ("ルール" in message or "構成" in message or "要求" in message):
        return {
            "response": """床運動の詳細ルール：

【基本規定】
- 演技エリア: 12m×12m
- 演技時間: 男子70秒以内、女子90秒以内
- 時間超過: -0.1点（2秒まで）、-0.3点（2秒超）

【構成要求（男子）】
1. 前方系アクロバット技
2. 後方系アクロバット技  
3. 側方系アクロバット技
4. 力技または静止技

【主な減点】
- ライン減点: 0.1点/回
- 着地の乱れ: 0.1〜1.0点
- 技の不完全実施: 0.1〜0.5点""",
            "conversation_id": "test_001"
        }
    
    # 演技構成分析結果への対応
    if "演技構成分析結果" in message or "dスコア" in message or "改善提案" in message:
        return analyze_routine_and_suggest_improvements(message)
    
    # 一般的な体操の挨拶
    if any(word in message for word in ["こんにちは", "はじめまして", "よろしく"]):
        return {
            "response": """AIアシスタントです！🏅

FIG公式ルールに基づいた正確な情報を提供します：
• 技の難度・採点基準
• 連続技（CV）の組み合わせ  
• ND減点の詳細
• 各種目の構成要求
• 演技構成の最適化アドバイス

何でもお気軽にご質問ください！""",
            "conversation_id": "test_001"
        }
    
    # デフォルト回答
    return {
        "response": f"""「{data.get("message", "")}」についてお答えします。

体操競技の専門的な質問により詳しくお答えできます：
• 各種目の技と難度
• FIG公式ルールの解説
• 演技構成の分析とアドバイス
• 採点基準と減点項目

どのような情報をお探しですか？""",
        "conversation_id": "test_001"
    }