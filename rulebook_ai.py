import os
from dotenv import load_dotenv
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain.prompts import PromptTemplate
from langchain.schema import Document
import pdfplumber
import logging
import warnings

# .envファイルから環境変数を読み込む
load_dotenv()

# pdfplumberの冗長なログを抑制
logging.basicConfig()
logging.getLogger("pdfminer").setLevel(logging.ERROR)

# --- 定数定義 ---
SUPPORTED_LANGUAGES = {
    "en": "英語",
    "ja": "日本語"
}
PDF_FILENAMES = {
    "en": "rulebook_en.pdf",
    "ja": "rulebook_ja.pdf"
}
DB_BASE_PATH = "db"
DATA_PATH = "data"

def get_vectorstore_path(lang):
    """言語に応じたベクトルストアのパスを生成する"""
    return f"{DB_BASE_PATH}_{lang}"

def load_pdf_with_tables(pdf_path):
    """
    pdfplumberを使用してPDFからテキストとテーブルを抽出する。
    特定の警告を無視する。
    """
    all_docs = []
    
    # "Cannot set gray non-stroke color" 警告を無視する
    with warnings.catch_warnings():
        warnings.filterwarnings(
            "ignore",
            category=UserWarning,
            message="Cannot set gray non-stroke color"
        )
        
        with pdfplumber.open(pdf_path) as pdf:
            for i, page in enumerate(pdf.pages):
                # ページのテキストを抽出
                text = page.extract_text() or ""
                
                # ページ内のテーブルを抽出してMarkdown形式に変換
                tables = page.extract_tables()
                tables_md = ""
                if tables:
                    for table in tables:
                        # Noneを空文字列に変換
                        clean_table = [[str(cell) if cell is not None else "" for cell in row] for row in table]
                        # Markdownテーブルのヘッダーを作成
                        header = "| " + " | ".join(clean_table[0]) + " |"
                        # Markdownのセパレーターを作成
                        separator = "| " + " | ".join(["---"] * len(clean_table[0])) + " |"
                        # Markdownの行を作成
                        rows = "\n".join(["| " + " | ".join(row) + " |" for row in clean_table[1:]])
                        tables_md += f"\n{header}\n{separator}\n{rows}\n"
                
                # テキストとテーブルを結合
                page_content = text + tables_md
                
                # Documentオブジェクトを作成
                metadata = {"source": pdf_path, "page": i}
                doc = Document(page_content=page_content, metadata=metadata)
                all_docs.append(doc)

    return all_docs

def setup_vectorstore(lang="en"):
    """
    PDFを読み込み、ベクトル化して保存・ロードする。
    """
    persist_directory = f"db_{lang}"
    pdf_path = os.path.join("data", PDF_FILENAMES.get(lang, "rulebook_en.pdf"))

    # OpenAIのEmbeddingモデルを利用
    embeddings = OpenAIEmbeddings()

    if os.path.exists(persist_directory):
        vectorstore = Chroma(persist_directory=persist_directory, embedding_function=embeddings)
        return vectorstore

    print(f"ベクトルストア ({SUPPORTED_LANGUAGES[lang]}) をセットアップ中...")
    
    if not os.path.exists(pdf_path):
        raise FileNotFoundError(f"ルールブックファイルが見つかりません: {pdf_path}。`{DATA_PATH}` ディレクトリに配置してください。")
    
    print(f"PDFファイルを読み込んでいます: {pdf_path}")
    
    # PDFをロード (パスワード対応)
    pdf_password = os.getenv("PDF_PASSWORD")
    try:
        # pdfplumberを使用して表データも含めて読み込む
        documents = load_pdf_with_tables(pdf_path)
    except Exception as e:
        print(f"pdfplumberでの読み込み中にエラーが発生しました: {e}")
        # フォールバック: PyPDFLoaderを使用
        try:
            loader = PyPDFLoader(pdf_path, password=pdf_password or None)
            documents = loader.load()
        except Exception as e2:
            print(f"PyPDFLoaderでの読み込みも失敗しました: {e2}")
            raise Exception(f"PDFファイルの読み込みに失敗しました: {pdf_path}. エラー: {str(e2)}")

    # テキストをチャンクに分割
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    texts = text_splitter.split_documents(documents)

    if not texts:
        print("警告: ドキュメントからテキストが抽出されませんでした。")
        # 空のChromaを初期化して返す
        return Chroma(persist_directory=persist_directory, embedding_function=embeddings)

    print(f"合計 {len(texts)}個のチャンクをベクトル化します...")

    # バッチ処理でChroma DBにベクトルを保存
    batch_size = 100  # 一度に処理するチャンク数
    
    # 最初のバッチでベクトルストアを初期化
    vectorstore = Chroma.from_documents(
        documents=texts[:batch_size],
        embedding=embeddings,
        persist_directory=persist_directory
    )
    print(f"  - バッチ 1 / {len(texts)//batch_size + 1} を処理しました。")

    # 残りのバッチを追加
    for i in range(batch_size, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        vectorstore.add_documents(documents=batch)
        print(f"  - バッチ {i//batch_size + 1} / {len(texts)//batch_size + 1} を処理しました。")

    print(f"ベクトルストア ({SUPPORTED_LANGUAGES[lang]}) のセットアップが完了しました。")
    return vectorstore

def load_prompt_template(file_path):
    """テキストファイルからプロンプトテンプレートを読み込む"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read()

def create_conversational_chain(vectorstore, lang="ja"):
    """
    会話の文脈を考慮し、ルールブックから情報を検索して回答を生成するチェーンを作成する。
    """
    # 1. LLMの定義
    llm = ChatOpenAI(model="gpt-4o", temperature=0.7)

    # 2. プロンプトの定義
    prompt_file = f"prompts/rulebook_chat_{lang}.txt"
    template = load_prompt_template(prompt_file)
    prompt = PromptTemplate(template=template, input_variables=["context", "chat_history", "question"])

    # 3. retrieverの定義（検索パラメータを調整）
    retriever = vectorstore.as_retriever(
        search_type="mmr",
        search_kwargs={'k': 15, 'fetch_k': 100}  # より多くの文書を取得
    )

    # 4. 会話チェーンを組み立てる
    chain = ConversationalRetrievalChain.from_llm(
        llm=llm,
        retriever=retriever,
        memory=ConversationBufferMemory(
            memory_key="chat_history", 
            return_messages=True, 
            output_key='answer',
            input_key='question'
        ),
        return_source_documents=True,
        combine_docs_chain_kwargs={'prompt': prompt},
        verbose=False
    )

    return chain 