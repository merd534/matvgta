extends Control

## PlayerHUD — modern cyberpunk HUD with custom-drawn icons.

@export var player: NodePath
@export var police_director: NodePath

var _player: Node3D
var _director: Node3D
var _health_bar: ProgressBar
var _stamina_bar: ProgressBar
var _stealth_bar: ProgressBar
var _wallet_label: Label
var _noise_label: Label
var _noise_dot: ColorRect
var _notification: Label
var _notification_timer: float = 0.0
var _crosshair: ColorRect

func _ready() -> void:
	_setup_ui()
	_player = get_node(player) as Node3D if player else null
	_director = get_node(police_director) as Node3D if police_director else null

func _setup_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Crosshair
	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.6)
	_crosshair.custom_minimum_size = Vector2(2, 2)
	_crosshair.anchors_preset = Control.PRESET_CENTER
	_crosshair.offset_left = -1
	_crosshair.offset_right = 1
	_crosshair.offset_top = -1
	_crosshair.offset_bottom = 1
	add_child(_crosshair)

	# Bottom-left panel
	var panel = _panel(Vector2(16, 920), Vector2(320, 140))
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(12, 10)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Health bar with heart icon
	_health_bar = _make_bar(_icon_heart(), Color(1.0, 0.15, 0.15), vbox)
	# Stamina bar with bolt icon
	_stamina_bar = _make_bar(_icon_bolt(), Color(0.0, 0.7, 1.0), vbox)
	# Stealth bar with eye icon
	_stealth_bar = _make_bar(_icon_eye(), Color(0.0, 1.0, 0.5), vbox)

	# Bottom center panel
	var bottom = _panel(Vector2(810, 950), Vector2(300, 80))
	add_child(bottom)

	_wallet_label = Label.new()
	_wallet_label.text = "$0"
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wallet_label.add_theme_font_size_override("font_size", 32)
	_wallet_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	bottom.add_child(_wallet_label)

	var noise_row = HBoxContainer.new()
	noise_row.position = Vector2(10, 50)
	noise_row.add_theme_constant_override("separation", 8)
	bottom.add_child(noise_row)

	_noise_dot = ColorRect.new()
	_noise_dot.custom_minimum_size = Vector2(10, 10)
	_noise_dot.color = Color(0.3, 0.3, 0.3)
	noise_row.add_child(_noise_dot)

	_noise_label = Label.new()
	_noise_label.text = "SILENT"
	_noise_label.add_theme_font_size_override("font_size", 14)
	_noise_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	noise_row.add_child(_noise_label)

	# Notification
	_notification = Label.new()
	_notification.anchor_left = 0.15
	_notification.anchor_right = 0.85
	_notification.anchor_top = 0.08
	_notification.anchor_bottom = 0.15
	_notification.offset_left = 0
	_notification.offset_right = 0
	_notification.offset_top = 0
	_notification.offset_bottom = 0
	_notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notification.add_theme_font_size_override("font_size", 28)
	_notification.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	_notification.visible = false
	add_child(_notification)

# ── Icon generators ──

func _icon_heart() -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Simple heart shape
	var heart = [
		[0,0,1,1,0,0,1,1,0,0],
		[0,1,1,1,1,1,1,1,1,0],
		[1,1,1,1,1,1,1,1,1,1],
		[1,1,1,1,1,1,1,1,1,1],
		[1,1,1,1,1,1,1,1,1,1],
		[0,1,1,1,1,1,1,1,1,0],
		[0,0,1,1,1,1,1,1,0,0],
		[0,0,0,1,1,1,1,0,0,0],
		[0,0,0,0,1,1,0,0,0,0],
	]
	for y in range(heart.size()):
		for x in range(heart[y].size()):
			if heart[y][x]:
				img.set_pixel(x + 3, y + 3, Color(1, 0.2, 0.2))
	return ImageTexture.create_from_image(img)

func _icon_bolt() -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bolt = [
		[0,0,0,0,0,1,1,0],
		[0,0,0,0,1,1,0,0],
		[0,0,0,1,1,0,0,0],
		[0,0,1,1,1,1,1,0],
		[0,0,0,0,1,1,0,0],
		[0,0,0,1,1,0,0,0],
		[0,0,1,1,0,0,0,0],
		[0,1,1,0,0,0,0,0],
	]
	for y in range(bolt.size()):
		for x in range(bolt[y].size()):
			if bolt[y][x]:
				img.set_pixel(x + 4, y + 4, Color(1, 0.8, 0.0))
	return ImageTexture.create_from_image(img)

func _icon_eye() -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Eye outline
	for x in range(1, 15):
		img.set_pixel(x, 7, Color(0, 1, 0.5))
		img.set_pixel(x, 8, Color(0, 1, 0.5))
	# Eye corners
	img.set_pixel(0, 7, Color(0, 1, 0.5))
	img.set_pixel(15, 7, Color(0, 1, 0.5))
	# Pupil
	for x in range(6, 10):
		for y in range(5, 11):
			img.set_pixel(x, y, Color(0, 1, 0.5))
	# Pupil center
	for x in range(7, 9):
		for y in range(7, 9):
			img.set_pixel(x, y, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)

# ── Helpers ──

func _panel(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p = PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = sz
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.06, 0.75)
	s.border_color = Color(0.0, 0.4, 0.8, 0.4)
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	return p

func _make_bar(icon_tex: Texture2D, color: Color, parent: Control) -> ProgressBar:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var icon = TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(16, 16)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(240, 18)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)

	row.add_child(bar)
	return bar

func _process(delta: float) -> void:
	_update_bars()
	_update_labels()
	if _notification.visible:
		_notification_timer -= delta
		if _notification_timer <= 0:
			_notification.visible = false

func _update_bars() -> void:
	if not _player:
		return
	_health_bar.value = 100
	_stamina_bar.value = 100
	if _player.has_node("StealthSystem"):
		var s = _player.get_node("StealthSystem")
		if "current_visibility" in s:
			_stealth_bar.value = s.current_visibility * 100

func _update_labels() -> void:
	if not _player:
		return
	if _player.has_node("NoiseSystem"):
		var n = _player.get_node("NoiseSystem")
		if "get_noise_level" in n:
			var level = n.get_noise_level()
			_noise_label.text = level
			match level:
				"SILENT":
					_noise_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
					_noise_dot.color = Color(0.2, 0.2, 0.2)
				"QUIET":
					_noise_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
					_noise_dot.color = Color(0.4, 0.4, 0.4)
				"LOUD":
					_noise_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
					_noise_dot.color = Color(1.0, 0.5, 0.0)
				"VERY_LOUD":
					_noise_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
					_noise_dot.color = Color(1.0, 0.1, 0.1)

func update_wallet(amount: int) -> void:
	_wallet_label.text = "$%d" % amount

func show_notification(text: String, duration: float = 3.0) -> void:
	_notification.text = text
	_notification.visible = true
	_notification_timer = duration

func show_interact_prompt(_text: String) -> void:
	pass

func hide_interact_prompt() -> void:
	pass
