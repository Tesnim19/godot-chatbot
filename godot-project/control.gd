extends Control

var chat_container: VBoxContainer
var chat_input: LineEdit
var send_button: Button
var upload_button: Button
var reconnect_button: Button
var tooltip_button: Button
var model_selection_button: Button
var websocket: WebSocketPeer
var socket_url = "ws://localhost:8000/ws"
var connection_status = false
var http_request: HTTPRequest
var message_container: VBoxContainer
var scroll_container: ScrollContainer
var fetch_documents_button: Button
var connection_indicator: ColorRect
var chat_header_indicator: ColorRect

# New UI elements
var chat_panel: PanelContainer
var toggle_button: Button
var is_chat_open = false


var server_process_id = -1
var disconnect = false
var document_map = {}

var viewport_container: SubViewportContainer
var viewport: SubViewport
var model_container: Node3D
var camera: Camera3D

func _ready():
	#start python server
	start_python_server()
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
	# Setup the 3D viewport system
	setup_3d_viewport()

# Creates all the necessary nodes for the 3D viewport
func setup_3d_viewport():
	# Create SubViewportContainer
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "ViewportContainer"
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	add_child(viewport_container)
	
	# Create SubViewport
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = Vector2i(800, 600)  # Default size, will be resized with container
	viewport.handle_input_locally = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport_container.add_child(viewport)
	
	# Create 3D world container
	model_container = Node3D.new()
	model_container.name = "ModelContainer"
	viewport.add_child(model_container)
	
	# Create camera
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 1.5, 4)
	camera.rotation_degrees = Vector3(-15, 0, 0)
	viewport.add_child(camera)
	
	# Setup initial lighting
	setup_lighting()

# Sets up basic lighting for the 3D scene
func setup_lighting():
	# Create a directional light
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight"
	dir_light.rotation_degrees = Vector3(-45, 45, 0)
	dir_light.light_energy = 1.2
	dir_light.shadow_enabled = true
	viewport.add_child(dir_light)
	
	# Create ambient lighting via WorldEnvironment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	
	# Add background and fog
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.3, 0.35)
	
	world_env.environment = env
	viewport.add_child(world_env)

func _exit():
	print("Trying to exit process")
	if server_process_id != -1:
		print("Stopping the server...")
		OS.kill(server_process_id)
		server_process_id = -1
		print("Server stopped.")

func start_python_server():
	var project_dir = ProjectSettings.globalize_path("res://")
	var server_dir = project_dir + "../server/"
	var server_file = server_dir + "app.py"

	if not FileAccess.file_exists(server_file):
		print("Server file doesn't exist")
		return

	var venv_dir = server_dir + ".venv"
	var args_create_venv = ["-m", "venv", venv_dir]
	var command_create_venv = "python"

	if OS.get_name() == "Windows":
		args_create_venv = ["-m", "venv", venv_dir.replace("/", "\\")]
		if OS.has_feature("standalone"):
			if OS.execute("py", ["--version"]) == 0:
				command_create_venv = "py"
			else:
				command_create_venv = "python"
	var output_create_venv = []
	var execute_code_create_venv = OS.execute(command_create_venv, args_create_venv, output_create_venv, true)

	print(execute_code_create_venv)
	print("Output creating venv: \n", "\n".join(output_create_venv))

	_execute_server_startup_command(server_dir)

func _execute_server_startup_command(server_dir):
	var args_fastapi = ["run", server_dir + "app.py"]
	var command_fastapi = ""

	if OS.get_name() == "Windows":
		command_fastapi = server_dir.replace("/", "\\") + ".venv\\Scripts\\fastapi"
	else:
		command_fastapi = server_dir + ".venv/bin/fastapi"

	server_process_id = OS.create_process(command_fastapi, args_fastapi)
	print("server id: ", server_process_id)
	
func setup_ui():
	# Main control settings
	anchor_right = 0.98
	anchor_bottom = 0.96
	
	setup_toggle_button()
	setup_connection_indicator()
	setup_chat_panel()
	chat_panel.hide()

