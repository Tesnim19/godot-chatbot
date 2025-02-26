import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, File, UploadFile
from server.connection import ConnectionManager
from server.ai_agent import AIAgent
from fastapi.staticfiles import StaticFiles
import glob
import os
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

app = FastAPI()

manager = ConnectionManager()

agent = AIAgent(model_type="gemini")
project_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))       
agent.load_document(f'{project_path}/server/public')
agent.load_3d_models()

app.mount("/public", StaticFiles(directory=f'{project_path}/server/public/'), name="public")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    print('connected')
    try:
        while True:
            data = await websocket.receive_text()
            # Parse the incoming message as JSON
            message_data = json.loads(data)
            if message_data.get("type") == "chat":
                # Get the actual message content
                query = message_data.get("content")
                # Use the instance of AIAgent
                response = agent.generate_answer(query)
                # Send the response back to the client
                await manager.send(json.dumps(response))
    except WebSocketDisconnect:
        manager.disconnect()
    except Exception as e:
        error_response = {
            "type": "error",
            "message": str(e)
        }
        await manager.send(json.dumps(error_response))

@app.post("/upload")
async def upload_pdf(file: UploadFile, response: Response):
    try:
        contents = await file.read()
        with open(f'{project_path}/server/public/{file.filename}', "wb") as f:
            f.write(contents)
        
        agent.load_single_document(f'./public/{file.filename}')
        return {"message": "File uploaded successfully"}
    except Exception as e:
        response.status_code = 500
        return {"error": str(e)}

@app.get("/documents")
async def get_documents(response: Response):
    try:
        files = [file.split('/')[-1] for file in glob.glob(f"{project_path}/server/public/*.pdf")]
        return {"documents": files}
    except Exception as e:
        response.status_code = 500
        return {"error": str(e)}

class ModelUpdateRequest(BaseModel):
    model_type: str

@app.post("/model")
async def update_model(request: ModelUpdateRequest, response: Response):
    model_type = request.model_type
    if model_type == None:
        response.status_code = 400
        return {"error": "Model type is required"}
    
    supported_types = ["t5-base", "gemini"]
    
    if model_type not in supported_types:
        response.status_code = 400
        return {"error": "Invalid model type. Supported types are t5-base and gemini"}
    try:
        agent.update_model(model_type)
        response.status_code = 200
        return {"message": "Model updated successfully"}
    except Exception as e:
        response.status_code = 500
        return {"error": str(e)}
