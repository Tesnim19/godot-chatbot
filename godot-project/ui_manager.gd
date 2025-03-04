extends Node

class_name UIManager

var chat_panel: PanelContainer
var chat_container: VBoxContainer
var message_container: VBoxContainer
var scroll_container: ScrollContainer
var chat_input: LineEdit
var send_button: Button
var upload_button: Button
var reconnect_button: Button
var tooltip_button: Button
var model_selection_button: Button
var fetch_documents_button: Button
var connection_indicator: ColorRect
var chat_header_indicator: ColorRect
var toggle_button: Button
var is_chat_open = false

signal message_sent(text: String)
signal upload_pressed
signal reconnect_pressed
signal tooltip_pressed
signal model_selected(model_name: String)

func setup_ui(parent_node: Control):
    setup_toggle_button(parent_node)
    setup_connection_indicator()
    setup_chat_panel()
    setup_chat_interface()
    chat_panel.hide()

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