# New function to create connection indicator
func setup_connection_indicator():
	# Create the indicator in the top-right corner of the toggle button
	connection_indicator = ColorRect.new()
	connection_indicator.size = Vector2(12, 12)
	connection_indicator.color = Color(0.8, 0.2, 0.2)  # Red by default
	
	# Create a circle shape using a StyleBoxFlat
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.8, 0.2, 0.2)
	circle_style.corner_radius_top_left = 16
	circle_style.corner_radius_top_right = 16
	circle_style.corner_radius_bottom_left = 16
	circle_style.corner_radius_bottom_right = 16
	
	# Apply the style
	connection_indicator.add_theme_stylebox_override("panel", circle_style)
	
	# Position it on the toggle button
	connection_indicator.position = Vector2(-6, -6)
	toggle_button.add_child(connection_indicator)
	
	# Also add an indicator in the chat panel header
	chat_header_indicator = ColorRect.new()
	chat_header_indicator.size = Vector2(12, 12)
	chat_header_indicator.custom_minimum_size = Vector2(12, 12)
	
	# Create and apply the same style
	var header_circle_style = StyleBoxFlat.new()
	header_circle_style.bg_color = Color(0.8, 0.2, 0.2)
	header_circle_style.corner_radius_top_left = 6
	header_circle_style.corner_radius_top_right = 6
	header_circle_style.corner_radius_bottom_left = 6
	header_circle_style.corner_radius_bottom_right = 6
	chat_header_indicator.add_theme_stylebox_override("panel", header_circle_style)

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

# Add handler for document button click to show popup
func _on_documents_button_pressed():
	# Remove any existing popup first
	var existing_popup = get_node_or_null("DocumentListPopup")
	if existing_popup:
		existing_popup.queue_free()
	
	# Fetch documents and show in popup
	_on_fetch_documents_pressed()

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
			var document_filenames = []
			for doc in documents:
				# Extract just the filename from the path
				var document_name = doc.get_file()
				document_filenames.append(document_name)
			_populate_document_menu(document_filenames)
		else:
			print("Failed to parse JSON response")
			add_message("System", "Failed to parse documents response!", false)
	else:
		print("Fetch failed with code: ", response_code)
		add_message("System", "Fetch failed with code: " + str(response_code), false)

func _populate_document_menu(documents: Array):
	var popup = fetch_documents_button.get_popup()
	popup.clear()  # Clear previous items
	document_map.clear()
	
	# Add each document as an item with a custom layout
	for i in range(documents.size()):
		var filename = documents[i]
		
		# Create the item ID for the document
		var doc_id = i
		
		# Add the document item with just the filename
		popup.add_item(filename, doc_id)
		document_map[doc_id] = filename
		
		# Add a delete option right next to it
		var delete_id = i + 1000  # Use a different range for delete actions
		popup.add_item("  🗑️ Delete", delete_id)  # Using trash icon emoji
		document_map[delete_id] = filename
		
		# Add a small separator if not the last item
		if i < documents.size() - 1:
			popup.add_separator()
	
	# Ensure the signal is connected only once
	if not popup.id_pressed.is_connected(_on_popup_item_selected):
		popup.id_pressed.connect(_on_popup_item_selected)
	
	# Show the dropdown menu
	popup.popup()

func _on_popup_item_selected(id):
	var filename = document_map[id]
	
	# Check if this is a document open or delete action
	if id >= 1000:  # Delete action
		_on_delete_document_pressed(filename)
	else:  # Open action
		var project_dir = ProjectSettings.globalize_path("res://")
		var file_dir = project_dir + "../server/public/" + filename
		_on_reference_clicked({'path': file_dir, 'page': 1})
		print("Opening: " + filename)

func _on_delete_document_pressed(document_name: String):
	print("Attempting to delete document:", document_name)
	
	# Create a confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Confirm Deletion"
	confirm_dialog.dialog_text = "Are you sure you want to delete " + document_name + "?"
	confirm_dialog.confirmed.connect(_delete_document_confirmed.bind(document_name))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

# Confirmation callback
func _delete_document_confirmed(document_name: String):
	print("Deletion confirmed for:", document_name)
	
	# Send delete request to server
	var http_request = HTTPRequest.new()
	add_child(http_request)
	var url = "http://localhost:8000/delete"
	
	# Create the request body
	var body = JSON.stringify({"document_name": document_name})
	var headers = ["Content-Type: application/json"]
	
	http_request.request_completed.connect(_on_document_deletion_response)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("Failed to send delete request:", error)
		add_message("System", "Failed to send delete request!", false)

