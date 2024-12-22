from langchain_community.document_loaders.pdf import PyPDFDirectoryLoader, PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
import langchain_core
import shutil
import os
import torch
from langchain_huggingface import HuggingFaceEmbeddings
from transformers import T5Tokenizer, T5ForConditionalGeneration
from server.helper.clean import clean_text

class AIAgent:
    def __init__(self):
        self.document = None
        self.chroma_path = 'chroma'
        self.db = None
        self.retriver = None
        self.langchain_embeddings = HuggingFaceEmbeddings(model_name="distilbert-base-nli-stsb-mean-tokens")
        self.model = T5ForConditionalGeneration.from_pretrained("t5-base")
        self.t5tokenizer = T5Tokenizer.from_pretrained("t5-base")

    def load_document(self, path):
        document_loader = PyPDFDirectoryLoader(path)
        loaded_documents = document_loader.load()  # List of Document objects
        self.document = [
            langchain_core.documents.base.Document(
                page_content=clean_text(doc.page_content), 
                metadata=doc.metadata
            )
            for doc in loaded_documents
        ]
        self.split_text()

    def load_single_document(self, path):
        document_loader = PyPDFLoader(path)
        print('path: ', path)
        loaded_document = document_loader.load()
        print("loaded document", loaded_document)
        self.document = [
            langchain_core.documents.base.Document(
                page_content=clean_text(doc.page_content),
                metadata=doc.metadata
            )
            for doc in loaded_document
        ]
        self.split_text()

    def split_text(self):
        if os.path.exists(self.chroma_path):
            shutil.rmtree(self.chroma_path)

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=300,  # Reduce chunk size
            chunk_overlap=50,  # Adjust overlap
            length_function=len,
            add_start_index=True,
        )

        chunks = text_splitter.split_documents(self.document)
        self.document = chunks
        self.tokenize_and_store()

    def tokenize_and_store(self):
        if os.path.exists(self.chroma_path):
            shutil.rmtree(self.chroma_path)

        self.db = Chroma.from_documents(
            self.document,
            self.langchain_embeddings
        )
        self.retriver = self.db.as_retriever()
        print(f"Saved {len(self.document)} chunks to {self.chroma_path}.")

    def retrive_documents(self, question):
        # Retrieve the most relevant documents
        results = self.retriver.get_relevant_documents(question)

        if results:
            print(f"Top {len(results)} Retrieved Document(s):")
            for i, result in enumerate(results[:5]):
                # Add document path and page number in the output
                print(f"Document {i+1}: Path: {result.metadata.get('source')}, Page Number: {result.metadata.get('page')}, Content: {result.page_content[:500]}...")
            return results
        
        return []

    def generate_answer(self, question):
        results = self.retrive_documents(question)

        if not results:
            return "No relevant documents found."

        # Extract the content from the results
        documents = "\n\n".join([result.page_content for result in results])

        # Combine the question and context into a single string
        input_text = f"question: {question} context: {documents}"
        inputs = self.t5tokenizer(input_text, return_tensors="pt", max_length=1024, truncation=True, padding=True)

        with torch.no_grad():
            outputs = self.model.generate(inputs["input_ids"], max_length=50, num_beams=4, early_stopping=True)

        predicted_answer = self.t5tokenizer.decode(outputs[0], skip_special_tokens=True)

        # Now, return the predicted answer along with the document path and page number
        answer_with_metadata = []
        for result in results:
            document_info = {
                "document_path": result.metadata.get('source'),
                "page_number": result.metadata.get('page')
            }
            answer_with_metadata.append(document_info)

            response = {
                "answer": predicted_answer,
                "metadata": answer_with_metadata
            }

        return response

#agent = AIAgent()
#agent.load_document('./public')
#answer = agent.generate_answer('What type of encoder feedback does the motor support?')  # Example question
#print(answer
