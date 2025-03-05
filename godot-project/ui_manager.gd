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

# Signals
signal message_sent(text: String)
signal upload_pressed
signal reconnect_pressed
signal tooltip_pressed
signal model_selected(model_name: String)
signal fetch_documents_pressed
signal toggle_chat(is_open: bool)

func setup_ui(parent_node: Control):
	parent_node.anchor_right = 0.98
	parent_node.anchor_bottom = 0.96  
	setup_toggle_button()
	setup_connection_indicator()
	setup_chat_panel()
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
	connection_indicator = ColorRect.new()
	connection_indicator.size = Vector2(12, 12)
	connection_indicator.color = Color(0.8, 0.2, 0.2)  # Red by default
	
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.8, 0.2, 0.2)
	circle_style.corner_radius_top_left = 16
	circle_style.corner_radius_top_right = 16
	circle_style.corner_radius_bottom_left = 16
	circle_style.corner_radius_bottom_right = 16
	
	connection_indicator.add_theme_stylebox_override("panel", circle_style)
	connection_indicator.position = Vector2(-6, -6)
	toggle_button.add_child(connection_indicator)
	
	chat_header_indicator = ColorRect.new()
	chat_header_indicator.size = Vector2(12, 12)
	chat_header_indicator.custom_minimum_size = Vector2(12, 12)
	
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
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	chat_panel.add_child(margin_container)
	
	chat_container = VBoxContainer.new()
	chat_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(chat_container)
	
	setup_header()
	setup_input_section()
	setup_message_area()

func setup_header():
	var header = HBoxContainer.new()
	chat_container.add_child(header)
	
	var title_container = HBoxContainer.new()
	title_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_container)
	
	var title = Label.new()
	title.text = "Chat Assistant"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(title)
	
	setup_model_selection(header)
	setup_tooltip_button(header)
	setup_documents_button(header)
	
	var close_button = Button.new()
	close_button.text = "×"
	close_button.flat = true
	close_button.add_theme_font_size_override("font_size", 24)
	close_button.pressed.connect(_on_toggle_chat)
	header.add_child(close_button)

func setup_model_selection(header: HBoxContainer):
	model_selection_button = MenuButton.new()
	model_selection_button.text = "Models"
	model_selection_button.custom_minimum_size = Vector2(100, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.6, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	model_selection_button.add_theme_stylebox_override("normal", style)
	
	header.add_child(model_selection_button)

func setup_tooltip_button(header: HBoxContainer):
	tooltip_button = Button.new()
	
	var icon = Image.new()
	icon.load("res://bubble.png")
	icon.resize(30, 30, Image.INTERPOLATE_BILINEAR)
	var texture = ImageTexture.create_from_image(icon)
	
	tooltip_button.icon = texture
	tooltip_button.text = ""
	tooltip_button.pressed.connect(_on_tooltip_pressed)
	header.add_child(tooltip_button)

func setup_documents_button(header: HBoxContainer):
	fetch_documents_button = MenuButton.new()
	fetch_documents_button.text = "Documents"
	fetch_documents_button.custom_minimum_size = Vector2(100, 0)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	fetch_documents_button.add_theme_stylebox_override("normal", style)
	
	fetch_documents_button.pressed.connect(_on_fetch_documents_pressed)
	header.add_child(fetch_documents_button)

func setup_input_section():
	var input_container = HBoxContainer.new()
	input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_container.add_child(input_container)
	
	setup_upload_button(input_container)
	setup_reconnect_button(input_container)
	setup_chat_input(input_container)
	setup_send_button(input_container)

func setup_upload_button(container: HBoxContainer):
	upload_button = Button.new()
	upload_button.text = "Upload PDF"
	upload_button.custom_minimum_size = Vector2(110, 42)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	upload_button.add_theme_stylebox_override("normal", style)
	
	upload_button.pressed.connect(_on_upload_pressed)
	container.add_child(upload_button)

func setup_reconnect_button(container: HBoxContainer):
	reconnect_button = Button.new()
	reconnect_button.text = "Disconnect"
	reconnect_button.custom_minimum_size = Vector2(110, 42)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.1, 0.1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	reconnect_button.add_theme_stylebox_override("normal", style)
	
	reconnect_button.pressed.connect(_on_reconnect_pressed)
	container.add_child(reconnect_button)

func setup_chat_input(container: HBoxContainer):
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 12
	container.add_child(spacer)
	
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.placeholder_text = "Type your message..."
	chat_input.custom_minimum_size.y = 36
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.25)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	chat_input.add_theme_stylebox_override("normal", style)
	
	chat_input.text_submitted.connect(_on_message_sent)
	container.add_child(chat_input)
	
	spacer = Control.new()
	spacer.custom_minimum_size.x = 12
	container.add_child(spacer)

