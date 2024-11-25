extends Control

var chat_container: VBoxContainer
var chat_output: RichTextLabel
var input_container: HBoxContainer
var chat_input: LineEdit
var send_button: Button
var upload_button: Button
var websocket: WebSocketPeer
var socket_url = "ws://localhost:8080"
var connection_status = false

func _ready():
	setup_ui()
	setup_websocket()
	print("Application started")

func setup_ui():
	# Set the main control (self) to fill the viewport
	custom_minimum_size = Vector2(800, 600)
	anchor_right = 1
	anchor_bottom = 1
	
	# Create a background panel for the entire UI
	var background_panel = PanelContainer.new()
	background_panel.anchor_right = 1
	background_panel.anchor_bottom = 1
	
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.12, 0.12, 0.14) # Dark background
	background_style.shadow_size = 4
	add_child(background_panel)
	background_panel.add_theme_stylebox_override("panel", background_style)
	
	# Add margins around the main container
	var margin_container = MarginContainer.new()
	margin_container.anchor_right = 1
	margin_container.anchor_bottom = 1
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	background_panel.add_child(margin_container)
	
	# Main layout
	chat_container = VBoxContainer.new()
	chat_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(chat_container)
	
	# Title section
	var title_container = HBoxContainer.new()
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.add_child(title_container)
	
	var title_label = Label.new()
	title_label.text = "Chat Assistant"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title_label.add_theme_font_size_override("font_size", 24)
	title_container.add_child(title_label)
	
	# Add spacing after title
	var title_spacer = Control.new()
	title_spacer.custom_minimum_size.y = 15
	chat_container.add_child(title_spacer)
	
	# Chat output area with enhanced styling
	var output_container = PanelContainer.new()
	output_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.custom_minimum_size.y = 300
	
	var output_style = StyleBoxFlat.new()
	output_style.bg_color = Color(0.18, 0.18, 0.2) # Slightly lighter than background
	output_style.border_color = Color(0.3, 0.3, 0.35)
	output_style.border_width_left = 1
	output_style.border_width_right = 1
	output_style.border_width_top = 1
	output_style.border_width_bottom = 1
	output_style.corner_radius_top_left = 8
	output_style.corner_radius_top_right = 8
	output_style.corner_radius_bottom_left = 8
	output_style.corner_radius_bottom_right = 8
	output_style.shadow_color = Color(0, 0, 0, 0.2)
	output_style.shadow_size = 4
	output_style.shadow_offset = Vector2(0, 2)
	output_container.add_theme_stylebox_override("panel", output_style)
	
	chat_container.add_child(output_container)
	
	chat_output = RichTextLabel.new()
	chat_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_output.scroll_following = true
	chat_output.bbcode_enabled = true
	chat_output.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
	chat_output.add_theme_font_size_override("normal_font_size", 14)
	
	var output_margin = MarginContainer.new()
	output_margin.add_theme_constant_override("margin_left", 12)
	output_margin.add_theme_constant_override("margin_right", 12)
	output_margin.add_theme_constant_override("margin_top", 12)
	output_margin.add_theme_constant_override("margin_bottom", 12)
	output_margin.add_child(chat_output)
	output_container.add_child(output_margin)
	
	# Spacing between chat output and input area
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 15
	chat_container.add_child(spacer)
	
	# Input container with enhanced styling
	input_container = HBoxContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.add_child(input_container)
	
	# Upload button with enhanced styling
	upload_button = Button.new()
	upload_button.text = "Upload PDF"
	upload_button.custom_minimum_size = Vector2(110, 42)
	upload_button.pressed.connect(_on_upload_pressed)
	
	var upload_button_style = StyleBoxFlat.new()
	upload_button_style.bg_color = Color(0.2, 0.4, 0.8)
	upload_button_style.corner_radius_top_left = 6
	upload_button_style.corner_radius_top_right = 6
	upload_button_style.corner_radius_bottom_left = 6
	upload_button_style.corner_radius_bottom_right = 6
	
	var upload_button_hover_style = upload_button_style.duplicate()
	upload_button_hover_style.bg_color = Color(0.25, 0.45, 0.85)
	
	var upload_button_pressed_style = upload_button_style.duplicate()
	upload_button_pressed_style.bg_color = Color(0.15, 0.35, 0.75)
	
	upload_button.add_theme_stylebox_override("normal", upload_button_style)
	upload_button.add_theme_stylebox_override("hover", upload_button_hover_style)
	upload_button.add_theme_stylebox_override("pressed", upload_button_pressed_style)
	upload_button.add_theme_color_override("font_color", Color.WHITE)
	upload_button.add_theme_color_override("font_hover_color", Color.WHITE)
	upload_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	input_container.add_child(upload_button)
	
	# Spacing between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size.x = 12
	input_container.add_child(button_spacer)
	
	# Chat input field with enhanced styling
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = "Type your message..."
	chat_input.custom_minimum_size.y = 42
	chat_input.text_submitted.connect(_on_message_sent)
	
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.22, 0.22, 0.25)
	input_style.border_color = Color(0.3, 0.3, 0.35)
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_width_top = 1
	input_style.border_width_bottom = 1
	input_style.corner_radius_top_left = 6
	input_style.corner_radius_top_right = 6
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	
	chat_input.add_theme_stylebox_override("normal", input_style)
	chat_input.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.55))
	chat_input.add_theme_font_size_override("font_size", 14)
	input_container.add_child(chat_input)
	
	# Spacing between input and send button
	var input_spacer = Control.new()
	input_spacer.custom_minimum_size.x = 12
	input_container.add_child(input_spacer)
	
	# Send button with enhanced styling
	send_button = Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(85, 42)
	send_button.pressed.connect(_on_send_pressed)
	
	var send_button_style = StyleBoxFlat.new()
	send_button_style.bg_color = Color(0.2, 0.7, 0.4)
	send_button_style.corner_radius_top_left = 6
	send_button_style.corner_radius_top_right = 6
	send_button_style.corner_radius_bottom_left = 6
	send_button_style.corner_radius_bottom_right = 6
	
	var send_button_hover_style = send_button_style.duplicate()
	send_button_hover_style.bg_color = Color(0.25, 0.75, 0.45)
	
	var send_button_pressed_style = send_button_style.duplicate()
	send_button_pressed_style.bg_color = Color(0.15, 0.65, 0.35)
	
	send_button.add_theme_stylebox_override("normal", send_button_style)
	send_button.add_theme_stylebox_override("hover", send_button_hover_style)
	send_button.add_theme_stylebox_override("pressed", send_button_pressed_style)
	send_button.add_theme_color_override("font_color", Color.WHITE)
	send_button.add_theme_color_override("font_hover_color", Color.WHITE)
	send_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	input_container.add_child(send_button)
	
	# Bottom spacing
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size.y = 10
	chat_container.add_child(bottom_spacer)

