from fastapi import FastAPI, WebSocket, WebSocketDisconnect, File, UploadFile
from server.connection import ConnectionManager
from server.ai_agent import AIAgent

app = FastAPI()

manager = ConnectionManager()

agent = AIAgent()
agent.load_document('./public')

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.send(f"You wrote: {data}")
    except WebSocketDisconnect:
        manager.disconnect()

@app.post("/upload")
async def upload_pdf(file: UploadFile):
    contents = await file.read()
    f = open(f'./public/{file.filename}', "wb")
    f.write(contents)
    f.close()
    agent.load_single_document(f'./public/{file.filename}')
    return {"message": "file uploaded successfuly"}