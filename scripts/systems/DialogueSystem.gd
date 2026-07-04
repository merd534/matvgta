extends Control

## DialogueSystem — branching dialogue UI with skill checks.
## Supports: bribery, deception, charisma checks, fake ID checks.

signal dialogue_started(npc_name: String)
signal dialogue_ended(npc_name: String)
signal choice_made(choice_id: String)
signal dialogue_action(action: String, params: Dictionary)

@export var font_size: int = 20
@export var typing_speed: float = 0.03

var _dialogue_data: Dictionary = {}
var _current_npc: String = ""
var _current_node: String = ""
var _is_active: bool = false
var _player_inventory: Array = []
var _player_money: int = 0
var _charisma: int = 5

# UI nodes
var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _choices_container: VBoxContainer
var _typing_timer: Timer
var _full_text: String = ""
var _char_index: int = 0

func _ready() -> void:
	_setup_ui()
	visible = false

func _setup_ui() -> void:
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 0.7
	_panel.anchor_bottom = 0.98
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.06, 0.92)
	style.border_color = Color(0.0, 0.6, 1.0, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	_panel.add_child(vbox)

	# NPC name
	_name_label = Label.new()
	_name_label.name = "NPCName"
	_name_label.add_theme_font_size_override("font_size", font_size + 4)
	_name_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	vbox.add_child(_name_label)

	# Dialogue text
	_text_label = RichTextLabel.new()
	_text_label.name = "DialogueText"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", font_size)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(_text_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)

	# Choices container
	_choices_container = VBoxContainer.new()
	_choices_container.name = "Choices"
	vbox.add_child(_choices_container)

	# Typing timer
	_typing_timer = Timer.new()
	_typing_timer.wait_time = typing_speed
	_typing_timer.one_shot = false
	_typing_timer.timeout.connect(_on_typing_tick)
	add_child(_typing_timer)

	process_mode = Node.PROCESS_MODE_ALWAYS

func start_dialogue(npc_name: String, dialogue_tree: Dictionary) -> void:
	_current_npc = npc_name
	_dialogue_data = dialogue_tree
	_current_node = dialogue_tree.get("start", "greeting")
	_is_active = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialogue_started.emit(npc_name)
	_show_node(_current_node)

func _show_node(node_id: String) -> void:
	if not _dialogue_data.has("nodes"):
		return

	var node = _dialogue_data["nodes"].get(node_id, {})
	if node.is_empty():
		end_dialogue()
		return

	_current_node = node_id
	_name_label.text = _current_npc

	# Check for skill checks
	var text = node.get("text", "")
	text = _evaluate_conditions(text, node.get("conditions", {}))
	_typewriter_text(text)

	# Build choices
	_build_choices(node.get("choices", []))

func _evaluate_conditions(text: String, conditions: Dictionary) -> String:
	# Replace placeholders
	text = text.replace("{player_name}", "Player")
	text = text.replace("{money}", str(_player_money))

	# Check conditions
	for condition in conditions:
		match condition:
			"has_item":
				var item = conditions[condition]
				if not _has_item(item):
					text += "\n[i](Requires: %s)[/i]" % item
			"charisma":
				var required = conditions[condition]
				if _charisma < required:
					text += "\n[i](Requires Charisma %d)[/i]" % required
			"has_money":
				text += "\n[i](You have: $%d)[/i]" % _player_money
	return text

func _typewriter_text(text: String) -> void:
	_full_text = text
	_char_index = 0
	_text_label.text = ""
	_typing_timer.start()

func _on_typing_tick() -> void:
	if _char_index < _full_text.length():
		_char_index += 1
		_text_label.text = _full_text.substr(0, _char_index)
	else:
		_typing_timer.stop()

func skip_typewriter() -> void:
	_typing_timer.stop()
	_text_label.text = _full_text
	_char_index = _full_text.length()

func _build_choices(choices: Array) -> void:
	# Clear old choices
	for child in _choices_container.get_children():
		child.queue_free()

	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.name = "Choice_%d" % i
		btn.text = _format_choice(choice)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Style
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.05, 0.1, 0.2, 0.6)
		btn_style.border_color = Color(0.0, 0.4, 0.8, 0.4)
		btn_style.border_width_left = 1
		btn_style.border_width_right = 1
		btn_style.border_width_top = 1
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_left = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.content_margin_left = 10
		btn_style.content_margin_right = 10
		btn_style.content_margin_top = 6
		btn_style.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", btn_style)

		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.0, 0.2, 0.5, 0.8)
		hover_style.border_color = Color(0.0, 0.6, 1.0, 0.8)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.add_theme_font_size_override("font_size", font_size)

		# Check availability
		var available = _check_choice_available(choice)
		btn.disabled = not available
		if not available:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

		btn.pressed.connect(_on_choice_pressed.bind(choice))
		_choices_container.add_child(btn)

func _format_choice(choice: Dictionary) -> String:
	var text = choice.get("text", "...")
	var cost = choice.get("cost", 0)
	var skill = choice.get("skill_check", "")

	var prefix = ""
	if cost > 0:
		prefix += "[$%d] " % cost
	if skill != "":
		prefix += "[%s] " % skill

	return prefix + text

func _check_choice_available(choice: Dictionary) -> bool:
	# Money check
	var cost = choice.get("cost", 0)
	if cost > 0 and _player_money < cost:
		return false

	# Item check
	var requires_item = choice.get("requires_item", "")
	if requires_item != "" and not _has_item(requires_item):
		return false

	# Skill check
	var skill = choice.get("skill_check", "")
	var skill_req = choice.get("skill_required", 0)
	if skill != "" and _get_skill_value(skill) < skill_req:
		return false

	return true

func _on_choice_pressed(choice: Dictionary) -> void:
	# Deduct money
	var cost = choice.get("cost", 0)
	if cost > 0:
		_player_money -= cost

	# Give items
	var gives = choice.get("gives", [])
	for item in gives:
		_player_inventory.append(item)

	# Execute action
	var action = choice.get("action", "")
	if action != "":
		dialogue_action.emit(action, choice.get("action_params", {}))

	choice_made.emit(choice.get("id", ""))

	# Go to next node
	var next = choice.get("next", "")
	if next == "":
		end_dialogue()
	else:
		_show_node(next)

func end_dialogue() -> void:
	_is_active = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialogue_ended.emit(_current_npc)

func set_player_data(money: int, inventory: Array, charisma: int) -> void:
	_player_money = money
	_player_inventory = inventory
	_charisma = charisma

func _has_item(item_name: String) -> bool:
	for item in _player_inventory:
		if item is Dictionary and item.get("name", "") == item_name:
			return true
		elif item is String and item == item_name:
			return true
	return false

func _get_skill_value(skill: String) -> int:
	match skill:
		"charisma": return _charisma
		"hacking": return 3  # placeholder
		"strength": return 2  # placeholder
	return 0

func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("interact"):
		if _char_index < _full_text.length():
			skip_typewriter()
	elif event.is_action_pressed("ui_cancel"):
		end_dialogue()
