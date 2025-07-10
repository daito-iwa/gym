# D-Score Calculator Logic
# This file will contain the logic for calculating the D-score of a gymnastics routine.

import os
import json
import pandas as pd
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain.chains import LLMChain
from langchain.memory import ConversationBufferMemory
from langchain.chains import ConversationalRetrievalChain
from langchain.prompts import PromptTemplate
from collections import defaultdict
from itertools import combinations

# --- 定数定義 ---
DIFFICULTY_VALUES = { "A": 0.1, "B": 0.2, "C": 0.3, "D": 0.4, "E": 0.5, "F": 0.6, "G": 0.7, "H": 0.8, "I": 0.9, "J": 1.0 }

# --- Skill Database Loader ---
def load_skills_from_csv(lang="en"):
    """
    選択された言語に応じて、対応する 'skills_xx.csv' ファイルを読み込む。
    """
    csv_path = f"data/skills_{lang}.csv"
    if not os.path.exists(csv_path):
        return defaultdict(list)

    try:
        df = pd.read_csv(csv_path)
        # 難度(数値)のカラムを追加
        df['value'] = df['value_letter'].map(DIFFICULTY_VALUES).fillna(0.0)
        
        skill_database = defaultdict(list)
        for _, row in df.iterrows():
            # CSVの 'apparatus' 列には "FX", "PH" のようなコードが入ることを期待
            skill_database[row['apparatus']].append(row.to_dict())
        
        # 技を名前でソート
        for apparatus in skill_database:
            skill_database[apparatus] = sorted(skill_database[apparatus], key=lambda x: x['name'])
            
        return skill_database
    except Exception as e:
        print(f"Error loading skills from {csv_path}: {e}")
        return defaultdict(list)

# 各種目のDスコア計算ルール (キーを言語非依存のコードに変更)
APPARATUS_RULES = {
    "FX": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "PH": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
    "SR": {"count_limit": 8, "groups_required": 4, "bonus_per_group": 0.5},
    "VT": {"count_limit": 1, "groups_required": 0, "bonus_per_group": 0.0},
    "PB": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
    "HB": {"count_limit": 8, "groups_required": 5, "bonus_per_group": 0.5},
}

# 連続技ボーナスのルール (キーを言語非依存のコードに変更)
CONNECTION_RULES = {
    "FX": [
        # 床運動の連続技ボーナス
        # 基本ルール: D難度以上 ＋ D難度以上 → 加点0.2
        {
            "from_group": [2, 3, 4], 
            "to_group": [2, 3, 4],
            "from_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "to_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "bonus": 0.2,
            "bidirectional": False,
            "additional_condition": "no_group4_both"
        },
        # 基本ルール: D難度以上 ＋ B/C難度 → 加点0.1
        {
            "from_group": [2, 3, 4], 
            "to_group": [2, 3, 4],
            "from_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "to_value": ["B", "C"], 
            "bonus": 0.1,
            "bidirectional": True,
            "additional_condition": "no_group4_both"
        }
    ],
    "HB": [
        # アドラー系（グループⅠ,Ⅲ） ＋ グループⅡの連続
        {
            "from_group": [1, 3], 
            "to_group": [2],
            "from_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "to_value": ["E", "F", "G", "H", "I", "J"], 
            "bonus": 0.2,
            "bidirectional": True
        },
        {
            "from_group": [1, 3], 
            "to_group": [2],
            "from_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "to_value": ["D"], 
            "bonus": 0.1,
            "bidirectional": True
        },
        # 離れ技(グループⅡ)の連続
        {
            "from_group": [2], 
            "to_group": [2],
            "from_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "to_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "bonus": 0.2,
            "bidirectional": False
        },
        {
            "from_group": [2], 
            "to_group": [2],
            "from_value": ["C"], 
            "to_value": ["D", "E", "F", "G", "H", "I", "J"], 
            "bonus": 0.1,
            "bidirectional": False
        },
    ]
}

def get_dismount_skill(apparatus, routine):
    """
    演技から終末技を検出する
    """
    if not routine or apparatus == "VT":  # 跳馬は終末技概念が異なる
        return None
    
    # 最後のグループの最後の技を終末技とする
    last_group = routine[-1]
    if last_group:
        return last_group[-1]
    return None

def calculate_dismount_group_bonus(apparatus, dismount_skill):
    """
    終末技の難度による追加グループ点を計算する
    ルール: 終末技のグループ点は、終末技の難度価値点と同じ点数
    """
    if not dismount_skill or apparatus == "VT":  # 跳馬は終末技グループ加点対象外
        return 0.0
    
    # 終末技の難度価値点と同じ点数をグループ加点として追加
    return dismount_skill.get('value', 0.0)

def calculate_landing_bonus_potential(apparatus, dismount_skill):
    """
    着地加点の可能性を計算する（着地を止めた場合の参考用）
    """
    if not dismount_skill or apparatus in ["VT", "PH"]:  # 跳馬・あん馬は着地加点対象外
        return 0.0
    
    # C難度以上の終末技の場合、着地加点の可能性がある
    dismount_value = dismount_skill.get('value', 0.0)
    if dismount_value >= 0.3:  # C難度以上
        return 0.1
    
    return 0.0

