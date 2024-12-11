extends Control

var chat_container: VBoxContainer
var chat_output: RichTextLabel
var input_container: HBoxContainer
var chat_input: LineEdit
var send_button: Button
var upload_button: Button
var websocket: WebSocketPeer
var socket_url = "ws://localhost:8000/ws"
var connection_status = false
var http_request: HTTPRequest

var user_message : bool = true  # Set this based on the message sender
var message_container : VBoxContainer  # A VBoxContainer to hold message labels
var scroll_container : ScrollContainer  # The ScrollContainer that will hold the VBoxContainer


func _ready():
	setup_ui()
	setup_websocket()
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	print("Application started")

func setup_ui():
	# Set the main control (self) to fill the viewport with a minimum size
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
	margin_container.anchor_left = 0
	margin_container.anchor_top = 0
	margin_container.anchor_right = 1
	margin_container.anchor_bottom = 1

	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 60)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 60)
	background_panel.add_child(margin_container)
	
	# Main layout using VBoxContainer
	chat_container = VBoxContainer.new()
	chat_container.anchor_left = 0
	chat_container.anchor_top = 0
	chat_container.anchor_right = 1
	chat_container.anchor_bottom = 1

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
	
	# Input container at the top
	input_container = HBoxContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.add_child(input_container)
	
	# Upload button
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
	
	# Chat input field
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = "Type your message..."
	chat_input.custom_minimum_size.y = 36
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
	
	# Send button
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
	
	# Spacing after input section
	var input_section_spacer = Control.new()
	input_section_spacer.custom_minimum_size.y = 15
	chat_container.add_child(input_section_spacer)
	
	
	
	# Chat output area with enhanced styling
	var output_container = PanelContainer.new()
	output_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.custom_minimum_size.y = 300
	
	var output_style = StyleBoxFlat.new()
	output_style.bg_color = Color(0.18, 0.18, 0.2)
	output_style.corner_radius_top_left = 8
	output_style.corner_radius_top_right = 8
	output_style.corner_radius_bottom_left = 8
	output_style.corner_radius_bottom_right = 8
	output_container.add_theme_stylebox_override("panel", output_style)
	
	chat_container.add_child(output_container)
	
	# Create a ScrollContainer for messages
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create a VBoxContainer to hold all messages
	message_container = VBoxContainer.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var message_margin = MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 12)
	message_margin.add_theme_constant_override("margin_right", 12)
	message_margin.add_theme_constant_override("margin_top", 12)
	message_margin.add_theme_constant_override("margin_bottom", 12)
	message_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	message_margin.add_child(message_container)
	scroll_container.add_child(message_margin)
	output_container.add_child(scroll_container)

func setup_websocket():
	websocket = WebSocketPeer.new()
	var err = websocket.connect_to_url(socket_url)
	if err != OK:
		print("Failed to connect to WebSocket server: ", err)
		add_message("System", "Failed to connect to server!", false)
	else:
		print("Attempting to connect to WebSocket server...", false)
		add_message("System", "Attempting to connect to server...", false)

func _process(_delta):
	if websocket:
		websocket.poll()
		var state = websocket.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				if !connection_status:
					print("Connected to server!") # Keep console logging for debugging
					connection_status = true
				# Check for messages
				while websocket.get_available_packet_count():
					var packet = websocket.get_packet()
					var message = packet.get_string_from_utf8()
					print("Received message: ", message) # Keep console logging for debugging
					
					# Try to parse as JSON
					var json = JSON.new()
					var error = json.parse(message)
					if error == OK:
						var response = json.get_data()
						if response.has("answer"):
							# Handle structured response with metadata
							var answer_text = response.answer
							var metadata = response.get("metadata", [])
							add_message("Assistant", answer_text, false, metadata)
						else:
							# Handle regular chat messages
							match response.get("type"):
								"chat":
									add_message("Assistant", response.get("message"), false)
								"error", "chunk_received", "transfer_complete":
									print(response.get("message")) # Only log to console
								_:
									add_message("Assistant", message, false)
					else:
						# Fallback for non-JSON messages
						add_message("Assistant", message, false)

func _on_send_pressed():
	if chat_input.text.strip_edges() != "":
		_on_message_sent(chat_input.text)

func _on_message_sent(text: String):
	if !connection_status:
		print("Not connected to server!")
		add_message("System", "Not connected to server!", false)
		return
		
	print("Sending message: ", text)
	add_message("You", text, true)
	
	# Format regular text messages as JSON
	var message_data = {
		"type": "chat",
		"content": text
	}
	
	var err = websocket.send_text(JSON.stringify(message_data))
	if err != OK:
		print("Failed to send message: ", err)
		add_message("System", "Failed to send message!", false)
	chat_input.text = ""