func setup_websocket():
	websocket = WebSocketPeer.new()
	var err = websocket.connect_to_url(socket_url)
	if err != OK:
		print("Failed to connect to WebSocket server: ", err)
		add_message("System", "Failed to connect to server!")
	else:
		print("Attempting to connect to WebSocket server...")
		add_message("System", "Attempting to connect to server...")

func _process(_delta):
	if websocket:
		websocket.poll()
		var state = websocket.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				if !connection_status:
					print("Connected to server!")
					add_message("System", "Connected to server!")
					connection_status = true
				# Check for messages
				while websocket.get_available_packet_count():
					var packet = websocket.get_packet()
					var message = packet.get_string_from_utf8()
					print("Received message: ", message)
					
					# Try to parse as JSON
					var json = JSON.new()
					var error = json.parse(message)
					if error == OK:
						var response = json.get_data()
						match response.get("type"):
							"chat":
								add_message("Server", response.get("message"))
							"error":
								add_message("System", response.get("message"))
							"chunk_received":
								add_message("System", "PDF chunk %d/%d received" % [
									response.get("chunk_index") + 1,
									response.get("total_chunks")
								])
							"transfer_complete":
								add_message("System", response.get("message"))
							_:
								add_message("Server", message)
					else:
						# Fallback for non-JSON messages
						add_message("Server", message)

func _on_send_pressed():
	if chat_input.text.strip_edges() != "":
		_on_message_sent(chat_input.text)