# Handle server response to deletion
func _on_document_deletion_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("Delete response received:")
	print("Result:", result)
	print("Response code:", response_code)
	print("Headers:", headers)
	
	if body.size() > 0:
		var response_body = JSON.parse_string(body.get_string_from_utf8())
		print("Response body:", response_body)
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("Document deletion failed with code", response_code)
		add_message("System", "Failed to delete document! Server returned: " + str(response_code), false)
	else:
		print("Document deleted successfully")
		add_message("System", "Document deleted successfully!", false)
				# Refresh document list
		_on_fetch_documents_pressed()

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
	
	# Create a sub-container for the title and indicator to keep them together
	var title_container = HBoxContainer.new()
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_container)
	
	var title = Label.new()
	title.text = "Chat Assistant"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(title)
	
	# Model Selection Dropdown
	model_selection_button = MenuButton.new()
	model_selection_button.text = "Models"
	model_selection_button.custom_minimum_size = Vector2(100, 0)
	
	# Style the model selection button
	var model_button_style = StyleBoxFlat.new()
	model_button_style.bg_color = Color(0.3, 0.6, 0.9)  # Light blue
	model_button_style.corner_radius_top_left = 6
	model_button_style.corner_radius_top_right = 6
	model_button_style.corner_radius_bottom_left = 6
	model_button_style.corner_radius_bottom_right = 6
	model_selection_button.add_theme_stylebox_override("normal", model_button_style)
	header.add_child(model_selection_button)
	
	# Connect button press event - Fixed: Changed to proper function call
	model_selection_button.pressed.connect(self._initialize_models)

	# Button for displaying tooltip
	tooltip_button = Button.new()
	
	var tool_tip_icon = Image.new()
	tool_tip_icon.load("res://bubble.png")
	tool_tip_icon.resize(30, 30, Image.INTERPOLATE_BILINEAR)
	
	var texture = ImageTexture.create_from_image(tool_tip_icon)

	tooltip_button.icon = texture
	tooltip_button.text = ""
	header.add_child(tooltip_button)
	
	tooltip_button.pressed.connect(_on_tooltip_pressed)
	
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

	#Reconnect button
	reconnect_button = Button.new()
	reconnect_button.text = "Disconnect"
	reconnect_button.custom_minimum_size = Vector2(110, 42)
	reconnect_button.pressed.connect(_on_reconnect_pressed)

	var upload_button_style = StyleBoxFlat.new()
	upload_button_style.bg_color = Color(0.2, 0.4, 0.8) # Blue color
	upload_button_style.corner_radius_top_left = 6
	upload_button_style.corner_radius_top_right = 6
	upload_button_style.corner_radius_bottom_left = 6
	upload_button_style.corner_radius_bottom_right = 6

	upload_button.add_theme_stylebox_override("normal", upload_button_style)
	input_container.add_child(upload_button)

	var reconnect_button_style = StyleBoxFlat.new()
	reconnect_button_style.bg_color = Color(0.8, 0.1, 0.1) # Red color
	reconnect_button_style.corner_radius_top_left = 6
	reconnect_button_style.corner_radius_top_right = 6
	reconnect_button_style.corner_radius_bottom_left = 6
	reconnect_button_style.corner_radius_bottom_right = 6

	reconnect_button.add_theme_stylebox_override("normal", reconnect_button_style)
	input_container.add_child(reconnect_button)

	
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

# Initialize with hardcoded models instead of fetching from backend
func _initialize_models():
	var popup = model_selection_button.get_popup()
	popup.clear()
	
	# Add our hardcoded models
	var models = ["gemini", "t5-base"]
	
	for i in range(models.size()):
		var model = models[i]
		popup.add_item(model, i)
	
	# Connect the signal for model selection
	if not popup.id_pressed.is_connected(self._on_model_selected):
		popup.id_pressed.connect(self._on_model_selected)
	
	# Set default model
	model_selection_button.text = models[0]


# This function handles when a model is selected from the dropdown
func _on_model_selected(id):
	var popup = model_selection_button.get_popup()
	var model_name = popup.get_item_text(popup.get_item_index(id))
	
	# Show selection in progress
	var previous_text = model_selection_button.text
	model_selection_button.text = "Switching..."
	
	# Create HTTP request to change the model
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.add_to_group("model_change_request") # Add to group for easy reference later
	
	# Store the model name so we can reference it in the response handler
	http_request.set_meta("model_name", model_name)
	http_request.set_meta("previous_model", previous_text)
	http_request.request_completed.connect(self._on_model_change_completed)
	
	# Prepare the request
	var url = "http://localhost:8000/model"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"model_type": model_name})
	
	# Debug output
	print("Sending model change request: " + body)
	
	# Send the POST request to change the model
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("An error occurred in the HTTP request to change model.")
		model_selection_button.text = previous_text
		add_message("System", "Failed to switch model. Please try again later.", false)