def calculate_d_score(apparatus, routine):
    """
    演技構成(routine)に基づいてDスコアを計算する。
    routineの構造: [[技A], [技B, 技C], [技D], ...]
    """
    if not routine or apparatus not in APPARATUS_RULES:
        # エラー時も、UIが必要とするデータ構造を返すようにする
        return 0.0, {"fulfilled": 0, "required": 0}, 0.0, 0.0, 0.0, 0

    rules = APPARATUS_RULES[apparatus]
    count_limit = rules["count_limit"]
    
    all_skills = [skill for group in routine for skill in group]
    total_skills_in_routine = len(all_skills)

    counted_skills = []

    if total_skills_in_routine > count_limit:
        best_combination = []
        max_score = -1

        # 技の組み合わせ(最大8つ)をすべて試す
        for skill_combination in combinations(all_skills, count_limit):
            # この組み合わせでのスコアを計算
            temp_difficulty_value = sum(s['value'] for s in skill_combination)
            
            temp_fulfilled_groups = set(s['group'] for s in skill_combination)
            temp_group_bonus = len(temp_fulfilled_groups) * rules["bonus_per_group"]
            
            current_score = temp_difficulty_value + temp_group_bonus
            
            if current_score > max_score:
                max_score = current_score
                best_combination = list(skill_combination)
        
        counted_skills = best_combination
    else:
        counted_skills = all_skills
    
    # 1. 難度点の合計
    difficulty_value = sum(skill['value'] for skill in counted_skills)
    
    # 2. グループ要求ボーナス
    fulfilled_groups = set(skill['group'] for skill in counted_skills)
    num_fulfilled_groups = len(fulfilled_groups)
    group_bonus = num_fulfilled_groups * rules["bonus_per_group"]
    
    # 3. 終末技による追加グループボーナス
    dismount_skill = get_dismount_skill(apparatus, routine)
    dismount_group_bonus = calculate_dismount_group_bonus(apparatus, dismount_skill)
    
    # 4. 着地加点の可能性（参考用）
    landing_bonus_potential = calculate_landing_bonus_potential(apparatus, dismount_skill)
    
    # 5. 連続技ボーナス
    connection_bonus = 0.0
    connection_rules_for_apparatus = CONNECTION_RULES.get(apparatus, [])
    if connection_rules_for_apparatus:
        # 入れ子になった構成(routine)をチェック
        for connection_group in routine:
            if len(connection_group) > 1: # 技が2つ以上連続している場合
                for i in range(len(connection_group) - 1):
                    skill1 = connection_group[i]
                    skill2 = connection_group[i+1]
                    
                    for rule in connection_rules_for_apparatus:
                        # 順方向のチェック
                        from_group_match = "from_group" not in rule or skill1.get("group", 0) in rule["from_group"]
                        to_group_match = "to_group" not in rule or skill2.get("group", 0) in rule["to_group"]
                        from_value_match = rule["from_value"] is None or skill1["value_letter"] in rule["from_value"]
                        to_value_match = rule["to_value"] is None or skill2["value_letter"] in rule["to_value"]
                        
                        # 追加条件のチェック
                        additional_condition_met = True
                        if rule.get("additional_condition") == "one_must_be_d_or_higher":
                            # 少なくとも一つはD難度以上である必要がある
                            d_or_higher = ["D", "E", "F", "G", "H", "I", "J"]
                            additional_condition_met = (skill1["value_letter"] in d_or_higher or 
                                                       skill2["value_letter"] in d_or_higher)
                        elif rule.get("additional_condition") == "different_skills":
                            # 異なる技である必要がある
                            additional_condition_met = skill1.get("id") != skill2.get("id")
                        elif rule.get("additional_condition") == "strength_to_dynamic":
                            # 静的技から動的技への連続（つり輪）
                            additional_condition_met = True  # 基本的なグループチェックで十分
                        elif rule.get("additional_condition") == "dynamic_to_strength":
                            # 動的技から静的技への連続（つり輪）
                            additional_condition_met = True  # 基本的なグループチェックで十分
                        elif rule.get("additional_condition") == "one_rail_transition":
                            # 一本棒技からの移行（平行棒）
                            additional_condition_met = True  # 基本的なグループチェックで十分
                        elif rule.get("additional_condition") == "no_group4_both":
                            # グループ4同士の組み合わせには加点がつかない
                            both_group4 = (skill1.get("group", 0) == 4 and skill2.get("group", 0) == 4)
                            additional_condition_met = not both_group4
                        
                        if from_group_match and to_group_match and from_value_match and to_value_match and additional_condition_met:
                            connection_bonus += rule["bonus"]
                            # 一つの連続に複数のルールが適用されないように、一度マッチしたら次の連続のチェックに移る
                            break
                        
                        # 双方向のチェック（bidirectionalがTrueの場合）
                        if rule.get("bidirectional", False):
                            # 逆方向のチェック
                            from_group_match_rev = "from_group" not in rule or skill2.get("group", 0) in rule["from_group"]
                            to_group_match_rev = "to_group" not in rule or skill1.get("group", 0) in rule["to_group"]
                            from_value_match_rev = rule["from_value"] is None or skill2["value_letter"] in rule["from_value"]
                            to_value_match_rev = rule["to_value"] is None or skill1["value_letter"] in rule["to_value"]
                            
                            # 追加条件のチェック（逆方向）
                            additional_condition_met_rev = True
                            if rule.get("additional_condition") == "one_must_be_d_or_higher":
                                d_or_higher = ["D", "E", "F", "G", "H", "I", "J"]
                                additional_condition_met_rev = (skill1["value_letter"] in d_or_higher or 
                                                               skill2["value_letter"] in d_or_higher)
                            elif rule.get("additional_condition") == "different_skills":
                                # 異なる技である必要がある
                                additional_condition_met_rev = skill1.get("id") != skill2.get("id")
                            elif rule.get("additional_condition") == "strength_to_dynamic":
                                # 静的技から動的技への連続（つり輪）
                                additional_condition_met_rev = True  # 基本的なグループチェックで十分
                            elif rule.get("additional_condition") == "dynamic_to_strength":
                                # 動的技から静的技への連続（つり輪）
                                additional_condition_met_rev = True  # 基本的なグループチェックで十分
                            elif rule.get("additional_condition") == "one_rail_transition":
                                # 一本棒技からの移行（平行棒）
                                additional_condition_met_rev = True  # 基本的なグループチェックで十分
                            elif rule.get("additional_condition") == "no_group4_both":
                                # グループ4同士の組み合わせには加点がつかない
                                both_group4 = (skill1.get("group", 0) == 4 and skill2.get("group", 0) == 4)
                                additional_condition_met_rev = not both_group4
                            
                            if from_group_match_rev and to_group_match_rev and from_value_match_rev and to_value_match_rev and additional_condition_met_rev:
                                connection_bonus += rule["bonus"]
                                break

    # ステータス情報を辞書として返す
    status_info = {
        "fulfilled": num_fulfilled_groups,
        "required": rules["groups_required"]
    }

    # 6. 最終Dスコア
    d_score = difficulty_value + group_bonus + dismount_group_bonus + connection_bonus
    
    # 着地成功時の参考スコア
    d_score_with_landing = d_score + landing_bonus_potential
    
    return d_score, status_info, difficulty_value, group_bonus + dismount_group_bonus, connection_bonus, total_skills_in_routine, landing_bonus_potential, d_score_with_landing

