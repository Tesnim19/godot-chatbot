import torch
import importlib
from typing import List, Optional
import numpy.typing as npt 
from transformers import AutoTokenizer, AutoModel

class DistilBertEmbedding:
    def __init__(self, model_name: str = "distilbert-base-uncased", cache_dir: Optional[str] = None):
        try:  # Dynamically import torch
            self._tokenizer = AutoTokenizer.from_pretrained(model_name, cache_dir=cache_dir)
            self._model = AutoModel.from_pretrained(model_name, cache_dir=cache_dir)
        except ImportError:
            raise ValueError(
                "The transformers and/or pytorch python package is not installed. Please install it with "
                "`pip install transformers` or `pip install torch`"
            )

    @staticmethod
    def _normalize(vector: npt.NDArray) -> npt.NDArray:
        """Normalizes a vector to unit length using L2 norm."""
        norm = np.linalg.norm(vector)
        if norm == 0:
            return vector
        return vector / norm

    def __call__(self, input: List[str]) -> List[List[float]]:
        """
        Embed a list of input texts using DistilBERT and return the embeddings.

        Args:
        - input: List of strings (documents) to be embedded.

        Returns:
        - List of normalized embeddings for each document.
        """
        inputs = self._tokenizer(input, padding=True, truncation=True, return_tensors="pt")
        with torch.no_grad():
            outputs = self._model(**inputs)
        embeddings = outputs.last_hidden_state.mean(dim=1)  # Mean pooling of the last hidden state
        embeddings = self._normalize(embeddings.numpy())  # Normalize the embeddings
        return embeddings.tolist()  # Return as a list of lists

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        """
        Embed a list of documents using DistilBERT and return the embeddings.

        Args:
        - texts: List of strings (documents) to be embedded.

        Returns:
        - List of normalized embeddings for each document.
        """
        return self(texts)  # Reusing the __call__ method