# This function handles HTTP response for model change
func _on_model_change_completed(result, response_code, headers, body):
	print("Model change response received: Result=" + str(result) + ", Code=" + str(response_code))
	
	# Get the HTTP request node that triggered this callback
	var http_request = get_node("../HTTPRequest") # Try direct path first
	
	if http_request == null:
		# Try getting from the group if direct path failed
		if get_tree().get_nodes_in_group("model_change_request").size() > 0:
			http_request = get_tree().get_nodes_in_group("model_change_request")[0]
		else:
			push_error("HTTP request node not found")
			model_selection_button.text = "Models" # Default fallback
			return
	
	var model_name = http_request.get_meta("model_name")
	var previous_model = http_request.get_meta("previous_model")
	
	print("Model name from request: " + model_name)
	
	# Check if we got a valid response
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Parse response
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response_data = json.get_data()
			print("Response data: " + str(response_data))
			
			# Update the button text
			model_selection_button.text = model_name
			
			# Notify the user about the model change
			add_message("System", "Model switched to " + model_name, false)
		else:
			push_error("JSON parsing error")
			model_selection_button.text = previous_model
			add_message("System", "Failed to switch model: Invalid response format", false)
	else:
		# Handle error
		var error_message = "Unknown error"
		
		if body and body.get_string_from_utf8():
			var json = JSON.new()
			var parse_result = json.parse(body.get_string_from_utf8())
			
			if parse_result == OK:
				var response_data = json.get_data()
				if response_data.has("error"):
					error_message = response_data["error"]
		
		push_error("Model change failed: " + error_message)
		model_selection_button.text = previous_model
		add_message("System", "Failed to switch model: " + error_message, false)
	
	# Remove the HTTP request node
	http_request.queue_free()

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
	add_message("System", "Waiting to connect to server!", false)
	_attempt_connection()

func _attempt_connection():
	var err = websocket.connect_to_url(socket_url)
	if err != OK:
		print("Waiting to connect to WebSocket server: ", err)
	else:
		print("Attempting to connect to WebSocket server...")

func _disconnect():
	if WebSocketPeer.STATE_OPEN:
		websocket.close(1000,"Closing connection")

func _on_connection_timer_timeout():
	if !connection_status and disconnect == false:
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
					_update_connection_indicator(true)
				
				while websocket.get_available_packet_count():
					var packet = websocket.get_packet()
					var message = packet.get_string_from_utf8()
					_handle_websocket_message(message)
			
			WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED:
				if connection_status:
					print("Disconnected from server")
					connection_status = false
					add_message("System", "Disconnected from server!", false)
					_update_connection_indicator(false)
	
# New function to update the connection indicator
func _update_connection_indicator(is_connected: bool):
	# Update color based on connection status
	var color = Color(0.2, 0.8, 0.2) if is_connected else Color(0.8, 0.2, 0.2)  # Green or Red
	
	# Update toggle button indicator
	if connection_indicator:
		connection_indicator.color = color
		var style = connection_indicator.get_theme_stylebox("panel")
		if style:
			style.bg_color = color
	
	# Update chat header indicator
	if chat_header_indicator:
		chat_header_indicator.color = color
		var header_style = chat_header_indicator.get_theme_stylebox("panel")
		if header_style:
			header_style.bg_color = color

func _handle_websocket_message(message: String):
	print("Received message: ", message) # Debug logging
	
	# Try to parse as JSON
	var json = JSON.new()
	var error = json.parse(message)
	if error == OK:
		var data = json.get_data()
		if data is Dictionary:
			if data.has("type"):
				match data.get("type"):
					"answer":
						if data.has("response") and data.response is Dictionary:
							var answer_text = data.response.get("answer", "")
							var metadata = data.response.get("metadata", [])
							add_message("Assistant", answer_text, false, metadata)
						else:
							print("Malformed answer message format")
							add_message("System", "Error: Received malformed answer message", false)
					"generate":
						# Handle generate type messages for 3D models
						if data.has("response") and data.response is String:
							var model_path = data.response
							# Call your function to display the 3D model
							display_3d_model(model_path)
							add_message("System", "Generated 3D model: " + model_path.get_file(), false)
						else:
							print("Malformed generate message format")
							add_message("System", "Error: Received malformed generate message", false)

					"chat":
						# Handle basic chat messages
						if data.has("message"):
							add_message("Assistant", data.get("message"), false)
						else:
							add_message("Assistant", "Received chat message with no content", false)
					"error":
						print("Error from server: ", data.get("message"))
						add_message("System", "Error: " + data.get("message"), false)
					"chunk_received":
						print("Chunk received: ", data.get("message"))
						# Optionally handle chunk notifications
					"transfer_complete":
						print("Transfer complete: ", data.get("message"))
						# Optionally handle transfer completion
					_:
						# Default case for unknown message types
						add_message("Assistant", message, false)
	else:
		# Handle non-JSON messages
		add_message("Assistant", message, false)
		
