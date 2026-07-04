extends Control

## MainMenu — vibrant neon interface with New Game, Settings, Load, Exit.

signal new_game_selected(world_size: int)
signal load_game_selected()
signal settings_opened()
signal exit_requested()

@export var font_size_title: int = 64
@export var font_size_button: int = 28

var _vbox: VBoxContainer
var _title: Label
var _size_selector: HBoxContainer
var _selected_size: int = 1
var _size_buttons: Array = []
var _settings_panel: Control
var _loading_label: Label

func _ready() -> void:
	_setup_ui()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Neon border effect
	var border = PanelContainer.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = Color(0.0, 0.5, 1.0, 0.3)
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border.add_theme_stylebox_override("panel", border_style)
	add_child(border)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_vbox = VBoxContainer.new()
	_vbox.name = "MenuVBox"
	_vbox.add_theme_constant_override("separation", 20)
	center.add_child(_vbox)

	# Title
	_title = Label.new()
	_title.name = "Title"
	_title.text = "MATVGTA"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", font_size_title)
	_title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	_vbox.add_child(_title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Neon City Simulator"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.3, 0.8))
	_vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	_vbox.add_child(spacer)

	# World size selector
	_size_selector = HBoxContainer.new()
	_size_selector.name = "SizeSelector"
	_size_selector.add_theme_constant_override("separation", 10)
	_size_selector.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(_size_selector)

	var size_label = Label.new()
	size_label.text = "World Size:"
	size_label.add_theme_font_size_override("font_size", font_size_button - 4)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_size_selector.add_child(size_label)

	var sizes = ["Small", "Medium", "Large", "XL", "Giant"]
	for i in range(sizes.size()):
		var btn = Button.new()
		btn.text = sizes[i]
		btn.toggle_mode = true
		if i == 0:
			btn.button_group = ButtonGroup.new()
		else:
			btn.button_group = _size_buttons[0].button_group
		btn.button_pressed = (i == _selected_size)
		btn.custom_minimum_size = Vector2(100, 40)
		_apply_button_style(btn)
		btn.pressed.connect(_on_size_selected.bind(i))
		_size_selector.add_child(btn)
		_size_buttons.append(btn)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 20
	_vbox.add_child(spacer2)

	# Buttons
	_add_menu_button("NEW GAME", func(): new_game_selected.emit(_selected_size))
	_add_menu_button("LOAD GAME", func(): load_game_selected.emit())
	_add_menu_button("SETTINGS", func(): _toggle_settings())
	_add_menu_button("EXIT", func(): exit_requested.emit())

	# Loading label (hidden)
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.text = "Generating world..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", font_size_button)
	_loading_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	_loading_label.visible = false
	_vbox.add_child(_loading_label)

	# Settings panel (hidden)
	_setup_settings_panel()

func _add_menu_button(text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	_apply_button_style(btn)
	btn.pressed.connect(callback)
	_vbox.add_child(btn)

func _apply_button_style(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.12, 0.8)
	style.border_color = Color(0.0, 0.5, 1.0, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.0, 0.15, 0.35, 0.9)
	hover.border_color = Color(0.0, 0.7, 1.0, 0.8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = style.duplicate()
	pressed.bg_color = Color(0.0, 0.2, 0.5, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", font_size_button)
	btn.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

func _on_size_selected(idx: int) -> void:
	_selected_size = idx
	for i in range(_size_buttons.size()):
		_size_buttons[i].button_pressed = (i == idx)

func _setup_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	add_child(_settings_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.04, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_panel.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	vbox.add_child(title)

	# Graphics preset
	var gfx_label = Label.new()
	gfx_label.text = "Graphics Quality"
	gfx_label.add_theme_font_size_override("font_size", font_size_button - 4)
	gfx_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(gfx_label)

	var gfx_hbox = HBoxContainer.new()
	gfx_hbox.add_theme_constant_override("separation", 8)
	gfx_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(gfx_hbox)

	var presets = ["Potato", "Low", "Medium", "High", "Ultra"]
	for i in range(presets.size()):
		var btn = Button.new()
		btn.text = presets[i]
		btn.custom_minimum_size = Vector2(120, 35)
		_apply_button_style(btn)
		btn.pressed.connect(_on_preset_selected.bind(i))
		gfx_hbox.add_child(btn)

	# FSR 2.2 section
	var fsr_label = Label.new()
	fsr_label.text = "AMD FSR 2.2"
	fsr_label.add_theme_font_size_override("font_size", font_size_button - 4)
	fsr_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(fsr_label)

	var fsr_hbox = HBoxContainer.new()
	fsr_hbox.add_theme_constant_override("separation", 8)
	fsr_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(fsr_hbox)

	var fsr_modes = ["Off", "Ultra Quality", "Quality", "Balanced", "Performance"]
	for i in range(fsr_modes.size()):
		var btn = Button.new()
		btn.text = fsr_modes[i]
		btn.custom_minimum_size = Vector2(140, 35)
		_apply_button_style(btn)
		btn.pressed.connect(_on_fsr_selected.bind(i))
		fsr_hbox.add_child(btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(200, 45)
	_apply_button_style(back_btn)
	back_btn.pressed.connect(func(): _settings_panel.visible = false)
	vbox.add_child(back_btn)

func _toggle_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible

func _on_preset_selected(idx: int) -> void:
	SettingsManager.apply_preset(idx)

func _on_fsr_selected(idx: int) -> void:
	var modes = [
		SettingsManager.FSRMode.OFF,
		SettingsManager.FSRMode.ULTRA_QUALITY,
		SettingsManager.FSRMode.QUALITY,
		SettingsManager.FSRMode.BALANCED,
		SettingsManager.FSRMode.PERFORMANCE,
	]
	SettingsManager.set_fsr(idx != 0, modes[idx])

func show_loading() -> void:
	_loading_label.visible = true
	_vbox.visible = false

func hide_loading() -> void:
	_loading_label.visible = false
	_vbox.visible = true