def load_prompt_template(file_path):
    """テキストファイルからプロンプトテンプレートを読み込む"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def create_routine_consultant_chain(vectorstore, lang="en"):
    """
    ルールブックの知識(vectorstore)も活用する、記憶を持つAIコーチチェーンを作成する。
    """
    llm = ChatOpenAI(model="gpt-4o", temperature=0.7)

    # プロンプトを外部ファイルから読み込む
    prompt_file = f"prompts/d_score_coach_{lang}.txt"
    prompt_template = load_prompt_template(prompt_file)

    prompt = PromptTemplate(template=prompt_template, input_variables=["context", "chat_history", "question"])
    
    memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True, output_key='answer')
    
    retriever = vectorstore.as_retriever(search_type="mmr", search_kwargs={'k': 5, 'fetch_k': 20})

    chain = ConversationalRetrievalChain.from_llm(
        llm=llm,
        retriever=retriever,
        memory=memory,
        return_source_documents=True,
        combine_docs_chain_kwargs={'prompt': prompt},
        verbose=False
    )
    
    return chain 

# --- AIチャット統合用の動的ルール抽出機能 ---

def get_apparatus_rules_explanation(apparatus, lang="ja"):
    """
    種目別ルールの説明を生成する
    """
    if apparatus not in APPARATUS_RULES:
        return None
    
    rules = APPARATUS_RULES[apparatus]
    apparatus_names = {
        "FX": {"ja": "床運動", "en": "Floor Exercise"},
        "PH": {"ja": "あん馬", "en": "Pommel Horse"},
        "SR": {"ja": "つり輪", "en": "Still Rings"},
        "VT": {"ja": "跳馬", "en": "Vault"},
        "PB": {"ja": "平行棒", "en": "Parallel Bars"},
        "HB": {"ja": "鉄棒", "en": "Horizontal Bar"},
    }
    
    apparatus_name = apparatus_names.get(apparatus, {}).get(lang, apparatus)
    
    if lang == "ja":
        explanation = f"""**{apparatus_name}（{apparatus}）のDスコア計算ルール**

---

## 基本ルール

**技数制限：** {rules['count_limit']}技
• {rules['count_limit']}技以上実施した場合、最高得点となる{rules['count_limit']}技の組み合わせを自動選択

**必要グループ数：** {rules['groups_required']}グループ  
• 各グループから最低1技が必要（グループボーナス獲得のため）

**グループボーナス：** {rules['bonus_per_group']}点/グループ
• 満たされたグループ数に応じて加点

---

## 計算方法