func _on_message_sent(text: String):
	if !connection_status:
		print("Not connected to server!")
		add_message("System", "Not connected to server!")
		return
		
	print("Sending message: ", text)
	add_message("You", text)
	
	# Format regular text messages as JSON
	var message_data = {
		"type": "chat",
		"content": text
	}
	
	var err = websocket.send_text(JSON.stringify(message_data))
	if err != OK:
		print("Failed to send message: ", err)
		add_message("System", "Failed to send message!")
	chat_input.text = ""

func _on_pdf_selected(path: String):
	print("PDF selected: ", path)
	if !connection_status:
		print("Not connected to server!")
		add_message("System", "Not connected to server!")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		print("Failed to open file!")
		add_message("System", "Failed to open file!")
		return
		
	var file_data = file.get_buffer(file.get_length())
	file.close()
	
	# Smaller chunk size to avoid WebSocket limitations
	var chunk_size = 32 * 1024  # 32KB chunks
	var total_size = file_data.size()
	var current_pos = 0
	var total_chunks = ceil(float(total_size) / chunk_size)
	
	# Send initial metadata message
	var metadata = {
		"type": "pdf_metadata",
		"name": path.get_file(),
		"total_size": total_size,
		"chunk_size": chunk_size,
		"total_chunks": total_chunks
	}
	
	var err = websocket.send_text(JSON.stringify(metadata))
	if err != OK:
		print("Failed to send PDF metadata: ", err)
		add_message("System", "Failed to send PDF metadata!")
		return
	
	# Add slight delay between chunks to prevent overwhelming the connection
	while current_pos < total_size:
		var chunk_end = min(current_pos + chunk_size, total_size)
		var chunk = file_data.slice(current_pos, chunk_end)
		
		var chunk_info = {
			"type": "pdf_chunk",
			"name": path.get_file(),
			"chunk_index": current_pos / chunk_size,
			"total_chunks": total_chunks,
			"size": chunk.size(),
			"content": Marshalls.raw_to_base64(chunk)
		}
		
		var json_string = JSON.stringify(chunk_info)
		print("Sending PDF chunk %d/%d (size: %d bytes)..." % [
			chunk_info.chunk_index + 1, 
			chunk_info.total_chunks,
			chunk_info.size
		])
		
		err = websocket.send_text(json_string)
		if err != OK:
			print("Failed to send PDF chunk: ", err)
			add_message("System", "Failed to send PDF chunk %d/%d!" % [
				chunk_info.chunk_index + 1,
				chunk_info.total_chunks
			])
			return
			
		# Add a small delay between chunks
		await get_tree().create_timer(0.05).timeout
		
		current_pos = chunk_end
	
	# Send completion message
	var completion_info = {
		"type": "pdf_complete",
		"name": path.get_file(),
		"total_chunks_sent": total_chunks
	}
	
	err = websocket.send_text(JSON.stringify(completion_info))
	if err != OK:
		print("Failed to send PDF completion message: ", err)
		add_message("System", "Failed to send PDF completion message!")
		return
	
	print("PDF sent successfully in %d chunks" % total_chunks)
	add_message("System", "PDF sent to server: %s (%d chunks)" % [path.get_file(), total_chunks])

func add_message(sender: String, message: String):
	var timestamp = Time.get_datetime_string_from_system()
	var color_code = ""
	
	# Color-code different message types
	match sender:
		"System":
			color_code = "[color=#FFA500]"  # Orange for system messages
		"Server":
			color_code = "[color=#4CAF50]"  # Green for server messages
		"You":
			color_code = "[color=#2196F3]"  # Blue for user messages
		_:
			color_code = "[color=#FFFFFF]"  # White for other messages
	
	var formatted_message = "[%s] %s%s:[/color] %s\n" % [
		timestamp,
		color_code,
		sender,
		message
	]
	
	print("Adding message to chat: ", formatted_message)
	chat_output.append_text(formatted_message)

func _on_upload_pressed():
	var file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.pdf ; PDF Files"])
	file_dialog.file_selected.connect(_on_pdf_selected)
	
	# Make dialog a good size
	file_dialog.size = Vector2(500, 400)
	add_child(file_dialog)
	file_dialog.popup_centered()
