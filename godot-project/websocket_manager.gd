extends Node

class_name WebSocketManager

var websocket: WebSocketPeer
var socket_url = "ws://localhost:8000/ws"
var connection_status = false
var disconnect = false

signal connection_status_changed(is_connected: bool)
signal message_received(message: Dictionary)

func setup_websocket():
    websocket = WebSocketPeer.new()
    _attempt_connection()

func _attempt_connection():
    var err = websocket.connect_to_url(socket_url)
    if err != OK:
        print("Waiting to connect to WebSocket server: ", err)
        emit_signal("connection_status_changed", false)
    else:
        print("Attempting to connect to WebSocket server...")

func disconnect_websocket():
    disconnect = true
    if websocket and websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        websocket.close(1000, "Client disconnecting")
    connection_status = false
    emit_signal("connection_status_changed", false)

func reconnect_websocket():
    disconnect = false
    _attempt_connection()

func send_message(message: Dictionary) -> bool:
    if !connection_status:
        print("Not connected to server!")
        return false
        
    var json_string = JSON.stringify(message)
    var err = websocket.send_text(json_string)
    if err != OK:
        print("Failed to send message: ", err)
        return false
    return true

func _process(_delta):
    if websocket:
        websocket.poll()
        var state = websocket.get_ready_state()
        
        match state:
            WebSocketPeer.STATE_OPEN:
                if !connection_status:
                    print("Connected to server!")
                    connection_status = true
                    emit_signal("connection_status_changed", true)
                
                while websocket.get_available_packet_count():
                    var packet = websocket.get_packet()
                    var message = packet.get_string_from_utf8()
                    _handle_websocket_message(message)
            
            WebSocketPeer.STATE_CLOSING:
                if connection_status:
                    print("Disconnecting from server...")
                    connection_status = false
                    emit_signal("connection_status_changed", false)
            
            WebSocketPeer.STATE_CLOSED:
                if connection_status:
                    print("Disconnected from server")
                    connection_status = false
                    emit_signal("connection_status_changed", false)
                
                # Attempt reconnection if not manually disconnected
                if !disconnect:
                    _attempt_connection()

func _handle_websocket_message(message: String):
    print("Received message: ", message)
    
    var json = JSON.new()
    var error = json.parse(message)
    
    if error == OK:
        var data = json.get_data()
        if data is Dictionary:
            emit_signal("message_received", data)
        else:
            print("Received non-dictionary JSON data")
            emit_signal("message_received", {"type": "error", "message": "Invalid message format"})
    else:
        print("Failed to parse message as JSON")
        emit_signal("message_received", {"type": "error", "message": "Failed to parse server message"})

func is_connected() -> bool:
    return connection_status

func get_connection_state() -> String:
    if !websocket:
        return "UNINITIALIZED"
        
    match websocket.get_ready_state():
        WebSocketPeer.STATE_CONNECTING:
            return "CONNECTING"
        WebSocketPeer.STATE_OPEN:
            return "CONNECTED"
        WebSocketPeer.STATE_CLOSING:
            return "CLOSING"
        WebSocketPeer.STATE_CLOSED:
            return "DISCONNECTED"
        _:
            return "UNKNOWN"

func send_chat_message(content: String) -> bool:
    var message = {
        "type": "chat",
        "content": content
    }
    return send_message(message)

func send_model_change(model_name: String) -> bool:
    var message = {
        "type": "model_change",
        "model": model_name
    }
    return send_message(message)

func send_document_query(query: String, context: Dictionary = {}) -> bool:
    var message = {
        "type": "document_query",
        "query": query,
        "context": context
    }
    return send_message(message)