**1. 難度点**
• 選択された技の難度値の合計
• 例：D難度(0.4) + E難度(0.5) + F難度(0.6) = 1.5点

**2. グループボーナス**  
• 満たされたグループ数 × {rules['bonus_per_group']}点
• 例：4グループ達成 = 4 × {rules['bonus_per_group']} = {4 * rules['bonus_per_group']}点

**3. 連続技ボーナス**
• 該当する連続技の加点（種目により異なる）

**4. 終末技グループ加点**
• 終末技の難度価値点と同じ点数の追加グループ点

---

## 計算例

**例：D難度3技 + E難度2技 + F難度終末技の場合**

• 難度点：0.4×3 + 0.5×2 + 0.6×1 = 2.8点
• グループボーナス：4グループ × {rules['bonus_per_group']} = {4 * rules['bonus_per_group']}点  
• 終末技グループ加点：0.6点（F難度終末技）
• **合計：{2.8 + 4 * rules['bonus_per_group'] + 0.6}点** （連続技ボーナス除く）

---

## 重要なポイント

✓ **最終Dスコア =** 難度点 + グループボーナス + 終末技グループ加点 + 連続技ボーナス

✓ **グループ要求を満たすことが高得点のカギ**

✓ **このルールはアプリのDスコア計算機能に実装されています**"""
    else:
        explanation = f"""**{apparatus_name} ({apparatus}) D-Score Calculation Rules**

**Basic Rules:**
- Skill limit: {rules['count_limit']} skills
- Required groups: {rules['groups_required']} groups  
- Group bonus: {rules['bonus_per_group']} points/group

**Calculation Method:**
1. Difficulty value: Sum of selected skills' difficulty values
2. Group bonus: Number of fulfilled groups × {rules['bonus_per_group']} points
3. Connection bonus: Applicable connection bonuses

**Important Notes:**
- If more than {rules['count_limit']} skills are performed, the best combination of {rules['count_limit']} skills is automatically selected
- At least 1 skill from each group is required (for group bonus)
- Final D-Score = Difficulty value + Group bonus + Connection bonus

These rules are implemented in the app's D-score calculation feature."""
    
    return explanation

def get_connection_rules_explanation(apparatus, lang="ja"):
    """
    連続技ルールの詳細説明を生成する
    """
    if apparatus not in CONNECTION_RULES:
        return None
    
    rules = CONNECTION_RULES[apparatus]
    apparatus_names = {
        "FX": {"ja": "床運動", "en": "Floor Exercise"},
        "HB": {"ja": "鉄棒", "en": "Horizontal Bar"},
    }
    
    apparatus_name = apparatus_names.get(apparatus, {}).get(lang, apparatus)
    
    if lang == "ja":
        explanation = f"""**{apparatus_name}（{apparatus}）の連続技ボーナスルール**

---

## 基本原則

**✓ 隣接して実施される技のみが連続技の対象**  
**✓ 該当する組み合わせで自動的に加点**  
**✓ 種目ごとに異なるルールが適用**

---

## 連続技ボーナス一覧

"""
        
        for i, rule in enumerate(rules, 1):
            # より分かりやすい説明を生成
            from_values = "、".join(rule['from_value']) if rule['from_value'] else "任意の難度"
            to_values = "、".join(rule['to_value']) if rule['to_value'] else "任意の難度"
            
            # グループの説明をより具体的に
            group_descriptions = {
                1: "グループⅠ（前方系・アドラー系）",
                2: "グループⅡ（手放し技・離れ技）", 
                3: "グループⅢ（背面系・コバチ系）",
                4: "グループⅣ（終末技）"
            }
            
            if apparatus == "FX":
                group_descriptions = {
                    1: "グループⅠ（前方系宙返り）",
                    2: "グループⅡ（側方系・ひねり系）",
                    3: "グループⅢ（後方系宙返り）", 
                    4: "グループⅣ（終末技）"
                }
            
            from_group_desc = group_descriptions.get(rule['from_group'][0] if rule.get('from_group') else None, f"グループ{rule.get('from_group', ['?'])[0]}")
            to_group_desc = group_descriptions.get(rule['to_group'][0] if rule.get('to_group') else None, f"グループ{rule.get('to_group', ['?'])[0]}")
            
            direction = "双方向OK" if rule.get('bidirectional') else "順序重要"
            
            explanation += f"""### ルール{i}：{from_values}難度 + {to_values}難度 = **{rule['bonus']}点**

**組み合わせ：**
• 前技：{from_group_desc}の{from_values}難度
• 後技：{to_group_desc}の{to_values}難度
• 方向性：{direction}

"""
            
            # 具体例を追加
            if apparatus == "FX" and i == 1:  # D+D = 0.2点
                explanation += """**具体例：**
• 前方宙返り2回ひねり（D難度）+ 後方宙返り3回ひねり（D難度）= 0.2点
• 側宙2回ひねり（D難度）+ バク転（D難度）= 0.2点

"""
            elif apparatus == "FX" and i == 2:  # D+B/C = 0.1点
                explanation += """**具体例：**
• 前方宙返り2回ひねり（D難度）+ 側転（B難度）= 0.1点
• バク宙（D難度）+ 前転倒立（C難度）= 0.1点

"""
            elif apparatus == "HB" and i == 1:  # アドラー系+離れ技
                explanation += """**具体例：**
• アドラー1回ひねり（D難度）+ コバチ（E難度）= 0.2点
• 背面とび（D難度）+ トカチェフ（F難度）= 0.2点

"""
            
            if rule.get('additional_condition') == 'no_group4_both':
                explanation += "⚠️ **除外条件：** グループ4同士の組み合わせには加点なし\n\n"
            else:
                explanation += "\n"
        
        explanation += """---

## 重要なポイント

**✓ 連続技認定の条件**
• 技と技の間に他の技が入らない
• 着地なしで直接次の技に移行
• アプリで「連続技設定」をONにする

**✓ 加点の計算**
• 該当する連続技は自動で検出
• 複数の連続技がある場合、すべて加点
• 同じ連続に複数ルールは適用されない

**✓ アプリでの確認方法**
• 技を選択後、連続技設定を有効化
• 計算結果で「連続技ボーナス」欄を確認
• このルールに基づいて正確に計算されます"""
        
    else:
        explanation = f"""**{apparatus_name} ({apparatus}) Connection Bonus Rules**

The connection bonus rules implemented in this app for {apparatus_name} are:

"""
        
        for i, rule in enumerate(rules, 1):
            from_values = ", ".join(rule['from_value']) if rule['from_value'] else "any difficulty"
            to_values = ", ".join(rule['to_value']) if rule['to_value'] else "any difficulty"
            
            direction = "(bidirectional)" if rule.get('bidirectional') else "(order matters)"
            
            explanation += f"""**Rule {i}: {from_values} + {to_values} = {rule['bonus']} points**
- First skill: Group {rule['from_group']} {from_values} difficulty
- Second skill: Group {rule['to_group']} {to_values} difficulty  
- Bonus: {rule['bonus']} points
- Direction: {direction}
"""
            
            if rule.get('additional_condition') == 'no_group4_both':
                explanation += "- Exclusion: No bonus for Group 4 combinations\n"
            
            explanation += "\n"
        
        explanation += """**Important Notes:**
- Only adjacent skills qualify for connection bonuses
- These rules are implemented in the app's D-score calculation feature
- Use the skill selection and connection setup for accurate calculations"""
    
    return explanation

