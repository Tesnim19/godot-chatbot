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
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from dotenv import load_dotenv
import json
from langchain.docstore.document import Document

load_dotenv()
class AIAgent:
    def __init__(self, model_type='t5-base'):
        os.environ["GOOGLE_API_KEY"] = os.getenv("GOOGLE_API_KEY")
        self.model_type = model_type
        self.document = None
        self.chroma_path = 'chroma'
        self.db = None
        self.retriver = None
        #self.langchain_embeddings = HuggingFaceEmbeddings(model_name="distilbert-base-nli-stsb-mean-tokens")
        self.langchain_embeddings = GoogleGenerativeAIEmbeddings(model="models/text-embedding-004")
        self.t5tokenizer = T5Tokenizer.from_pretrained("t5-base")
        
        self.update_model(model_type)
    
    def update_model(self, model_type):
        self.model_type = model_type
        if self.model_type == 'gemini':
            self.model = ChatGoogleGenerativeAI(
                                model="gemini-1.5-flash",
                                temperature=0,
                                max_tokens=None,
                                timeout=None,
                                max_retries=2,
                       )
        else:
            self.model = T5ForConditionalGeneration.from_pretrained("t5-base")

    def load_document(self, path):
        document_loader = PyPDFDirectoryLoader(path)
        loaded_documents = document_loader.load()  # List of Document objects
        
        if not loaded_documents or len(loaded_documents) == 0:
            return 

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
        loaded_document = document_loader.load()
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
            self.langchain_embeddings,
            collection_name="documents",
        )
        self.retriver = self.db.as_retriever()
        print(f"Saved {len(self.document)} chunks to {self.chroma_path}.")

    def retrive_documents(self, question, collection_name):
        db = Chroma(collection_name=collection_name, embedding_function=self.langchain_embeddings)
        self.retriver = db.as_retriever()
        # Retrieve the most relevant documents
        results = self.retriver.get_relevant_documents(question)

        if results:
            print(f"Top {len(results)} Retrieved Document(s):")
            for i, result in enumerate(results[:5]):
                # Add document path and page number in the output
                print(f"Document {i+1}: Path: {result.metadata.get('source')}, Page Number: {result.metadata.get('page')}, Content: {result.page_content[:500]}...")
            return results
        
        return []

    def load_3d_models(self):
        json_path = './public/models/model_description.json'

        # Check if the file exists
        if not os.path.exists(json_path):
            return

        # Check if the file is empty
        if os.path.getsize(json_path) == 0:
            return

        # Load JSON data
        with open(json_path, 'r') as f:
            try:
                model_description = json.load(f)
            except json.JSONDecodeError:
                return

        # Check if the JSON is an empty array
        if not model_description or not isinstance(model_description, list):
            return

        # Process valid data
        document_ids = [model["path"] for model in model_description]  # Use the path as the ID
        documents = [
            Document(page_content=model["description"], metadata={"path": model["path"]})
            for model in model_description
        ]

        self.db = Chroma.from_documents(documents, 
                                        self.langchain_embeddings, 
                                        ids=document_ids, 
                                        collection_name='3d_object_descriptions')

        self.retriver = self.db.as_retriever()

        print(f"Saved {len(documents)} chunks to {self.chroma_path}. Models")

    def decide_action(self, question):
        if self.model_type != 'gemini':
            raise Exception("This method is only available for the Gemini model.")
        
        prompt = f"""You are an intelligent decision-making agent. Based on the input, determine whether to answer a question or generate a 3D model. 

        If the input suggests generating a 3D model, return 'generate'.  
        Otherwise, return 'answer'. Question: {question}"""
        
        decision = self.model.invoke(prompt)
        decision = decision.content
        
        return decision
        
    def generate_object(self, question):
        results = self.retrive_documents(question, '3d_object_descriptions')
        
        # select the top result
        if not results:
            return "No relevant documents found."
        
        document = results[0]
        path = document.metadata.get('path')
        
        response = {'type': 'generate', 'response': path}

        return response

    def answer_question(self, question):
        results = self.retrive_documents(question, 'documents')
        if not results:
            return "No relevant documents found."

        # Extract the content from the results
        documents = "\n\n".join([result.page_content for result in results])
        
        if self.model_type == 'gemini':
            prompt = f"""You are an assistant for question-answering tasks.
            Use the following context to answer the question.
            If you don't know the answer, just say that you don't know.
            Use five sentences maximum and keep the answer concise.\n
            Question: {question} \nContext: {documents} \nAnswer:"""
            
            predicted_answer = self.model.invoke(prompt)
            predicted_answer = predicted_answer.content
           
        else:
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
            
        final_response = {'type': 'answer', 'response': response}

        return final_response
    def generate_answer(self, question):
        decision = self.decide_action(question)
        
        if decision == 'generate':
            return self.generate_object(question)
        else:
            return self.answer_question(question)


#agent = AIAgent()
#agent.load_document('./public')
#answer = agent.generate_answer('What type of encoder feedback does the motor support?')  # Example question
#print(answer)