func display_3d_model(model_path: String):
	print("Loading 3D model from path: ", model_path)
	pass

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

	# Add original_file_path as another form field
	var path_field = "\r\n--" + boundary + "\r\n"
	path_field += "Content-Disposition: form-data; name=\"original_file_path\"\r\n\r\n"
	path_field += path + "\r\n"
	body.append_array(path_field.to_utf8_buffer())
	
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
	
	
	# Create message bubble
	var message_bubble = PanelContainer.new()
	
	message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_user else Control.SIZE_SHRINK_BEGIN
	# Set to use 70% of the container width
	message_bubble.custom_minimum_size.x = scroll_container.size.x * 0.7
	
	
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
			var pdf_name = ref["document_path"].get_file()  # Extract file name from path
			var project_dir = ProjectSettings.globalize_path("res://")
			ref.document_path = project_dir + "../server/public/" + pdf_name
			var ref_button = Button.new()
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
	
	# Add timestamp
	var current_time = Time.get_datetime_dict_from_system()
	var timestamp_label = Label.new()
	timestamp_label.text = "%02d:%02d" % [current_time.hour, current_time.minute]
	timestamp_label.add_theme_font_size_override("font_size", 9)
	timestamp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_user else HORIZONTAL_ALIGNMENT_LEFT
	timestamp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add a small margin above the timestamp
	var timestamp_margin = MarginContainer.new()
	timestamp_margin.add_theme_constant_override("margin_top", 4)
	timestamp_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timestamp_margin.add_child(timestamp_label)
	
	content.add_child(timestamp_margin)
	
	# Assemble the message
	content_margin.add_child(content)
	message_bubble.add_child(content_margin)
	
	
	# Create spacers for alignment
	var left_spacer = Control.new()
	var right_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add components to row in correct order based on sender
	if is_user:
		message_row.add_child(left_spacer)
		message_row.add_child(message_bubble)
	else:
		message_row.add_child(message_bubble)
		message_row.add_child(right_spacer)
	
	
	# Add to message container with spacing
	message_container.add_child(message_row)
	
	# Add spacing between messages
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	message_container.add_child(spacer)
	
	# Scroll to bottom after a short delay to ensure layout is complete
	await get_tree().create_timer(0.1).timeout
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
	
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
	