def get_difficulty_values_explanation(lang="ja"):
    """
    難度値の説明を生成する
    """
    if lang == "ja":
        explanation = """**体操競技の難度値システム**

---

## 難度値一覧

"""
        
        # 技の例を含む詳細な説明
        skill_examples = {
            "A": ["前転", "側転", "バク転（床）"],
            "B": ["ロンダート", "側宙", "前方宙返り"],
            "C": ["後方宙返り1回ひねり", "前方宙返り1回ひねり", "ムーンサルト"],
            "D": ["後方宙返り2回ひねり", "前方宙返り2回ひねり", "トーマス旋回（あん馬）"],
            "E": ["後方宙返り3回ひねり", "二段宙返り", "コバチ（鉄棒）"],
            "F": ["後方宙返り4回ひねり", "二段宙返り1回ひねり", "トカチェフ（鉄棒）"],
            "G": ["三段宙返り", "後方宙返り5回ひねり", "アドラー系高難度技"],
            "H": ["四段宙返り", "超高難度ひねり技", "最新開発技"],
            "I": ["世界最高レベル技", "新技開発", "五段宙返り"],
            "J": ["理論上の最高難度", "究極技", "神技レベル"]
        }
        
        for letter, value in DIFFICULTY_VALUES.items():
            examples = skill_examples.get(letter, ["高難度技"])
            example_text = "、".join(examples[:2])  # 最初の2つの例を表示
            
            if letter in ["A", "B", "C"]:
                level = "基本レベル"
            elif letter in ["D", "E"]:
                level = "中級レベル"
            elif letter in ["F", "G"]:
                level = "上級レベル"
            else:
                level = "最高レベル"
                
            explanation += f"""### {letter}難度：{value}点 ({level})
• **代表例：** {example_text}
• **特徴：** {level}の技として演技に組み込まれる

"""
        
        explanation += """---

## 難度値の活用方法

**1. Dスコア計算での役割**
• 選択した技の難度値を合計
• 例：C難度(0.3) + D難度(0.4) + E難度(0.5) = 1.2点

**2. 演技構成のポイント**
• 高難度技ほど高得点だが、実施成功率とのバランスが重要
• グループ要求を満たしつつ、難度を上げることが理想
• 終末技は難度価値点と同じグループ加点も獲得

**3. 戦略的な難度選択**
• **A〜C難度：** 確実性重視、基本構成
• **D〜E難度：** バランス型、中核となる技
• **F難度以上：** 高得点狙い、リスクと得点のバランス

---

## 重要なルール

**✓ 同一技の制限**
• 同じ技を繰り返しても、2回目以降は難度値なし
• 技のバリエーションが重要

**✓ 実施要件**
• 技が正しく実施されない場合、難度値は認められない
• 着地や技の完成度が評価される

**✓ 国際基準**
• 各技の難度は国際体操連盟(FIG)によって設定
• 定期的にルール改正で難度が変更される場合がある

---

**このシステムはアプリのDスコア計算機能に正確に実装されています**"""
        
    else:
        explanation = """**Gymnastics Difficulty Value System**

The difficulty values implemented in this app are:

"""
        for letter, value in DIFFICULTY_VALUES.items():
            explanation += f"- **{letter} Difficulty**: {value} points\n"
        
        explanation += """
**Application:**
- D-score calculation sums the difficulty values of selected skills
- Higher difficulty skills provide more points
- Each skill is assigned a difficulty by the International Gymnastics Federation

**Important Notes:**
- Repeated skills do not receive difficulty value after the first performance
- Incorrectly performed skills do not receive difficulty value
- This system is implemented in the app's D-score calculation feature"""
    
    return explanation

