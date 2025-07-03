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
                        
                        if from_group_match and to_group_match and from_value_match and to_value_match:
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
                            
                            if from_group_match_rev and to_group_match_rev and from_value_match_rev and to_value_match_rev:
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