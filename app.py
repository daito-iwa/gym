import streamlit as st
import os
from dotenv import load_dotenv
from rulebook_ai import setup_vectorstore, create_conversational_chain, SUPPORTED_LANGUAGES, PDF_FILENAMES
from d_score_calculator import calculate_d_score, create_routine_consultant_chain, load_skills_from_csv
import d_score_calculator

# --- UIテキストの多言語定義 ---
UI_TEXTS = {
    "en": {
        "title": "Gymnastics AI Chat",
        "sidebar_title": "Settings",
        "mode_selection_label": "Select Mode",
        "mode_chat": "Rulebook AI Chat",
        "mode_d_score": "D-Score Calculator",
        "selectbox_label": "Rulebook Language:",
        "reset_button_label": "Reset Chat",
        "chat_input_placeholder": "Ask a question about gymnastics rules...",
        "init_spinner": "Loading **{lang_display_name}** rulebook...",
        "init_error": "Error during AI initialization: {e}",
        "thinking_spinner": "AI is thinking...",
        "expander_title": "Reference",
        "page_header": "**Page:** {page_num}",
        "no_pdf_error": "Rulebook PDF not found in `data` directory.",
        "supported_files_info": "Supported filenames: `{filenames}`",
        "d_score_title": "D-Score Calculator",
        "d_score_apparatus_label": "Select Apparatus",
        "d_score_current_score_label": "Current D-Score:",
        "d_score_chat_placeholder": "Ask for advice on your routine...",
        "d_score_add_skill_button": "Add",
        "d_score_select_skill_placeholder": "Select a skill to add",
        "d_score_wip": "This feature is currently under development.",
        "d_score_routine_header": "Current Routine",
        "d_score_edit_button": "Change",
        "d_score_delete_button": "Delete",
        "d_score_connect_button": "Connect with Next",
        "d_score_confirm_button": "✓",
        "d_score_cancel_button": "×",
        "d_score_metric_difficulty": "① Difficulty Value",
        "d_score_metric_groups": "② Group Bonus",
        "d_score_metric_connection": "③ Connection Value",
        "d_score_metric_total": "Total D-Score",
        "d_score_coach_header": "AI Routine Coach",
        "d_score_reset_button_label": "Reset Coach Chat",
        "apparatus_fx": "FX - Floor Exercise",
        "apparatus_ph": "PH - Pommel Horse",
        "apparatus_sr": "SR - Rings",
        "apparatus_vt": "VT - Vault",
        "apparatus_pb": "PB - Parallel Bars",
        "apparatus_hb": "HB - Horizontal Bar",
    },
    "ja": {
        "title": "Gymnastics AI Chat",
        "sidebar_title": "設定",
        "mode_selection_label": "モード選択",
        "mode_chat": "ルールブックAIチャット",
        "mode_d_score": "Dスコア計算",
        "selectbox_label": "ルールブックの言語:",
        "reset_button_label": "チャットをリセット",
        "chat_input_placeholder": "体操のルールについて質問を入力してください。",
        "init_spinner": "**{lang_display_name}** のルールブックを読み込んでいます...",
        "init_error": "AIの初期化中にエラーが発生しました: {e}",
        "thinking_spinner": "AIが回答を考えています...",
        "expander_title": "参考にしたルールブックの箇所",
        "page_header": "**ページ:** {page_num}",
        "no_pdf_error": "`data`ディレクトリにルールブックPDFが見つかりません。",
        "supported_files_info": "サポートされているファイル名: `{filenames}`",
        "d_score_title": "Dスコア計算",
        "d_score_apparatus_label": "種目を選択",
        "d_score_current_score_label": "現在のDスコア:",
        "d_score_chat_placeholder": "演技構成について相談する...",
        "d_score_add_skill_button": "技を追加",
        "d_score_select_skill_placeholder": "追加する技を選択",
        "d_score_wip": "この機能は現在開発中です。",
        "d_score_routine_header": "現在の構成",
        "d_score_edit_button": "変更",
        "d_score_delete_button": "削除",
        "d_score_connect_button": "次の連続とつなげる",
        "d_score_confirm_button": "✓",
        "d_score_cancel_button": "×",
        "d_score_metric_difficulty": "① 技の難度点",
        "d_score_metric_groups": "② グループ要求",
        "d_score_metric_connection": "③ 連続技ボーナス",
        "d_score_metric_total": "合計 Dスコア",
        "d_score_coach_header": "構成相談コーチ",
        "d_score_reset_button_label": "コーチとの会話をリセット",
        "apparatus_fx": "ゆか",
        "apparatus_ph": "あん馬",
        "apparatus_sr": "つり輪",
        "apparatus_vt": "跳馬",
        "apparatus_pb": "平行棒",
        "apparatus_hb": "鉄棒",
    }
}