def get_all_apparatus_overview(lang="ja"):
    """
    全種目の概要説明を生成する
    """
    if lang == "ja":
        explanation = """**体操競技男子6種目のDスコア計算概要**

---

## 種目別ルール比較

"""
        apparatus_info = {
            "FX": {
                "name": "床運動", 
                "feature": "タンブリング系技中心",
                "specialty": "宙返り・ひねり技の連続",
                "duration": "70秒以内"
            },
            "PH": {
                "name": "あん馬", 
                "feature": "旋回技中心",
                "specialty": "ポメル・あん部での技",
                "duration": "制限なし"
            },
            "SR": {
                "name": "つり輪", 
                "feature": "静止技・倒立系",
                "specialty": "筋力と技術の融合",
                "duration": "制限なし"
            },
            "VT": {
                "name": "跳馬", 
                "feature": "1技のみ",
                "specialty": "爆発的パワー技",
                "duration": "瞬間"
            },
            "PB": {
                "name": "平行棒", 
                "feature": "上棒・下棒技",
                "specialty": "振動技と倒立技",
                "duration": "制限なし"
            },
            "HB": {
                "name": "鉄棒", 
                "feature": "手放し技中心",
                "specialty": "回転・手放し・終末技",
                "duration": "制限なし"
            }
        }
        
        for apparatus, rules in APPARATUS_RULES.items():
            info = apparatus_info.get(apparatus, {"name": apparatus, "feature": "技の組み合わせ", "specialty": "多様な技", "duration": "制限なし"})
            
            explanation += f"""### {info['name']}（{apparatus}）
**特徴：** {info['feature']}  
**専門性：** {info['specialty']}  
**演技時間：** {info['duration']}

**ルール詳細：**
• 技数制限：{rules['count_limit']}技
• 必要グループ：{rules['groups_required']}グループ  
• グループボーナス：{rules['bonus_per_group']}点/グループ
• 連続技ルール：{"あり" if apparatus in CONNECTION_RULES else "なし"}
• 終末技グループ加点：{"あり" if apparatus != "VT" else "なし"}

---

"""
        
        explanation += """## 全種目共通ルール

**✓ 難度値システム**
• A難度（0.1点）〜 J難度（1.0点）の10段階
• 技の複雑さと危険度に応じて設定

**✓ Dスコア計算式**
• **基本構成：** 難度点 + グループボーナス
• **追加要素：** 連続技ボーナス + 終末技グループ加点
• **最終式：** Dスコア = 難度点 + グループボーナス + 終末技グループ加点 + 連続技ボーナス

**✓ 戦略的ポイント**
1. **グループ要求を満たす** - 基本ボーナス確保
2. **高難度技を選択** - 難度点アップ
3. **連続技を組み込む** - 追加ボーナス獲得
4. **終末技の難度を上げる** - 2倍の効果（難度点+グループ加点）

---

## 種目選択のヒント

**初心者向け：** 床運動・跳馬
• ルールがシンプル
• 技の種類が分かりやすい

**中級者向け：** つり輪・平行棒  
• グループ要求が4-5個
• バランスの良い技選択が重要

**上級者向け：** あん馬・鉄棒
• 高いグループ要求（5個）
• 複雑な連続技ルール

---

**このアプリのDスコア計算機能ですべての種目を正確に計算できます**"""
        
    else:
        explanation = """**Men's Gymnastics 6 Apparatus D-Score Overview**

Rules overview for each apparatus implemented in this app:

"""
        apparatus_names = {
            "FX": "Floor Exercise", "PH": "Pommel Horse", "SR": "Still Rings",
            "VT": "Vault", "PB": "Parallel Bars", "HB": "Horizontal Bar"
        }
        
        for apparatus, rules in APPARATUS_RULES.items():
            name = apparatus_names.get(apparatus, apparatus)
            explanation += f"""**{name} ({apparatus})**
- Skill limit: {rules['count_limit']} skills
- Required groups: {rules['groups_required']} groups
- Group bonus: {rules['bonus_per_group']} points/group
- Connection rules: {"Yes" if apparatus in CONNECTION_RULES else "No"}

"""
        
        explanation += """**Common Rules:**
- Difficulty values range from A (0.1 points) to J (1.0 points)
- Final D-Score = Difficulty value + Group bonus + Connection bonus
- Use this app's D-score calculation feature for accurate calculations"""
    
    return explanation

