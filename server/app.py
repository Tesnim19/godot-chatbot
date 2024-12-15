import json
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, File, UploadFile
from server.connection import ConnectionManager
from server.ai_agent import AIAgent
from fastapi.staticfiles import StaticFiles

app = FastAPI()

manager = ConnectionManager()

agent = AIAgent()
agent.load_document('./public')

app.mount("/public", StaticFiles(directory="public"), name="public")

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Parse the incoming message as JSON
            message_data = json.loads(data)
            if message_data.get("type") == "chat":
                # Get the actual message content
                query = message_data.get("content")
                # Use the instance of AIAgent, not the class
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
async def upload_pdf(file: UploadFile):
    try:
        contents = await file.read()
        with open(f'./public/{file.filename}', "wb") as f:
            f.write(contents)
        
        agent.load_single_document(f'./public/{file.filename}')
        return {"message": "File uploaded successfully"}
    except Exception as e:
        return {"error": str(e)}, 500