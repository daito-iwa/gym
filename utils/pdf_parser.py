import os
import pypdf
from dotenv import load_dotenv

# .envファイルから環境変数を読み込む
load_dotenv()

def extract_text_from_pdf_range(pdf_path, start_page, end_page):
    """PDFの指定ページ範囲からテキストを抽出する"""
    if not os.path.exists(pdf_path):
        raise FileNotFoundError(f"PDF file not found at {pdf_path}")
    
    text = ""
    pdf_password = os.getenv("PDF_PASSWORD")

    with open(pdf_path, 'rb') as f:
        try:
            reader = pypdf.PdfReader(f, password=pdf_password or None)
            if reader.is_encrypted and not reader.decrypt(pdf_password or ""):
                 raise Exception("Failed to decrypt PDF. Please check your PDF_PASSWORD in the .env file.")

            for i in range(start_page - 1, end_page):
                page = reader.pages[i]
                text += page.extract_text() + "\n"
        except pypdf.errors.FileNotDecryptedError:
            raise Exception("This PDF is password-protected. Please set the PDF_PASSWORD in your .env file.")

    return text

if __name__ == '__main__':
    PDF_PATH = "data/rulebook_ja.pdf"
    OUTPUT_TXT_PATH = "data/debug_page_19.txt"
    
    # 日本語版ルールブックの19ページのみを抽出
    DEBUG_PAGE = 19
    
    try:
        text = extract_text_from_pdf_range(PDF_PATH, DEBUG_PAGE, DEBUG_PAGE)
        
        with open(OUTPUT_TXT_PATH, 'w', encoding='utf-8') as f:
            f.write(text)
        
        print(f"Successfully extracted text from page {DEBUG_PAGE} to {OUTPUT_TXT_PATH}")

    except Exception as e:
        print(f"An error occurred during debug extraction: {e}") 