extends Control

var chat_container: VBoxContainer
var chat_input: LineEdit
var send_button: Button
var upload_button: Button
var websocket: WebSocketPeer
var socket_url = "ws://localhost:8000/ws"
var connection_status = false
var http_request: HTTPRequest
var message_container: VBoxContainer
var scroll_container: ScrollContainer
var fetch_documents_button: Button

# New UI elements
var chat_panel: PanelContainer
var toggle_button: Button
var is_chat_open = false

#var python_server_process: Process
#var server_started = false

func _ready():
	#start python server
	#start_python_server()
	# Make sure UI is set up first
	setup_ui()
	
	scroll_container.resized.connect(_resize_messages)
	
	# Then set up the rest
	setup_websocket()
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	var connection_timer = Timer.new()
	add_child(connection_timer)
	connection_timer.wait_time = 15.0
	connection_timer.timeout.connect(_on_connection_timer_timeout)
	connection_timer.start()
	
#func start_python_server():
	#var server_path = "C:/Users/Abdi/Documents/SWEG/iCogLabs_Work/godot-chatbot/server/app.py"
	#var command = "fastapi dev"  
	#var arguments = [server_path]  # Arguments should be an array containing the server script path
#
	## Execute the command with the correct arguments
	#var error_code = OS.execute(command, arguments, [], true)  # true to run in the background
	#if error_code != OK:
		#print("Failed to start the Python server. Error code: ", error_code)
	#else:
		#print("Python server started successfully.")

# Add a new function to handle message resizing
func _resize_messages():
	if not message_container or not scroll_container:
		return
	
	var container_width = scroll_container.size.x
	if container_width <= 0:
		return  # Avoid invalid or uninitialized sizes
	
	# Determine the target width for message bubbles as a percentage of the container width
	var target_width = container_width * 0.7  # Adjust percentage as needed (e.g., 70%)
	
	# Iterate over all children in the message container
	for child in message_container.get_children():
		if child is HBoxContainer:  # Process message rows only
			for subchild in child.get_children():
				if subchild is PanelContainer:  # Resize message bubbles
					if subchild.has_method("set_custom_minimum_size"):
						subchild.set_custom_minimum_size(Vector2(target_width, 0))



func setup_ui():
	# Main control settings
	anchor_right = 0.98
	anchor_bottom = 0.96
	
	setup_toggle_button()
	setup_chat_panel()
	chat_panel.hide()

func _on_fetch_documents_pressed():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var url = "http://localhost:8000/documents"  # Adjust this to your server's URL
	var error = http_request.request(url)
	
	if error != OK:
		print("Failed to send request: ", error)
		add_message("System", "Failed to fetch documents!", false)
	else:
		http_request.request_completed.connect(_on_documents_fetched)

func _on_documents_fetched(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error during fetch: ", result)
		add_message("System", "Failed to fetch documents!", false)
		return
	
	if response_code == 200:
		var json = JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		if error == OK:
			var response = json.get_data()
			var documents = response.get("documents", [])
			_populate_document_menu(documents)
		else:
			print("Failed to parse JSON response")
			add_message("System", "Failed to parse documents response!", false)
	else:
		print("Fetch failed with code: ", response_code)
		add_message("System", "Fetch failed with code: " + str(response_code), false)

func _populate_document_menu(documents: Array):
	var popup = fetch_documents_button.get_popup()
	popup.clear()  # Clear previous items
	
	# Add each document to the dropdown menu
	for doc in documents:
		popup.add_item(doc)
	
	# Show the dropdown menu
	popup.popup()

func setup_toggle_button():
	toggle_button = Button.new()
	toggle_button.text = "Chat"
	toggle_button.custom_minimum_size = Vector2(60, 60)
	toggle_button.anchor_left = 1
	toggle_button.anchor_top = 1
	toggle_button.anchor_right = 1
	toggle_button.anchor_bottom = 1
	toggle_button.position = Vector2(-80, -80)
	
	var toggle_style = StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.2, 0.7, 0.4)
	toggle_style.corner_radius_top_left = 30
	toggle_style.corner_radius_top_right = 30
	toggle_style.corner_radius_bottom_left = 30
	toggle_style.corner_radius_bottom_right = 30
	
	toggle_button.add_theme_stylebox_override("normal", toggle_style)
	toggle_button.pressed.connect(_on_toggle_chat)
	add_child(toggle_button)

func setup_chat_panel():
	chat_panel = PanelContainer.new()
	chat_panel.anchor_left = 0.5
	chat_panel.anchor_top = 0
	chat_panel.anchor_right = 1
	chat_panel.anchor_bottom = 1
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.14)
	panel_style.shadow_size = 4
	chat_panel.add_theme_stylebox_override("panel", panel_style)
	
	setup_chat_interface()
	add_child(chat_panel)

