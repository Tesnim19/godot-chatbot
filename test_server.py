import asyncio
import websockets
import json
import base64
import os
import logging
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Dict, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('pdf_server.log')
    ]
)

@dataclass
class PDFMetadata:
    name: str
    total_size: int
    chunk_size: int
    total_chunks: int
    timestamp: str = str(datetime.now())
    
@dataclass
class PDFTransfer:
    metadata: PDFMetadata
    chunks: Dict[int, bytes]
    chunks_received: int = 0
    
    def is_complete(self) -> bool:
        return self.chunks_received == self.metadata.total_chunks
    
    def add_chunk(self, index: int, data: bytes) -> None:
        self.chunks[index] = data
        self.chunks_received += 1

class PDFAssembler:
    def __init__(self, upload_dir: str = "uploads"):
        self.transfers: Dict[str, PDFTransfer] = {}
        self.upload_dir = upload_dir
        
        # Create uploads directory if it doesn't exist
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)
    
    def initialize_transfer(self, metadata: Dict) -> PDFMetadata:
        pdf_metadata = PDFMetadata(
            name=metadata["name"],
            total_size=metadata["total_size"],
            chunk_size=metadata["chunk_size"],
            total_chunks=metadata["total_chunks"]
        )
        
        self.transfers[metadata["name"]] = PDFTransfer(
            metadata=pdf_metadata,
            chunks={}
        )
        
        return pdf_metadata
    
    def add_chunk(self, filename: str, chunk_index: int, content: bytes) -> Optional[str]:
        """Add a chunk and return the output filename if transfer is complete"""
        if filename not in self.transfers:
            raise ValueError(f"No active transfer for {filename}")
            
        transfer = self.transfers[filename]
        transfer.add_chunk(chunk_index, content)
        
        if transfer.is_complete():
            return self._save_complete_pdf(filename)
        return None
    
    def _save_complete_pdf(self, filename: str) -> str:
        transfer = self.transfers[filename]
        
        # Assemble chunks in order
        pdf_data = b"".join(
            transfer.chunks[i] 
            for i in range(transfer.metadata.total_chunks)
        )
        
        # Verify total size
        if len(pdf_data) != transfer.metadata.total_size:
            raise ValueError(
                f"Size mismatch for {filename}. "
                f"Expected {transfer.metadata.total_size}, "
                f"got {len(pdf_data)}"
            )
        
        # Save file with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_filename = os.path.join(
            self.upload_dir,
            f"{timestamp}_{filename}"
        )
        
        with open(output_filename, "wb") as f:
            f.write(pdf_data)
        
        # Cleanup transfer data
        del self.transfers[filename]
        
        return output_filename

async def handle_client(websocket):
    client_id = id(websocket)
    logging.info(f"Client connected! ID: {client_id}")
    pdf_assembler = PDFAssembler()
    
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get("type", "")
                
                if msg_type == "pdf_metadata":
                    logging.info(f"Received PDF metadata from client {client_id}: {data['name']}")
                    metadata = pdf_assembler.initialize_transfer(data)
                    await websocket.send(json.dumps({
                        "type": "metadata_received",
                        "name": data["name"],
                        "message": "Ready to receive PDF chunks"
                    }))
                
                elif msg_type == "pdf_chunk":
                    chunk_index = data["chunk_index"]
                    filename = data["name"]
                    logging.info(
                        f"Processing chunk {chunk_index + 1}/{data['total_chunks']} "
                        f"of {filename} from client {client_id}"
                    )
                    
                    try:
                        chunk_content = base64.b64decode(data["content"])
                        output_file = pdf_assembler.add_chunk(
                            filename,
                            chunk_index,
                            chunk_content
                        )
                        
                        if output_file:
                            response = {
                                "type": "transfer_complete",
                                "name": filename,
                                "message": f"PDF saved as: {output_file}",
                                "success": True
                            }
                        else:
                            response = {
                                "type": "chunk_received",
                                "chunk_index": chunk_index,
                                "total_chunks": data["total_chunks"],
                                "name": filename
                            }
                        
                        await websocket.send(json.dumps(response))
                        
                    except ValueError as e:
                        logging.error(f"Error processing chunk: {str(e)}")
                        await websocket.send(json.dumps({
                            "type": "error",
                            "message": str(e)
                        }))
                
                elif msg_type == "pdf_complete":
                    logging.info(
                        f"Received completion message for {data['name']} "
                        f"from client {client_id}"
                    )
                    await websocket.send(json.dumps({
                        "type": "transfer_status",
                        "name": data["name"],
                        "message": "Transfer completed successfully"
                    }))
                
                elif msg_type == "chat":
                    # Handle regular chat messages
                    logging.info(f"Received chat message from client {client_id}: {data.get('content')}")
                    response = {
                        "type": "chat",
                        "message": f"Recieved: {data.get('content')}"
                    }
                    await websocket.send(json.dumps(response))
                
                else:
                    logging.warning(f"Unknown message type: {msg_type}")
                    await websocket.send(json.dumps({
                        "type": "error",
                        "message": f"Unknown message type: {msg_type}"
                    }))
                
            except json.JSONDecodeError as e:
                logging.error(f"JSON decode error: {str(e)}")
                await websocket.send(json.dumps({
                    "type": "error",
                    "message": "Invalid JSON format"
                }))
                
    except websockets.exceptions.ConnectionClosed as e:
        logging.info(f"Client {client_id} disconnected! Code: {e.code}, Reason: {e.reason}")
    except Exception as e:
        logging.error(f"Unexpected error with client {client_id}: {str(e)}")
        try:
            await websocket.send(json.dumps({
                "type": "error",
                "message": "Internal server error"
            }))
        except:
            pass

async def main():
    server = await websockets.serve(
        handle_client,
        "localhost",
        8080,
        ping_interval=20,
        ping_timeout=60,
        max_size=None  # Remove message size limit
    )
    
    logging.info("WebSocket server started on ws://localhost:8080")
    
    try:
        await server.wait_closed()
    except KeyboardInterrupt:
        logging.info("Server shutting down...")
        server.close()
        await server.wait_closed()
        logging.info("Server shutdown complete")

if __name__ == "__main__":
    asyncio.run(main())