func setup_send_button(container: HBoxContainer):
	send_button = Button.new()
	send_button.text = "Send"
	send_button.custom_minimum_size = Vector2(85, 42)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.7, 0.4)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	send_button.add_theme_stylebox_override("normal", style)
	
	send_button.pressed.connect(_on_send_pressed)
	container.add_child(send_button)

func setup_message_area():
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 15
	chat_container.add_child(spacer)
	
	var output_container = PanelContainer.new()
	output_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.custom_minimum_size.y = 300
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	output_container.add_theme_stylebox_override("panel", style)
	
	chat_container.add_child(output_container)
	
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_container.add_child(scroll_container)
	
	var message_margin = MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 12)
	message_margin.add_theme_constant_override("margin_right", 12)
	message_margin.add_theme_constant_override("margin_top", 12)
	message_margin.add_theme_constant_override("margin_bottom", 12)
	message_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(message_margin)
	
	message_container = VBoxContainer.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_margin.add_child(message_container)

func update_connection_indicator(is_connected: bool):
	var color = Color(0.2, 0.8, 0.2) if is_connected else Color(0.8, 0.2, 0.2)
	
	if connection_indicator:
			connection_indicator.color = color
			var style = connection_indicator.get_theme_stylebox("panel")
			if style:
					style.bg_color = color
	
	if chat_header_indicator:
			chat_header_indicator.color = color
			var style = chat_header_indicator.get_theme_stylebox("panel")
			if style:
					style.bg_color = color

func add_message(sender: String, text: String, is_user: bool = false, metadata = null):
	var message_row = HBoxContainer.new()
	message_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var message_bubble = PanelContainer.new()
	message_bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if is_user else Control.SIZE_SHRINK_BEGIN
	
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.2, 0.7, 0.4) if is_user else Color(0.25, 0.25, 0.3)
	bubble_style.corner_radius_top_left = 15
	bubble_style.corner_radius_top_right = 15
	bubble_style.corner_radius_bottom_left = 15
	bubble_style.corner_radius_bottom_right = 15
	message_bubble.add_theme_stylebox_override("panel", bubble_style)
	
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	
	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content.add_child(sender_label)
	
	var message_label = RichTextLabel.new()
	message_label.text = text
	message_label.fit_content = true
	message_label.custom_minimum_size.x = 100
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(message_label)
	
	if metadata and metadata.has("references"):
			for ref in metadata["references"]:
					var ref_button = Button.new()
					ref_button.text = ref["title"]
					ref_button.pressed.connect(_on_reference_clicked.bind(ref))
					content.add_child(ref_button)
	
	message_bubble.add_child(content)
	message_row.add_child(message_bubble)
	message_container.add_child(message_row)
	
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func clear_messages():
	for child in message_container.get_children():
			child.queue_free()

func _on_toggle_chat():
	is_chat_open = !is_chat_open
	if is_chat_open:
			chat_panel.show()
			toggle_button.hide()
	else:
			chat_panel.hide()
			toggle_button.show()
	emit_signal("toggle_chat", is_chat_open)

func _on_send_pressed():
	if chat_input.text.strip_edges() != "":
			emit_signal("message_sent", chat_input.text)
			chat_input.text = ""

func _on_message_sent(text: String):
	emit_signal("message_sent", text)
	chat_input.text = ""

func _on_upload_pressed():
	emit_signal("upload_pressed")

func _on_reconnect_pressed():
	emit_signal("reconnect_pressed")

func _on_tooltip_pressed():
	emit_signal("tooltip_pressed")

func _on_fetch_documents_pressed():
	emit_signal("fetch_documents_pressed")

func _on_reference_clicked(ref: Dictionary):
	OS.shell_open(ref["path"])

func initialize_models():
	var popup = model_selection_button.get_popup()
	popup.clear()
	
	var models = ["gemini", "t5-base"]
	for i in range(models.size()):
			popup.add_item(models[i], i)
	
	if not popup.id_pressed.is_connected(_on_model_selected):
			popup.id_pressed.connect(_on_model_selected)

func _on_model_selected(id: int):
	var popup = model_selection_button.get_popup()
	var model_name = popup.get_item_text(id)
	emit_signal("model_selected", model_name)