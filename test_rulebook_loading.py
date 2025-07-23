#!/usr/bin/env python3
"""
ルールブック読み込みテストスクリプト
OpenAI APIキーなしでPDFの内容確認とチャンク分割をテスト
"""

import pdfplumber
import warnings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document

warnings.filterwarnings('ignore')

def test_pdf_loading():
    """PDFの読み込みとチャンク分割をテスト"""
    print("🏅 体操AIルールブック読み込みテスト")
    print("=" * 50)
    
    # 日本語ルールブックのテスト
    pdf_path = "data/rulebook_ja.pdf"
    
    try:
        all_docs = []
        
        with pdfplumber.open(pdf_path) as pdf:
            total_pages = len(pdf.pages)
            print(f"📋 総ページ数: {total_pages}ページ")
            
            for i, page in enumerate(pdf.pages[:5]):  # 最初の5ページをテスト
                text = page.extract_text() or ""
                
                # テーブル抽出
                tables = page.extract_tables()
                tables_md = ""
                if tables:
                    for table in tables:
                        clean_table = [[str(cell) if cell is not None else "" for cell in row] for row in table]
                        if clean_table:
                            header = "| " + " | ".join(clean_table[0]) + " |"
                            separator = "| " + " | ".join(["---"] * len(clean_table[0])) + " |"
                            rows = "\n".join(["| " + " | ".join(row) + " |" for row in clean_table[1:]])
                            tables_md += f"\n{header}\n{separator}\n{rows}\n"
                
                page_content = text + tables_md
                metadata = {"source": pdf_path, "page": i}
                doc = Document(page_content=page_content, metadata=metadata)
                all_docs.append(doc)
                
                print(f"  ページ {i+1}: {len(text)}文字, テーブル数: {len(tables) if tables else 0}")
        
        print(f"\n📊 読み込み完了: {len(all_docs)}ページ")
        
        # チャンク分割テスト
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1200,
            chunk_overlap=300,
            separators=["\n\n", "\n", "。", ".", " ", ""]
        )
        
        texts = text_splitter.split_documents(all_docs)
        print(f"🔄 チャンク分割結果: {len(texts)}チャンク")
        
        # サンプルチャンクの表示
        if texts:
            sample_chunk = texts[0]
            print(f"\n📝 サンプルチャンク:")
            print(f"  文字数: {len(sample_chunk.page_content)}")
            print(f"  メタデータ: {sample_chunk.metadata}")
            print(f"  内容: {sample_chunk.page_content[:300]}...")
        
        # 体操技術関連のキーワード検索テスト
        print(f"\n🔍 キーワード検索テスト:")
        keywords = ["鉄棒", "手放し技", "難度", "減点", "着地"]
        
        for keyword in keywords:
            found_chunks = [chunk for chunk in texts if keyword in chunk.page_content]
            print(f"  '{keyword}': {len(found_chunks)}チャンク")
            
            if found_chunks:
                sample = found_chunks[0].page_content
                # キーワード周辺のテキストを表示
                idx = sample.find(keyword)
                if idx != -1:
                    start = max(0, idx - 50)
                    end = min(len(sample), idx + 100)
                    context = sample[start:end].replace('\n', ' ')
                    print(f"    例: ...{context}...")
        
        print(f"\n✅ ルールブック読み込みテスト完了！")
        print(f"💡 実際のAI機能を使用するにはOpenAI APIキーが必要です")
        
    except Exception as e:
        print(f"❌ エラー: {e}")

if __name__ == "__main__":
    test_pdf_loading()