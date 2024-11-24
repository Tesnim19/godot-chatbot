from langchain.document_loaders.pdf import PyPDFDirectoryLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.vectorstores.chroma import Chroma
import shutil
import os
from server.embedding import DistilBertEmbedding

class AIAgent:
    def __init__(self):
        self.document = None
        self.chroma_path = 'chroma'
        self.db = None

        # Initialize the custom DistilBERT embedding class
        self.embedding_function = DistilBertEmbedding()

    def load_document(self, path):
        document_loader = PyPDFDirectoryLoader(path)
        self.document = document_loader.load()
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
        self.tokenize_and_store()

    def tokenize_and_store(self):
        # Clear existing database if present
        if os.path.exists(self.chroma_path):
            shutil.rmtree(self.chroma_path)

        # Generate embeddings and store in Chroma
        self.db = Chroma.from_documents(
            self.document,
            self.embedding_function,  # Use the embedding function object
            persist_directory=self.chroma_path
        )

        # Persist the database to disk
        self.db.persist()
        print(f"Saved {len(self.document)} chunks to {self.chroma_path}.")

agent = AIAgent()
agent.load_document('/content')
