from langchain_community.document_loaders.pdf import PyPDFDirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import Chroma
import shutil
import os
import torch
from langchain_huggingface import HuggingFaceEmbeddings
from transformers import T5Tokenizer, T5ForConditionalGeneration

class AIAgent:
    def __init__(self):
        self.document = None
        self.chroma_path = 'chroma'
        self.db = None
        self.retriver = None
        self.langchain_embeddings = HuggingFaceEmbeddings(model_name="distilbert-base-nli-stsb-mean-tokens")

        self.model = T5ForConditionalGeneration.from_pretrained("t5-small")
        self.t5tokenizer = T5Tokenizer.from_pretrained("t5-small")

    def load_document(self, path):
        document_loader = PyPDFDirectoryLoader(path)
        self.document = document_loader.load()
        print("Document", self.document)
        self.split_text()

    def split_text(self):
        # Clear out the existing database directory if it exists
        if os.path.exists(self.chroma_path):
            shutil.rmtree(self.chroma_path)

        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=400,  # Size of each chunk in characters
            chunk_overlap=100,  # Overlap between consecutive chunks
            length_function=len,  # Function to compute the length of the text
            add_start_index=True,  # Flag to add start index to each chunk
        )

        # Split documents into smaller chunks using the text splitter
        chunks = text_splitter.split_documents(self.document)
        self.document = chunks
        print("CUNCKS", self.document)
        self.tokenize_and_store()

    def tokenize_and_store(self):
        # Clear existing database if present
        if os.path.exists(self.chroma_path):
            shutil.rmtree(self.chroma_path)

        self.db=Chroma.from_documents(
            self.document,
            self.langchain_embeddings
        )
        self.retriver = self.db.as_retriever()
        print(f"Saved {len(self.document)} chunks to {self.chroma_path}.")

    def retrive_documents(self, question):
      # Retrieve the most relevant documents based on the query embedding
      results = self.retriver.get_relevant_documents(question)

      # If there are results, return the content of all relevant documents
      if results:
          return "\n\n".join([result.page_content for result in results])  # Join all documents' content with a newline in between

      return "No relevant documents found."

    def generate_answer(self, question):
        # Retrieve documents (context) based on the question
        documents = self.retrive_documents(question)

        # Combine the question and context into a single string
        input_text = f"question: {question} context: {documents}"

        # Tokenize the input text
        inputs =  self.t5tokenizer(input_text, return_tensors="pt", max_length=512, truncation=True, padding=True)

        # Perform inference to get the model output (generated answer)
        with torch.no_grad():
            outputs = self.model.generate(inputs["input_ids"], max_length=50, num_beams=4, early_stopping=True)

        # Decode the tokens to get the answer text
        predicted_answer = self.t5tokenizer.decode(outputs[0], skip_special_tokens=True)

        # Print the predicted answer
        print(f"Predicted Answer: {predicted_answer}")




#agent = AIAgent()
#agent.load_document('./public')
#agent.generate_answer('What is the output current of the EL7411 BLDC motor?') # question
#What is the peak current for the EL7411 motor?
#What is the output current of the EL7411 BLDC motor?
#What type of encoder feedback does the motor support?
