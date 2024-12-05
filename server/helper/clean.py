from PyPDF2 import PdfReader
import re
import easyocr
import torch
import langchain_core

# Check if GPU is available
gpu_available = torch.cuda.is_available()

# Initialize EasyOCR reader with GPU support if available
reader = easyocr.Reader(["en"], gpu=gpu_available)

def clean_text(text):
    """
    Cleans extracted text by removing unwanted patterns and normalizing it.
    """
    text = re.sub(r"^\s*\d+\s*[/of]\s*\d+\s*$", "", text, flags=re.IGNORECASE | re.MULTILINE)
    text = re.sub(r"^\s*\d+\s*[—-]\s*\d+\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*(Figure|Page|Table)\s*\d+\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text

def handle_ocr_errors(text):
    """
    Handles common OCR issues with context-specific rules.
    """
    corrected_text = text
    corrected_text = re.sub(r'1(\W)', r'I\1', corrected_text)  # '1' -> 'I'
    corrected_text = re.sub(r'I(\d)', r'1\1', corrected_text)  # 'I' -> '1'
    corrected_text = corrected_text.replace("0", "O")  # '0' -> 'O'
    return corrected_text    

def extract_text_by_page(documents):
    text = ""
    for document in documents:
        if isinstance(document, langchain_core.documents.base.Document):  # Validate type
            raw_text = document.page_content
            print("raw text: ", type(raw_text))  # Debugging info
            
            # Clean the text if necessary
            cleaned_text = clean_text(raw_text)
            if cleaned_text:
                text += cleaned_text
        else:
            print("Invalid document type:", type(document))
    return text

def extract_text_from_image(pdf_path, page_num):

    try:
        import fitz  # PyMuPDF
        pdf_document = fitz.open(pdf_path)
        page = pdf_document.load_page(page_num)
        pix = page.get_pixmap()
        img_data = pix.tobytes("png")  # Convert to PNG byte data

        ocr_result = reader.readtext(img_data, detail=0)
        text = " ".join(ocr_result)
        text = handle_ocr_errors(text)
        return text 
    except Exception as e:
        print(f"Error processing page {page_num + 1} with OCR: {e}")
        return ""