def main():
    st.set_page_config(page_title="Gymnastics AI Chat", layout="wide")

    # --- 1. セッション情報の初期化 ---
    if "language" not in st.session_state:
        st.session_state.language = "en"
    if "mode" not in st.session_state:
        st.session_state.mode = "chat" 
    if "routine" not in st.session_state:
        st.session_state.routine = []
    if "messages" not in st.session_state:
        st.session_state.messages = []
    if "d_score_messages" not in st.session_state:
        st.session_state.d_score_messages = []


    # --- 2. サイドバーUIの定義と状態管理 ---
    with st.sidebar:
        # ロゴ
        logo_path = "assets/logo.png"
        if os.path.exists(logo_path):
            st.image(logo_path)

        # 現在の言語設定に基づいて、まずUIテキスト全体を取得
        ui_texts = UI_TEXTS.get(st.session_state.language, UI_TEXTS["en"])
        
        st.title(ui_texts["sidebar_title"])

        # 言語選択
        lang_options = {code: name for code, name in SUPPORTED_LANGUAGES.items() if os.path.exists(os.path.join("data", PDF_FILENAMES[code]))}
        if len(lang_options) > 1:
            # 現在の言語のインデックスを取得
            current_lang_index = list(lang_options.keys()).index(st.session_state.language)
            
            selected_lang_key = st.selectbox(
                label=ui_texts["selectbox_label"],
                options=list(lang_options.keys()),
                index=current_lang_index,
                format_func=lambda k: lang_options[k],
                key="language_selector" # ユニークなキー
            )
            # 言語が変更されたら状態を更新し、関連情報をリセット
            if st.session_state.language != selected_lang_key:
                st.session_state.language = selected_lang_key
                st.session_state.messages = []
                st.session_state.pop("qa_chain", None)
                st.session_state.d_score_messages = []
                st.session_state.pop("consultant_chain", None)
                st.session_state.routine = []
                st.rerun()

        # モード選択
        mode_options = {"chat": ui_texts["mode_chat"], "d_score": ui_texts["mode_d_score"]}
        st.session_state.mode = st.radio(
            label=ui_texts["mode_selection_label"],
            options=list(mode_options.keys()),
            format_func=lambda k: mode_options[k],
            key="mode_selector"
        )
        
        # リセットボタン（チャットモード時のみ表示）
        if st.session_state.mode == "chat":
            if st.button(ui_texts["reset_button_label"], use_container_width=True):
                st.session_state.messages = []
                st.session_state.pop("qa_chain", None)
                st.rerun()

    # --- 3. メインコンテンツの描画 ---
    if st.session_state.mode == "chat":
        render_chat_mode(ui_texts)
    else: # "d_score"
        skill_db = d_score_calculator.load_skills_from_csv(st.session_state.language)
        render_d_score_mode(ui_texts, skill_db)

def render_chat_mode(ui_texts):
    """ルールブックAIチャットモードのUIをレンダリング"""
    col1, col2 = st.columns([3, 1])
    with col1:
        st.title(ui_texts["title"])
    with col2:
        st.write("")
        if st.button(ui_texts["reset_button_label"], key="reset_chat"):
            st.session_state.messages = []
            st.session_state.pop("qa_chain", None)
            st.rerun()
    
    if "qa_chain" not in st.session_state:
        init_spinner_text = ui_texts["init_spinner"].format(lang_display_name=SUPPORTED_LANGUAGES.get(st.session_state.language, ''))
        with st.spinner(init_spinner_text):
            try:
                vectorstore = setup_vectorstore(st.session_state.language)
                st.session_state.qa_chain = create_conversational_chain(
                    vectorstore,
                    lang=st.session_state.language
                )
            except Exception as e:
                st.error(ui_texts["init_error"].format(e=e))
                st.stop()
    
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
            if message["role"] == "assistant" and message.get("source_documents"):
                with st.expander(ui_texts["expander_title"]):
                    for doc in message["source_documents"]:
                        st.write("---")
                        st.write(doc.page_content)
                        if 'page' in doc.metadata:
                            st.write(ui_texts["page_header"].format(page_num=doc.metadata.get('page', -1) + 1))

    if user_question := st.chat_input(ui_texts["chat_input_placeholder"]):
        st.session_state.messages.append({"role": "user", "content": user_question})
        with st.chat_message("user"):
            st.markdown(user_question)

        with st.chat_message("assistant"):
            with st.spinner(ui_texts["thinking_spinner"]):
                result = st.session_state.qa_chain.invoke({"question": user_question})
                response_content = result["answer"]
                source_documents = result.get("source_documents")
                
                st.markdown(response_content)
                if source_documents:
                    with st.expander(ui_texts["expander_title"]):
                        for doc in source_documents:
                            st.write("---")
                            st.write(doc.page_content)
                            if 'page' in doc.metadata:
                                st.write(ui_texts["page_header"].format(page_num=doc.metadata.get('page', -1) + 1))
        
        st.session_state.messages.append({
            "role": "assistant",
            "content": response_content,
            "source_documents": source_documents
        })

