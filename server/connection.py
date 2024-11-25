from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        self.connection = None
    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connection = websocket
    def disconnect(self):
        self.connection = None
    async def send(self, message: str):
        await self.connection.send_text(message)
