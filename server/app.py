import requests
import logging
from pydantic import BaseModel
from fastapi.responses import JSONResponse, Response
import os
import glob
from fastapi.staticfiles import StaticFiles
import uvicorn
from server.ai_agent import AIAgent
from server.connection import ConnectionManager

import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, File, UploadFile

app = FastAPI()

project_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def setup_config():
    if not os.path.exists(f"{project_path}/server/config"):
        os.makedirs(f"{project_path}/server/config")
        with open(f"{project_path}/server/config/api_key.json", "w") as f:
            json.dump({"GOOGLE_API_KEY": "not-set"}, f)


def load_api_key():
    api_key_file = project_path + '/server/config/api_key.json'
    with open(api_key_file) as f:
        api_key = json.load(f)

    os.environ["GOOGLE_API_KEY"] = api_key.get("GOOGLE_API_KEY")


setup_config()
load_api_key()

manager = ConnectionManager()

agent = AIAgent(model_type="gemini")

app.mount(
    "/public", StaticFiles(directory=f'{project_path}/server/public/'), name="public")


def validate_api_key(api_key):
    API_VERSION = "v1"
    # check if the api key is valid
    gemini_api = f'https://generativelanguage.googleapis.com/{API_VERSION}/models/gemini-2.0-flash?key={api_key}'
    try:
        res = requests.get(gemini_api)
        if res.status_code == 200:
            return True
        else:
            return False
    except Exception as e:
        raise Exception(f"Error validating the API")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")

    try:
        # check if the api key is empty or set to not-set
        if GOOGLE_API_KEY == None or GOOGLE_API_KEY == "not-set":
            await manager.send(json.dumps({'status': 'Failure', "message": "API key not set"}))
        else:
            is_valid = validate_api_key(GOOGLE_API_KEY)

            if is_valid:
                await manager.send(json.dumps({"status": "Success", "message": "API key is valid"}))
            else:
                await manager.send(json.dumps({"status": "Failure", "message": "API key is invalid"}))
        while True:
            data = await websocket.receive_text()
            # Parse the incoming message as JSON
            message_data = json.loads(data)
            if message_data.get("type") == "chat":
                # Get the actual message content
                query = message_data.get("content")
                # Get the specfied collection name
                pdf_name = message_data.get("pdf_name", None)
                # Use the instance of AIAgent
                response = agent.generate_answer(query, pdf_name)
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
            
        agent.load_single_document(
            f'{project_path}/server/public/{file.filename}')
        return {"message": "File uploaded successfully"}
    except Exception as e:
        os.remove(f"{project_path}/server/public/{file.filename}")
        response.status_code = 500
        logging.info(f"Error uploading a file {e}")
        return {"error": str(e)}


@app.get("/documents")
async def get_documents(response: Response):
    try:
        files = [file.split('/')[-1]
                 for file in glob.glob(f"{project_path}/server/public/*.pdf")]
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


class DocumentDeleteRequest(BaseModel):
    document_name: str


@app.post('/delete')
async def delete_document(request: DocumentDeleteRequest, response: Response):
    document_name = request.document_name
    try:
        os.remove(f"{project_path}/server/public/{document_name}")
        response.status_code = 200
        agent.delete_from_chroma(
            f'{project_path}/server/public/{document_name}')
        return {"message": "Document deleted successfully"}
    except Exception as e:
        logging.info(f"Error deleting a file {e}")
        response.status_code = 500
        return {"error": f"Error deleting a file {e}"}


@app.get("/check")
async def check_api_key(response: Response):
    # check if the api key is empty or set to not-set
    if os.environ.get("GOOGLE_API_KEY") == None or os.environ.get("GOOGLE_API_KEY") == "not-set":
        response.status_code = 404
        return {"message": "API key not set"}

    GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")
    try:
        is_valid = validate_api_key(GOOGLE_API_KEY)
        if is_valid:
            response.status_code = 200
            return {"message": "API key is valid"}
        else:
            response.status_code = 401
            return {"message": "API key is invalid"}
    except Exception as e:
        response.status_code = 500
        return {"error": str(e)}


class APIKEYRequest(BaseModel):
    api_key: str


@app.post("/api_key")
async def set_api_key(request: APIKEYRequest, response: Response):
    api_key = request.api_key
    if api_key == None:
        response.status_code = 400
        return {"error": "API key is invalid"}

    try:
        is_valid = validate_api_key(api_key)
        if is_valid:
            os.environ["GOOGLE_API_KEY"] = api_key
            api_key_file = project_path + '/server/config/api_key.json'
            with open(api_key_file) as f:
                api_key_json = json.load(f)

            api_key_json["GOOGLE_API_KEY"] = api_key

            with open(api_key_file, "w") as f:
                json.dump(api_key_json, f)

            response.status_code = 200
            return {"message": "API key set successfully"}
        else:
            response.status_code = 401
            return {"message": "API key is invalid"}
    except Exception as e:
        response.status_code = 500
        return {"error": str(e)}