def get_dismount_rules_explanation_concise(question: str, lang="ja"):
    """
    終末技・着地に関するルールの簡潔な説明を生成する
    """
    import re
    
    # 特定の難度について質問されているかチェック
    difficulty_match = re.search(r'([a-j])難度', question.lower())
    if difficulty_match:
        difficulty = difficulty_match.group(1).upper()
        difficulty_value = {
            "A": 0.1, "B": 0.2, "C": 0.3, "D": 0.4, "E": 0.5,
            "F": 0.6, "G": 0.7, "H": 0.8, "I": 0.9, "J": 1.0
        }.get(difficulty, 0.0)
        
        if lang == "ja":
            basic_total = round(difficulty_value * 2, 1)
            landing_bonus = 0.1 if difficulty_value >= 0.3 else 0.0
            total_with_landing = round(basic_total + landing_bonus, 1)
            
            explanation = f"""**{difficulty}難度終末技の加点**

• 難度価値点：{difficulty_value}点
• 終末技グループ加点：{difficulty_value}点

**基本加点：{basic_total}点**"""
            
            if landing_bonus > 0:
                explanation += f"""
• 着地加点（着地を止めた場合のみ）：+{landing_bonus}点

**着地成功時の合計：{total_with_landing}点**"""
            
            return explanation
        else:
            basic_total = round(difficulty_value * 2, 1)
            landing_bonus = 0.1 if difficulty_value >= 0.3 else 0.0
            total_with_landing = round(basic_total + landing_bonus, 1)
            
            explanation = f"""**{difficulty} difficulty dismount bonus**

• Difficulty value: {difficulty_value} pts
• Dismount group bonus: {difficulty_value} pts

**Basic bonus: {basic_total} pts**"""
            
            if landing_bonus > 0:
                explanation += f"""
• Landing bonus (only if stuck landing): +{landing_bonus} pts

**Total with stuck landing: {total_with_landing} pts**"""
            
            return explanation
    
    # 一般的な簡潔回答
    if lang == "ja":
        return """**終末技の加点**

• **グループ加点：** 終末技の難度価値点と同じ点数
• **着地加点：** C難度以上で着地を止めた場合のみ0.1点

**例：F難度終末技**
- 基本加点：0.6点（難度）+ 0.6点（グループ加点）= 1.2点
- 着地成功時：1.2点 + 0.1点（着地加点）= 1.3点"""
    else:
        return """**Dismount bonus**

• **Group bonus:** Equal to dismount's difficulty value
• **Landing bonus:** 0.1 pts for C+ only with stuck landing

**Example: F difficulty dismount**
- Basic bonus: 0.6 (difficulty) + 0.6 (group) = 1.2 pts
- With stuck landing: 1.2 + 0.1 (landing) = 1.3 pts"""

def get_dismount_rules_explanation(lang="ja"):
    """
    終末技・着地に関するルールの説明を生成する
    """
    if lang == "ja":
        explanation = """**終末技に関するルール**

---

## 1. 終末技のグループ加点

**基本ルール：**
• 終末技の難度価値点と同じ点数のグループ点を獲得
• 通常のグループボーナスとは別に追加される特別な加点

**具体的な計算例：**
• **C難度終末技（0.3点）** → 難度点 0.3点 + グループ加点 0.3点
• **D難度終末技（0.4点）** → 難度点 0.4点 + グループ加点 0.4点  
• **E難度終末技（0.5点）** → 難度点 0.5点 + グループ加点 0.5点
• **F難度終末技（0.6点）** → 難度点 0.6点 + グループ加点 0.6点
• **G難度終末技（0.7点）** → 難度点 0.7点 + グループ加点 0.7点

**対象種目：**
• 跳馬を除く全種目（床・あん馬・つり輪・平行棒・鉄棒）

---

## 2. 終末技の着地加点

**基本ルール：**
• C難度以上の終末技で着地を止めた場合：**0.1点の加点**

**対象種目：**
• あん馬を除く全種目
• 跳馬の場合：宙返りを伴う技のみ対象

**着地の条件：**
• 着地時に足を動かさず、完全に静止する必要があります

---

## 重要なポイント

**✓ 終末技の加点構成：**
1. **常に獲得：** 難度による追加グループ点（難度価値点と同じ）
2. **条件付き：** 着地加点（着地を止めた場合のみ0.1点）

**計算例：F難度終末技の場合**
• **基本：** 0.6点（難度）+ 0.6点（グループ加点）= 1.2点
• **着地成功時：** 1.2点 + 0.1点（着地加点）= **1.3点の加点**

**⚠️ 重要：** 着地加点は着地を止めた場合のみ適用されます

---

このルールはアプリのDスコア計算機能に実装されています。"""
    else:
        explanation = """**Dismount Rules**

---

## 1. Dismount Group Bonus

**Basic Rule:**
• Group points equal to the dismount's difficulty value points
• Special bonus added separately from regular group bonuses

**Specific Calculation Examples:**
• **C difficulty dismount (0.3 pts)** → 0.3 difficulty pts + 0.3 group bonus
• **D difficulty dismount (0.4 pts)** → 0.4 difficulty pts + 0.4 group bonus
• **E difficulty dismount (0.5 pts)** → 0.5 difficulty pts + 0.5 group bonus
• **F difficulty dismount (0.6 pts)** → 0.6 difficulty pts + 0.6 group bonus
• **G difficulty dismount (0.7 pts)** → 0.7 difficulty pts + 0.7 group bonus

**Applicable Events:**
• All events except vault (Floor, Pommel Horse, Still Rings, Parallel Bars, Horizontal Bar)

---

## 2. Dismount Landing Bonus

**Basic Rule:**
• **0.1 point bonus for C difficulty or higher dismounts with stuck landing**

**Applicable Events:**
• All events except pommel horse
• Vault: Only for skills with salto

**Landing Requirements:**
• Must land completely still without moving feet

---

## Key Points

**✓ Dismounts can earn both:**
1. Difficulty-based group points (equal to difficulty value)
2. Landing bonus (0.1 points)

**Calculation Example: F difficulty dismount with perfect landing**
• Difficulty points: 0.6 pts
• Dismount group bonus: 0.6 pts
• Landing bonus: 0.1 pts
• **Total: 1.3 points bonus**

---

These rules are implemented in the app's D-score calculation feature."""
    
    return explanation

