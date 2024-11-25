from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from server.connection import ConnectionManager

app = FastAPI()

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.send(f"You wrote: {data}")
    except WebSocketDisconnect:
        manager.disconnect()
