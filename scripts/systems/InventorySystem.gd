extends Control

## InventorySystem — tab-menu displaying item grid, loot value, equipped gadgets.

signal inventory_opened()
signal inventory_closed()

@export var max_slots: int = 40
@export var max_equipped: int = 3

var _inventory: Array = []
var _equipped: Array = []
var _money: int = 0
var _is_open: bool = false

var _panel: PanelContainer
var _grid: GridContainer
var _value_label: Label
var _money_label: Label
var _equipped_container: HBoxContainer
var _item_info: VBoxContainer

func _ready() -> void:
	_setup_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_ui() -> void:
	# Full screen overlay
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.01, 0.04, 0.92)
	style.border_color = Color(0.0, 0.5, 1.0, 0.4)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	_panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 30)
	margin.add_child(hbox)

	# Left: Grid + Value
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 15)
	hbox.add_child(left_vbox)

	# Title
	var title = Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	left_vbox.add_child(title)

	# Money
	_money_label = Label.new()
	_money_label.text = "Cash: $0"
	_money_label.add_theme_font_size_override("font_size", 20)
	_money_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	left_vbox.add_child(_money_label)

	# Grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	# Total value
	_value_label = Label.new()
	_value_label.text = "Total Value: $0"
	_value_label.add_theme_font_size_override("font_size", 16)
	_value_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	left_vbox.add_child(_value_label)

	# Right: Equipped + Item Info
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size.x = 300
	right_vbox.add_theme_constant_override("separation", 15)
	hbox.add_child(right_vbox)

	var equip_title = Label.new()
	equip_title.text = "EQUIPPED"
	equip_title.add_theme_font_size_override("font_size", 24)
	equip_title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	right_vbox.add_child(equip_title)

	_equipped_container = HBoxContainer.new()
	_equipped_container.add_theme_constant_override("separation", 10)
	right_vbox.add_child(_equipped_container)

	var info_title = Label.new()
	info_title.text = "ITEM INFO"
	info_title.add_theme_font_size_override("font_size", 24)
	info_title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	right_vbox.add_child(info_title)

	_item_info = VBoxContainer.new()
	_item_info.add_theme_constant_override("separation", 8)
	right_vbox.add_child(_item_info)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and _is_open:
		close()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	_is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_grid()
	_refresh_equipped()
	inventory_opened.emit()

func close() -> void:
	_is_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory_closed.emit()

func add_item(item: Dictionary) -> bool:
	if _inventory.size() >= max_slots:
		return false
	_inventory.append(item)
	_refresh_grid()
	return true

func remove_item(item_name: String) -> bool:
	for i in range(_inventory.size()):
		if _inventory[i].get("name", "") == item_name:
			_inventory.remove_at(i)
			_refresh_grid()
			return true
	return false

func get_items() -> Array:
	return _inventory

func add_money(amount: int) -> void:
	_money += amount
	_money_label.text = "Cash: $%d" % _money

func spend_money(amount: int) -> bool:
	if _money >= amount:
		_money -= amount
		_money_label.text = "Cash: $%d" % _money
		return true
	return false

func get_money() -> int:
	return _money

func equip_item(item: Dictionary) -> bool:
	if _equipped.size() >= max_equipped:
		return false
	_equipped.append(item)
	remove_item(item.get("name", ""))
	_refresh_equipped()
	_refresh_grid()
	return true

func unequip_item(idx: int) -> void:
	if idx >= 0 and idx < _equipped.size():
		var item = _equipped[idx]
		_equipped.remove_at(idx)
		add_item(item)
		_refresh_equipped()

func get_total_value() -> int:
	var total = 0
	for item in _inventory:
		total += item.get("value", 0)
	return total

func _refresh_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	for i in range(max_slots):
		var slot = _create_slot()
		if i < _inventory.size():
			var item = _inventory[i]
			_fill_slot(slot, item)
		_grid.add_child(slot)

	_value_label.text = "Total Value: $%d" % get_total_value()

func _create_slot() -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(50, 50)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.8)
	style.border_color = Color(0.0, 0.3, 0.6, 0.4)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", style)
	return slot

func _fill_slot(slot: PanelContainer, item: Dictionary) -> void:
	var label = Label.new()
	label.text = item.get("name", "?").substr(0, 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)

	var rarity = item.get("rarity", 0)
	match rarity:
		0: label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		1: label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		2: label.add_theme_color_override("font_color", Color(0.2, 0.5, 1.0))
		3: label.add_theme_color_override("font_color", Color(0.7, 0.2, 1.0))
		4: label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))

	slot.add_child(label)

func _refresh_equipped() -> void:
	for child in _equipped_container.get_children():
		child.queue_free()

	for i in range(max_equipped):
		var slot = _create_slot()
		slot.custom_minimum_size = Vector2(70, 70)
		if i < _equipped.size():
			_fill_slot(slot, _equipped[i])
		_equipped_container.add_child(slot)