def calculate_demo_score(apparatus, skills_list, lang="ja"):
    """
    デモンストレーション用のスコア計算
    簡単な技のリストから計算例を示す
    """
    if apparatus not in APPARATUS_RULES:
        return None
    
    try:
        # 簡単な形式での技リストを想定: [{"value_letter": "D", "group": 2}, ...]
        routine = [skills_list]  # 全て連続として扱う
        
        d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills, landing_bonus_potential, d_score_with_landing = calculate_d_score(
            apparatus, routine
        )
        
        # 終末技の情報を取得
        dismount_skill = get_dismount_skill(apparatus, routine)
        dismount_group_bonus = calculate_dismount_group_bonus(apparatus, dismount_skill)
        regular_group_bonus = group_bonus - dismount_group_bonus
        
        if lang == "ja":
            explanation = f"""**計算例：{apparatus}種目**

**入力技構成：**
"""
            for i, skill in enumerate(skills_list, 1):
                is_dismount = (i == len(skills_list)) and apparatus != "VT"
                dismount_note = "（終末技）" if is_dismount else ""
                explanation += f"{i}. {skill.get('value_letter', '?')}難度・グループ{skill.get('group', '?')}{dismount_note}\n"
            
            explanation += f"""
**計算結果：**
- 難度点：{difficulty_value:.1f}点
- 通常グループボーナス：{regular_group_bonus:.1f}点（{status_info['fulfilled']}/{status_info['required']}グループ達成）"""
            
            if dismount_group_bonus > 0:
                explanation += f"\n- 終末技グループ加点：{dismount_group_bonus:.1f}点（{dismount_skill.get('value_letter', '?')}難度終末技）"
            
            explanation += f"""
- 連続技ボーナス：{connection_bonus:.1f}点
- **合計Dスコア：{d_score:.1f}点**"""
            
            if landing_bonus_potential > 0:
                explanation += f"""
- **（着地成功時：{d_score_with_landing:.1f}点）**"""
            
            explanation += f"""

この計算はアプリの実装されたルールに基づいています。"""
            
        else:
            explanation = f"""**Calculation Example: {apparatus} Apparatus**

**Input Skills:**
"""
            for i, skill in enumerate(skills_list, 1):
                is_dismount = (i == len(skills_list)) and apparatus != "VT"
                dismount_note = " (dismount)" if is_dismount else ""
                explanation += f"{i}. {skill.get('value_letter', '?')} difficulty, Group {skill.get('group', '?')}{dismount_note}\n"
            
            explanation += f"""
**Calculation Results:**
- Difficulty value: {difficulty_value:.1f} points
- Regular group bonus: {regular_group_bonus:.1f} points ({status_info['fulfilled']}/{status_info['required']} groups fulfilled)"""
            
            if dismount_group_bonus > 0:
                explanation += f"\n- Dismount group bonus: {dismount_group_bonus:.1f} points ({dismount_skill.get('value_letter', '?')} difficulty dismount)"
            
            explanation += f"""
- Connection bonus: {connection_bonus:.1f} points
- **Total D-Score: {d_score:.1f} points**"""
            
            if landing_bonus_potential > 0:
                explanation += f"""
- **(With stuck landing: {d_score_with_landing:.1f} points)**"""
            
            explanation += f"""

This calculation is based on the app's implemented rules."""
        
        return explanation
        
    except Exception as e:
        if lang == "ja":
            return f"計算エラーが発生しました：{str(e)}"
        else:
            return f"Calculation error occurred: {str(e)}"