func setup_chat_interface():
	# Create margin container for padding
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	chat_panel.add_child(margin_container)
	
	# Main chat container
	chat_container = VBoxContainer.new()
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(chat_container)
	
	# Header with title and close button
	var header = HBoxContainer.new()
	chat_container.add_child(header)
	
	var title = Label.new()
	title.text = "Chat Assistant"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	#Button for displaying documents
	fetch_documents_button = MenuButton.new()
	fetch_documents_button.text = "Documents"
	fetch_documents_button.custom_minimum_size = Vector2(100, 0)  # Give it some minimum width
	var popup = fetch_documents_button.get_popup()
	fetch_documents_button.pressed.connect(_on_fetch_documents_pressed)
	
	# Style the documents button
	var docs_button_style = StyleBoxFlat.new()
	docs_button_style.bg_color = Color(0.2, 0.4, 0.8)  # Match your color scheme
	docs_button_style.corner_radius_top_left = 6
	docs_button_style.corner_radius_top_right = 6
	docs_button_style.corner_radius_bottom_left = 6
	docs_button_style.corner_radius_bottom_right = 6

	fetch_documents_button.add_theme_stylebox_override("normal", docs_button_style)

	header.add_child(fetch_documents_button)
	
	var close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_on_toggle_chat)
	header.add_child(close_button)
	
	# Input container with upload and chat input
	var input_container = HBoxContainer.new()
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
	
	upload_button.add_theme_stylebox_override("normal", upload_button_style)
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
	
	send_button.add_theme_stylebox_override("normal", send_button_style)
	input_container.add_child(send_button)
	
	# Spacing after input section
	var input_section_spacer = Control.new()
	input_section_spacer.custom_minimum_size.y = 15
	chat_container.add_child(input_section_spacer)
	
	# Chat output area
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
	
	# Scroll container for messages
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	
	# Message container
	message_container = VBoxContainer.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#message_container.custom_minimum_size = Vector2(200, 0)
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

func _on_toggle_chat():
	is_chat_open = !is_chat_open
	if is_chat_open:
		chat_panel.show()
		toggle_button.hide()
	else:
		chat_panel.hide()
		toggle_button.show()

func setup_websocket():
	websocket = WebSocketPeer.new()
	_attempt_connection()

func _attempt_connection():
	var err = websocket.connect_to_url(socket_url)
	if err != OK:
		print("Waiting to connect to WebSocket server: ", err)
		add_message("System", "Waiting to connect to server!", false)
	else:
		print("Attempting to connect to WebSocket server...")

func _on_connection_timer_timeout():
	if !connection_status:
		print("Attempting to reconnect...")
		_attempt_connection()

func _process(_delta):
	if websocket:
		websocket.poll()
		var state = websocket.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				if !connection_status:
					print("Connected to server!")
					connection_status = true
					add_message("System", "Connected to server!", false)
				
				while websocket.get_available_packet_count():
					var packet = websocket.get_packet()
					var message = packet.get_string_from_utf8()
					_handle_websocket_message(message)
			
			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
				if connection_status:
					print("Disconnected from server")
					connection_status = false
					add_message("System", "Disconnected from server!", false)