func _on_pdf_selected(path: String):
	print("PDF selected: ", path)
	
	var file = FileAccess.open(path, FileAccess.READ)
	if !file:
		print("Failed to open file!")
		add_message("System", "Failed to open file!", false)
		return
		
	var file_data = file.get_buffer(file.get_length())
	file.close()
	
	# Create multipart form data
	var boundary = "GodotFormBoundary"
	var body = PackedByteArray()
	
	# Add file data
	var file_header = "\r\n--" + boundary + "\r\n"
	file_header += "Content-Disposition: form-data; name=\"file\"; filename=\"" + path.get_file() + "\"\r\n"
	file_header += "Content-Type: application/pdf\r\n\r\n"
	body.append_array(file_header.to_utf8_buffer())
	body.append_array(file_data)  # Append raw binary data
	
	# Add closing boundary
	var end_boundary = "\r\n--" + boundary + "--\r\n"
	body.append_array(end_boundary.to_utf8_buffer())
	
	# Set up headers
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary
	]
	
	# Send request
	var url = "http://localhost:8000/upload"  # Make sure this matches your server port
	var error = http_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("An error occurred while uploading the PDF")
		add_message("System", "Failed to upload PDF!", false)
	else:
		print("PDF upload started...")
		add_message("System", "Uploading PDF...", false)

func add_message(sender: String, text: String, is_user: bool = false, metadata = null):
	# Create message container with full width
	var message_row = HBoxContainer.new()
	message_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create left and right margins/spacers
	var left_margin = Control.new()
	var right_margin = Control.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
# Create the message bubble
	var message_bubble = PanelContainer.new()
	message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	message_bubble.custom_minimum_size.x = 600  # Increased from 200 to 400
	message_bubble.size_flags_stretch_ratio = 0.7  # This makes the bubble use up to 70% of available width
	
	
	# Style the bubble
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.25, 0.4, 0.7) if is_user else Color(0.2, 0.2, 0.22)
	bubble_style.corner_radius_top_left = 8
	bubble_style.corner_radius_top_right = 8
	bubble_style.corner_radius_bottom_left = 8
	bubble_style.corner_radius_bottom_right = 8
	message_bubble.add_theme_stylebox_override("panel", bubble_style)
	
	# Content margin
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	
	# Message content
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Sender name
	var name_label = Label.new()
	name_label.text = sender
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0) if is_user else Color(0.3, 0.8, 0.4))
	name_label.add_theme_font_size_override("font_size", 12)
	
	# Message text
	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size.x = 350
	text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	content.add_child(name_label)
	content.add_child(text_label)
	
	# Add metadata if present
	if metadata != null and metadata.size() > 0:
		var metadata_container = VBoxContainer.new()
		metadata_container.add_theme_constant_override("separation", 4)
		
		var refs_label = Label.new()
		refs_label.text = "References:"
		refs_label.add_theme_font_size_override("font_size", 11)
		refs_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		metadata_container.add_child(refs_label)
		
		for ref in metadata:
			var ref_label = Label.new()
			var pdf_name = ref.document_path.get_file()
			ref_label.text = "• %s (Page %d)" % [pdf_name, ref.page_number]
			ref_label.add_theme_font_size_override("font_size", 10)
			ref_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
			metadata_container.add_child(ref_label)
		
		content.add_child(metadata_container)
	
	# Assemble the message
	content_margin.add_child(content)
	message_bubble.add_child(content_margin)
	
	# Add components to row in correct order for alignment
	if is_user:
		message_row.add_child(left_margin)  # Pushes the bubble to the right
		message_row.add_child(message_bubble)
	else:
		message_row.add_child(message_bubble)
		message_row.add_child(right_margin)  # Pushes the bubble to the left
	
	# Add to message container with spacing
	message_container.add_child(message_row)
	
	# Add spacing between messages
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	message_container.add_child(spacer)
	
	# Scroll to bottom
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

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

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error during upload: ", result)
		add_message("System", "Upload failed!", false)
		return
		
	if response_code == 200:
		print("Upload successful!")
		add_message("System", "PDF uploaded successfully!", false)
		
		# Parse response if needed
		var json = JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		if error == OK:
			var response = json.get_data()
			print("Server response: ", response)
	else:
		print("Upload failed with code: ", response_code)
		add_message("System", "Upload failed with code: " + str(response_code), false)
