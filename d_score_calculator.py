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
    
    # 3. 連続技ボーナス
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

    # 4. 最終Dスコア
    d_score = difficulty_value + group_bonus + connection_bonus
    
    return d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills_in_routine

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

**基本ルール：**
- 技数制限：{rules['count_limit']}技
- 必要グループ数：{rules['groups_required']}グループ
- グループボーナス：{rules['bonus_per_group']}点/グループ

**計算方法：**
1. 難度点：選択された技の難度値の合計
2. グループボーナス：満たされたグループ数 × {rules['bonus_per_group']}点
3. 連続技ボーナス：該当する連続技の加点

**注意事項：**
- {rules['count_limit']}技以上実施した場合、最高得点となる{rules['count_limit']}技の組み合わせを自動選択
- 各グループから最低1技が必要（グループボーナス獲得のため）
- 実際のDスコア = 難度点 + グループボーナス + 連続技ボーナス

このルールはアプリのDスコア計算機能に実装されています。"""
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

このアプリで実装されている{apparatus_name}の連続技ボーナスは以下の通りです：

"""
        
        for i, rule in enumerate(rules, 1):
            group_text = f"グループ{rule['from_group']}の技" if rule.get('from_group') else "任意のグループ"
            to_group_text = f"グループ{rule['to_group']}の技" if rule.get('to_group') else "任意のグループ"
            from_values = "、".join(rule['from_value']) if rule['from_value'] else "任意の難度"
            to_values = "、".join(rule['to_value']) if rule['to_value'] else "任意の難度"
            
            direction = "（双方向）" if rule.get('bidirectional') else "（順序重要）"
            
            explanation += f"""**ルール{i}：{from_values}難度 + {to_values}難度 = {rule['bonus']}点**
- 前技：{group_text}の{from_values}難度
- 後技：{to_group_text}の{to_values}難度
- 加点：{rule['bonus']}点
- 双方向性：{direction}
"""
            
            if rule.get('additional_condition') == 'no_group4_both':
                explanation += "- 除外条件：グループ4同士の組み合わせには加点なし\n"
            
            explanation += "\n"
        
        explanation += """**重要な注意点：**
- 連続技は隣接して実施される技のみが対象です
- このルールはアプリのDスコア計算機能に実装されています
- 実際に技を選択して連続技設定を行うと、正確な加点が計算されます"""
        
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

このアプリで実装されている難度値は以下の通りです：

"""
        for letter, value in DIFFICULTY_VALUES.items():
            explanation += f"- **{letter}難度**：{value}点\n"
        
        explanation += """
**適用方法：**
- Dスコア計算では、選択された技の難度値を合計します
- より高い難度の技ほど、より多くの得点を獲得できます
- 各技には国際体操連盟によって難度が設定されています

**注意事項：**
- 同じ技を繰り返し実施しても、2回目以降は難度値が認められません
- 技が正しく実施されなかった場合、難度値は認められません
- このシステムはアプリのDスコア計算機能に実装されています"""
        
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

このアプリで実装されている各種目のルールの概要：

"""
        apparatus_names = {
            "FX": "床運動", "PH": "あん馬", "SR": "つり輪", 
            "VT": "跳馬", "PB": "平行棒", "HB": "鉄棒"
        }
        
        for apparatus, rules in APPARATUS_RULES.items():
            name = apparatus_names.get(apparatus, apparatus)
            explanation += f"""**{name}（{apparatus}）**
- 技数制限：{rules['count_limit']}技
- 必要グループ：{rules['groups_required']}グループ
- グループボーナス：{rules['bonus_per_group']}点/グループ
- 連続技ルール：{"あり" if apparatus in CONNECTION_RULES else "なし"}

"""
        
        explanation += """**共通ルール：**
- 難度値はA（0.1点）からJ（1.0点）まで
- 最終Dスコア = 難度点 + グループボーナス + 連続技ボーナス
- このアプリのDスコア計算機能で正確な計算が可能です"""
        
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
        
        d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills = calculate_d_score(
            apparatus, routine
        )
        
        if lang == "ja":
            explanation = f"""**計算例：{apparatus}種目**

**入力技構成：**
"""
            for i, skill in enumerate(skills_list, 1):
                explanation += f"{i}. {skill.get('value_letter', '?')}難度・グループ{skill.get('group', '?')}\n"
            
            explanation += f"""
**計算結果：**
- 難度点：{difficulty_value:.1f}点
- グループボーナス：{group_bonus:.1f}点（{status_info['fulfilled']}/{status_info['required']}グループ達成）
- 連続技ボーナス：{connection_bonus:.1f}点
- **合計Dスコア：{d_score:.1f}点**

この計算はアプリの実装されたルールに基づいています。"""
            
        else:
            explanation = f"""**Calculation Example: {apparatus} Apparatus**

**Input Skills:**
"""
            for i, skill in enumerate(skills_list, 1):
                explanation += f"{i}. {skill.get('value_letter', '?')} difficulty, Group {skill.get('group', '?')}\n"
            
            explanation += f"""
**Calculation Results:**
- Difficulty value: {difficulty_value:.1f} points
- Group bonus: {group_bonus:.1f} points ({status_info['fulfilled']}/{status_info['required']} groups fulfilled)
- Connection bonus: {connection_bonus:.1f} points
- **Total D-Score: {d_score:.1f} points**

This calculation is based on the app's implemented rules."""
        
        return explanation
        
    except Exception as e:
        if lang == "ja":
            return f"計算エラーが発生しました：{str(e)}"
        else:
            return f"Calculation error occurred: {str(e)}"