func _on_reference_clicked(ref_data: Dictionary):
	var document_path = ref_data["path"]
	var page = ref_data.get("page", 1)
	page = max(1, page)  # Ensure minimum page is 1
	
	# Convert to absolute path
	var absolute_path = ProjectSettings.globalize_path(document_path)
	
	if !FileAccess.file_exists(absolute_path):
		add_message("System", "PDF file not found!", false)
		return

	var success = false
	
	if OS.has_feature("windows"):
		# Windows readers (priority order)
		var readers = [
			{
				"name": "Adobe Acrobat",
				"paths": [
					"C:\\Program Files (x86)\\Adobe\\Acrobat Reader DC\\Reader\\AcroRd32.exe",
					"C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\Acrobat.exe"
				],
				"args": ["/A", "page=%d" % page, absolute_path]
			},
			{
				"name": "SumatraPDF",
				"paths": [
					OS.get_environment("ProgramFiles") + "\\SumatraPDF\\SumatraPDF.exe",
					OS.get_environment("ProgramW6432") + "\\SumatraPDF\\SumatraPDF.exe"
				],
				"args": ["-page", str(page), absolute_path]
			},
			{
				"name": "Default Browser",
				"method": "url",
				"url": "file:///" + absolute_path.replace("\\", "/") + "#page=" + str(page)
			}
		]
		
		for reader in readers:
			if reader.has("method") && reader["method"] == "url":
				success = OS.shell_open(reader["url"]) == OK
				if success: break
				continue
				
			for exe_path in reader["paths"]:
				if FileAccess.file_exists(exe_path):
					var pid = OS.create_process(exe_path, reader["args"], false)
					if pid != 0:
						success = true
						break
			if success: break

	elif OS.has_feature("macos"):
		# macOS readers
		var readers = [
			{
				"name": "Adobe Acrobat",
				"path": "/Applications/Adobe Acrobat Reader DC.app/Contents/MacOS/AdobeReader",
				"args": [absolute_path, "--page=%d" % page]
			},
			{
				"name": "Preview",
				"script": """
				tell application "Preview" to open POSIX file "%s"
				delay 1
				tell application "System Events" to tell process "Preview"
					keystroke "g" using {command down, option down}
					delay 0.5
					keystroke "%d"
					keystroke return
				end tell
				""" % [absolute_path, page]
			},
			{
				"name": "Foxit Reader",
				"path": "/Applications/Foxit PDF Reader.app/Contents/MacOS/Foxit PDF Reader",
				"args": [absolute_path, "--page=%d" % page]
			}
		]
		
		for reader in readers:
			if reader.has("script"):
				var result = OS.execute("osascript", ["-e", reader["script"]])
				if result == 0:
					success = true
					break
			elif FileAccess.file_exists(reader["path"]):
				var pid = OS.create_process(reader["path"], reader["args"], false)
				if pid != 0:
					success = true
					break

	elif OS.has_feature("linux"):
		# Linux readers
		var readers = [
			{
				"name": "Evince",
				"cmd": "evince",
				"args": ["-p", str(page), absolute_path]
			},
			{
				"name": "Okular",
				"cmd": "okular",
				"args": ["-p", str(page), absolute_path]
			},
			{
				"name": "qpdfview",
				"cmd": "qpdfview",
				"args": ["--page", str(page), absolute_path]
			}
		]
		
		for reader in readers:
			var exit_code = OS.execute("which", [reader["cmd"]])
			if exit_code == 0:
				var pid = OS.create_process(reader["cmd"], reader["args"], false)
				if pid != 0:
					success = true
					break

	if !success:
		# Fallback to system default
		success = OS.shell_open(absolute_path) == OK

	if !success:
		add_message("System", "Failed to open PDF!", false)
	else:
		print("PDF opened successfully with page ", page)

func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		_exit()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit()

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

func _on_tooltip_pressed():
	var tip_popup = PopupPanel.new()
	
	# Set the background color of the popup (dark purple)
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color("5553b7")  # Darker purple
	popup_style.content_margin_left = 15
	popup_style.content_margin_right = 15
	popup_style.content_margin_top = 10
	popup_style.content_margin_bottom = 10
	tip_popup.add_theme_stylebox_override("panel", popup_style)


	# Create a VBoxContainer for the layout
	var content_container = VBoxContainer.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Allow expansion
	content_container.add_theme_constant_override("separation", 10)  # Add spacing
	tip_popup.add_child(content_container)

	# Add content to the popup (e.g., a tip Label)
	var tip_label = Label.new()
	tip_label.text = "Here are some useful tips!"
	tip_label.add_theme_color_override("font_color", Color(1, 1, 1))  # White text
	content_container.add_child(tip_label)
	
	# Spacer to push buttons to the bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(spacer)

	# Create an HBoxContainer for buttons
	var button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Make it expand horizontally
	content_container.add_child(button_container)

	# Create the "Back" button and position it at the bottom left
	var back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(60, 20)  # Set a proper size
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button_container.add_child(back_button)  # Add to button container
	
	# Add a spacer to push "Next" button to the right
	var button_spacer = Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_container.add_child(button_spacer)

	# Create the "Next" button and position it at the bottom right
	var next_button = Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(60, 20)  # Set a proper size
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_END  # Align right
	
	var next_button_style = StyleBoxFlat.new()
	next_button_style.bg_color = Color("a88532")  # Yellowish color
	next_button.add_theme_stylebox_override("normal", next_button_style)
	
	button_container.add_child(next_button)  # Add to button container

	# Add the popup to the scene
	add_child(tip_popup)

	# Position the popup relative to the tooltip_button
	var button_position = tooltip_button.global_position
	var offset = Vector2(tooltip_button.custom_minimum_size.x - 100, 50)  # Adjust the X offset as needed
	tip_popup.popup(Rect2i(button_position + offset, Vector2i(200, 120)))  # Increased height for button space

func _on_reconnect_pressed():
	if connection_status == false:
		websocket.connect_to_url(socket_url)
		disconnect = false
		reconnect_button.text = 'Disconnect'
	else:
		_disconnect()
		disconnect = true
		reconnect_button.text = 'Reconnect'

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