func _handle_websocket_message(message: String):
	print("Received message: ", message) # Debug logging
	
	# Try to parse as JSON
	var json = JSON.new()
	var error = json.parse(message)
	if error == OK:
		var response = json.get_data()
		if response is Dictionary:
			if response.has("answer"):
				# Handle structured response with metadata
				var answer_text = response.answer
				var metadata = response.get("metadata", [])
				add_message("Assistant", answer_text, false, metadata)
			else:
				# Handle different message types
				match response.get("type"):
					"chat":
						add_message("Assistant", response.get("message"), false)
					"error":
						print("Error from server: ", response.get("message"))
						add_message("System", "Error: " + response.get("message"), false)
					"chunk_received":
						print("Chunk received: ", response.get("message"))
						# Optionally handle chunk notifications
					"transfer_complete":
						print("Transfer complete: ", response.get("message"))
						# Optionally handle transfer completion
					_:
						# Default case for unknown message types
						add_message("Assistant", message, false)
	else:
		# Handle non-JSON messages
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
	#var left_margin = Control.new()
	#var right_margin = Control.new()
	#left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create message bubble
	var message_bubble = PanelContainer.new()
	#message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	#message_bubble.custom_minimum_size.x = 500  # Increased from 200 to 400
	#message_bubble.size_flags_stretch_ratio = 0.9  # This makes the bubble use up to 70% of available width
	
	message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_user else Control.SIZE_SHRINK_BEGIN
	# Set to use 70% of the container width
	message_bubble.custom_minimum_size.x = scroll_container.size.x * 0.7
	
	# Set the message bubble to take approximately half the container width
	#message_bubble.custom_minimum_size.x = scroll_container.size.x * 0.45  # 45% of container width
	
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
	text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	
	content.add_child(name_label)
	content.add_child(text_label)
	
	# Handle metadata if present
	if metadata != null and metadata.size() > 0:
		var metadata_container = VBoxContainer.new()
		metadata_container.add_theme_constant_override("separation", 4)
		
		var refs_label = Label.new()
		refs_label.text = "References:"
		refs_label.add_theme_font_size_override("font_size", 11)
		refs_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		metadata_container.add_child(refs_label)
		
		for ref in metadata:
			# Adjust document path to match the Godot project directory
			ref.document_path = "res://pdfs/" + ref.document_path.get_file()
			var ref_button = Button.new()
			var pdf_name = ref["document_path"].get_file()  # Extract file name from path
			ref_button.text = "• %s (Page %d)" % [pdf_name, ref["page_number"]]
			ref_button.flat = true
			ref_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			ref_button.add_theme_font_size_override("font_size", 10)
			ref_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
			ref_button.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 1.0))
			
			# Store reference data to pass to the callback
			var ref_data = {"path": ref["document_path"], "page": ref["page_number"]}
			ref_button.pressed.connect(_on_reference_clicked.bind(ref_data))
			
			metadata_container.add_child(ref_button)
		
		content.add_child(metadata_container)
	
	# Assemble the message
	content_margin.add_child(content)
	message_bubble.add_child(content_margin)
	
	# Add spacers for alignment
	#var left_spacer = Control.new()
	#var right_spacer = Control.new()
	#left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	print(is_user)
	
	# Create spacers for alignment
	var left_spacer = Control.new()
	var right_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add components to row in correct order based on sender
	if is_user:
		message_row.add_child(left_spacer)
		message_row.add_child(message_bubble)
		## Set alignment to the right
		#message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
		
		#message_row.alignment = BoxContainer.ALIGNMENT_END
		#message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	else:
		message_row.add_child(message_bubble)
		message_row.add_child(right_spacer)
		## Set alignment to the left
		#message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# For system/assistant messages (left-aligned)
		#message_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		#message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	#message_row.add_child(message_bubble)
	
	# Add to message container with spacing
	message_container.add_child(message_row)
	
	# Add spacing between messages
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	message_container.add_child(spacer)
	
	# Scroll to bottom after a short delay to ensure layout is complete
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	
func _on_reference_clicked(ref_data: Dictionary):
	# Extract path and page from ref_data
	var document_path = ref_data["path"]
	var page = ref_data["page"]
	
	# Get just the filename from the path
	var filename = document_path.get_file()
	print("filename: ", filename)
	
	# Construct the local path relative to the project's pdfs directory
	var local_path = ProjectSettings.globalize_path("res://pdfs/" + filename)
	print("local_path: ", local_path)
	
	# More detailed file existence check
	var file_check_path = "res://pdfs/" + filename
	if not FileAccess.file_exists(file_check_path):
		print("File not found in project directory: ", file_check_path)
		add_message("System", "Error: PDF file not found!", false)
		return
		
	# Try to open the file directly with the OS
	var error_code
	if OS.has_feature("windows"):
		print("Attempting to open on Windows...")
		# Try both methods
		var pdf_url = "file:///" + local_path.replace("\\", "/") + "#page=" + str(page)
		print("Opening PDF with URL: ", pdf_url)
		error_code = OS.shell_open(pdf_url)
		#error_code = OS.shell_open(local_path)
		if error_code != OK:
			print("shell_open failed with error: ", error_code)
			# Try alternative method
			error_code = OS.execute("cmd", ["/c", "start", "", local_path])
			print("cmd execute result: ", error_code)
	elif OS.has_feature("macos"):
		print("Attempting to open on macOS...")
		error_code = OS.execute("open", [local_path])
		print("open command result: ", error_code)
	elif OS.has_feature("linux"):
		print("Attempting to open on Linux...")
		error_code = OS.execute("xdg-open", [local_path])
		print("xdg-open command result: ", error_code)
	else:
		print("Unsupported platform")
		add_message("System", "Error: Unsupported platform for opening PDFs!", false)
		return
		
	if error_code != OK:
		print("Failed to open PDF. Error code: ", error_code)
		add_message("System", "Error: Failed to open PDF!", false)

		



#func _notification(what):
	#if what == NOTIFICATION_RESIZED:
		##_resize_messages()
		## Add null checks
		#if message_container != null and scroll_container != null:
			#for child in message_container.get_children():
				#if child is HBoxContainer:  # Message row
					#for subchild in child.get_children():
						#if subchild is PanelContainer:  # Message bubble
							## Make sure scroll_container has a valid size
							#if scroll_container.size.x > 0:
								#subchild.custom_minimum_size.x = scroll_container.size.x * 0.7
							#else:
								## Use a default size if scroll container size is not yet set
								#subchild.custom_minimum_size.x = 300  # Default width

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