def render_d_score_mode(ui_texts, skill_db):
    """Dスコア計算モードのUIをレンダリング"""
    st.title(ui_texts["d_score_title"])

    st.subheader(ui_texts["d_score_routine_header"])
    
    # 利用可能な種目がない場合は、メッセージを表示
    if not skill_db:
        st.warning("現在の言語に対応する技リスト(CSV)が見つかりません。")
        return

    # 種目選択UI
    apparatus_options = {
        code: ui_texts.get(f"apparatus_{code.lower()}", code)
        for code in skill_db.keys()
    }
    
    selected_apparatus_code = st.selectbox(
        ui_texts["d_score_apparatus_label"],
        options=list(apparatus_options.keys()),
        format_func=lambda code: apparatus_options[code]
    )
    
    if 'routine' not in st.session_state:
        st.session_state.routine = []
    
    available_skills = skill_db.get(selected_apparatus_code, [])
    # 技名と難度を表示するための辞書を作成
    skill_options_map = {
        f"{skill['name']} ({skill['value_letter']})": skill
        for skill in available_skills
    }
    skill_display_names = list(skill_options_map.keys())
    
    # --- 技の追加エリア ---
    selected_skill_display_name = st.selectbox(
        ui_texts["d_score_select_skill_placeholder"], 
        options=skill_display_names,
        index=None, # デフォルトで何も選択しない
        key="skill_selection_to_add"
    )
    if st.button(ui_texts["d_score_add_skill_button"]):
        if selected_skill_display_name:
            skill_info = skill_options_map.get(selected_skill_display_name)
            if skill_info:
                st.session_state.routine.append([skill_info.copy()])
                st.session_state.editing_skill_index = None
                st.rerun()

    st.write("---")

    # --- 現在の構成リスト ---
    skill_counter = 1
    for i, connection_group in enumerate(st.session_state.routine):
        with st.container(border=True):
            for j, skill in enumerate(connection_group):
                is_editing = 'editing_skill_index' in st.session_state and st.session_state.editing_skill_index == (i, j)
                if is_editing:
                    # インライン編集UI
                    # (ロジックは変更なし)
                    pass
                else:
                    col1, col2, col3 = st.columns([0.7, 0.15, 0.15])
                    with col1:
                        prefix = f"{skill_counter}."
                        if j > 0: prefix = f"↳ {skill_counter}."
                        st.write(f"{prefix} {skill['name']} ({skill['value']})")
                    with col2:
                        if st.button(ui_texts["d_score_edit_button"], key=f"edit_{i}_{j}", use_container_width=True):
                            st.session_state.editing_skill_index = (i, j)
                            st.rerun()
                    with col3:
                        if st.button(ui_texts["d_score_delete_button"], key=f"delete_{i}_{j}", use_container_width=True):
                            st.session_state.routine[i].pop(j)
                            if not st.session_state.routine[i]: st.session_state.routine.pop(i)
                            st.rerun()
                skill_counter += 1
        
        if i < len(st.session_state.routine) - 1:
            if st.button(ui_texts["d_score_connect_button"], key=f"connect_{i}", use_container_width=True):
                # TODO: 結合ロジック
                pass
    
    st.write("---")

    # --- Dスコア表示 ---
    d_score, status_info, difficulty_value, group_bonus, connection_bonus, total_skills_in_routine = d_score_calculator.calculate_d_score(selected_apparatus_code, st.session_state.routine)
    
    st.metric(label=ui_texts["d_score_metric_difficulty"], value=f"{difficulty_value:.3f}")
    st.metric(label=ui_texts["d_score_metric_groups"], value=f"{group_bonus:.1f}")
    st.metric(label=ui_texts["d_score_metric_connection"], value=f"{connection_bonus:.2f}")
    st.metric(label=ui_texts["d_score_metric_total"], value=f"{d_score:.3f}")
    
    # 8技以上の場合に警告を表示
    if total_skills_in_routine > 8 and selected_apparatus_code != "VT":
        warning_text_ja = f"注意: Dスコアは、最も高得点になる8技で計算されます。現在、構成には{total_skills_in_routine}個の技が含まれています。"
        warning_text_en = f"Note: The D-Score is calculated from the 8 skills that yield the highest score. Your routine currently contains {total_skills_in_routine} skills."
        st.warning(warning_text_ja if st.session_state.language == "ja" else warning_text_en)

    st.write("---")

    # --- 構成相談AIチャットエリア ---
    st.subheader(ui_texts["d_score_coach_header"])

    if st.button(ui_texts["d_score_reset_button_label"], key="reset_d_score_chat"):
        st.session_state.d_score_messages = []
        st.session_state.pop("consultant_chain", None)
        st.rerun()

    if "consultant_chain" not in st.session_state:
        with st.spinner("AIコーチを準備中..."):
            try:
                vectorstore = setup_vectorstore(st.session_state.language)
                st.session_state.consultant_chain = d_score_calculator.create_routine_consultant_chain(vectorstore, lang=st.session_state.language)
            except Exception as e:
                st.error(f"AIコーチの初期化中にエラーが発生しました: {e}")
                st.stop()
    
    if "d_score_messages" not in st.session_state:
        st.session_state.d_score_messages = []

    for message in st.session_state.d_score_messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
            
    if user_advice_question := st.chat_input(ui_texts["d_score_chat_placeholder"]):
        st.session_state.d_score_messages.append({"role": "user", "content": user_advice_question})
        with st.chat_message("user"):
            st.markdown(user_advice_question)
        
        with st.chat_message("assistant"):
            with st.spinner(ui_texts["thinking_spinner"]):
                # --- AIへの入力に現在の構成情報を追加 ---
                # 1. 現在の構成を文字列にフォーマット
                routine_str_parts = []
                skill_counter = 1
                for connection_group in st.session_state.routine:
                    for j, skill in enumerate(connection_group):
                        prefix = f"{skill_counter}."
                        if j > 0: prefix = f"↳"
                        # グループ情報を追加
                        group_info = skill.get('group', 'N/A')
                        routine_str_parts.append(f"{prefix} {skill['name']} (難度: {skill['value_letter']}, グループ: {group_info})")
                        skill_counter += 1
                routine_str = "\n".join(routine_str_parts)
                if not routine_str:
                    routine_str = "まだ技が追加されていません。" if st.session_state.language == "ja" else "No skills added yet."

                # 2. 現在のスコアを文字列にフォーマット
                d_score_calc, status_info_calc, difficulty_value_calc, group_bonus_calc, connection_bonus_calc, _ = d_score_calculator.calculate_d_score(selected_apparatus_code, st.session_state.routine)
                score_str = f"""- {ui_texts["d_score_metric_difficulty"]}: {difficulty_value_calc:.3f}
- {ui_texts["d_score_metric_groups"]}: {group_bonus_calc:.1f}
- {ui_texts["d_score_metric_connection"]}: {connection_bonus_calc:.2f}
- {ui_texts["d_score_metric_total"]}: {d_score_calc:.3f}"""

                # 3. 情報を結合してAIへの最終的な質問を作成
                apparatus_name = ui_texts.get(f"apparatus_{selected_apparatus_code.lower()}", selected_apparatus_code)
                connection_bonus_available = selected_apparatus_code in d_score_calculator.CONNECTION_RULES

                if st.session_state.language == "ja":
                    connection_bonus_text = "利用可能です。" if connection_bonus_available else "この種目では利用できません。"
                    augmented_question = f"""
現在、私は「{apparatus_name}」の構成を組んでいます。
以下が現在の構成、Dスコア、そしてこの種目の基本情報です。
この情報を踏まえて、私の質問に答えてください。

# 種目
{apparatus_name}

# この種目のルール
- Dスコアは最大 {d_score_calculator.APPARATUS_RULES[selected_apparatus_code]['count_limit']} 個の技で計算されます。
- グループ要求の最大数: {d_score_calculator.APPARATUS_RULES[selected_apparatus_code]['groups_required']}
- 連続技ボーナス: {connection_bonus_text}

# 私の現在の構成
{routine_str}

# 私の現在のDスコア
{score_str}

# 私からの質問
「{user_advice_question}」
"""
                else:
                    connection_bonus_text = "Available." if connection_bonus_available else "Not available for this apparatus."
                    augmented_question = f"""
I am currently building a routine for "{apparatus_name}".
Below is my current routine, its D-Score, and the basic rules for this apparatus.
Based on this information, please answer my question.

# Apparatus
{apparatus_name}

# Rules for this Apparatus
- D-Score is calculated from a maximum of {d_score_calculator.APPARATUS_RULES[selected_apparatus_code]['count_limit']} skills.
- Maximum number of element groups: {d_score_calculator.APPARATUS_RULES[selected_apparatus_code]['groups_required']}
- Connection Bonus: {connection_bonus_text}

# My Current Routine
{routine_str}

# My Current D-Score
{score_str}

# My Question
"{user_advice_question}"
"""
                
                response = st.session_state.consultant_chain.invoke({"question": augmented_question})
                response_content = response['answer']
                st.markdown(response_content)
        
        st.session_state.d_score_messages.append({"role": "assistant", "content": response_content})

if __name__ == "__main__":
    main() 