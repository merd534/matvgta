extends Node3D

## MainMenu3D — 3D city skyline background. 2D UI overlay via CanvasLayer.

signal new_game_selected(world_size: int)
signal load_game_selected()
signal exit_requested()

var _cam: Camera3D
var _ui_layer: CanvasLayer
var _main_ui: Control
var _loading_ui: Control
var _settings_ui: Control
var _selected_size: int = 1

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_3d_background()
	_build_ui()

func _build_3d_background() -> void:
	_cam = Camera3D.new()
	_cam.name = "MenuCamera"
	_cam.fov = 55
	_cam.position = Vector3(0, 5, 16)
	add_child(_cam)
	_cam.look_at(Vector3(0, 2, 0))

	# Ground
	var g = MeshInstance3D.new()
	g.mesh = PlaneMesh.new()
	g.mesh.size = Vector2(80, 80)
	g.position.y = -2
	var gm = StandardMaterial3D.new()
	gm.albedo_color = Color(0.02, 0.02, 0.05)
	g.mesh.material = gm
	add_child(g)

	# Buildings
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(40):
		var h = rng.randf_range(4.0, 18.0)
		var w = rng.randf_range(1.5, 4.0)
		var d = rng.randf_range(1.5, 4.0)
		var x = rng.randf_range(-35.0, 35.0)
		var z = rng.randf_range(-25.0, -3.0)
		var bldg = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(w, h, d)
		bldg.mesh = box
		bldg.position = Vector3(x, h / 2 - 2, z)
		var bm = StandardMaterial3D.new()
		var br = rng.randf_range(0.01, 0.04)
		bm.albedo_color = Color(br, br, br + 0.02)
		bm.emission_enabled = true
		bm.emission = Color(rng.randf_range(0, 0.1), rng.randf_range(0, 0.1), rng.randf_range(0.05, 0.2))
		bm.emission_energy_multiplier = rng.randf_range(0.3, 1.0)
		bldg.mesh.material = bm
		add_child(bldg)

		# Windows
		for row in range(int(h / 1.2)):
			for col in range(int(w / 0.8)):
				if rng.randf() > 0.4:
					var wl = MeshInstance3D.new()
					var ws = BoxMesh.new()
					ws.size = Vector3(0.25, 0.12, 0.05)
					wl.mesh = ws
					wl.position = bldg.position + Vector3(-w / 2 + 0.4 + col * 0.8, -h / 2 + 1 + row * 1.2, d / 2 + 0.01)
					var wm = StandardMaterial3D.new()
					wm.emission_enabled = true
					wm.emission = Color(0, 0.6, 1) if rng.randf() > 0.4 else Color(1, 0.2, 0.5)
					wm.emission_energy_multiplier = rng.randf_range(0.5, 2.5)
					wl.mesh.material = wm
					add_child(wl)

	# Neon lines
	for i in range(10):
		var line = MeshInstance3D.new()
		var lm = PlaneMesh.new()
		lm.size = Vector2(70, 0.04)
		line.mesh = lm
		line.position = Vector3(0, -1.98, -12 + i * 2.5)
		var lmat = StandardMaterial3D.new()
		lmat.emission_enabled = true
		lmat.emission = Color(0, 0.4, 1) if i % 2 == 0 else Color(0.8, 0, 0.4)
		lmat.emission_energy_multiplier = 0.6
		line.mesh.material = lmat
		add_child(line)

	# Lights
	for ld in [[Color(0, 0.5, 1), 3, Vector3(-10, 7, -10)], [Color(0.8, 0, 0.5), 2.5, Vector3(10, 6, -8)], [Color(0, 0.3, 0.8), 2, Vector3(0, 3, 6)]]:
		var l = OmniLight3D.new()
		l.light_color = ld[0]
		l.light_energy = ld[1]
		l.omni_range = 30
		l.position = ld[2]
		add_child(l)

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	# ── Main menu ──
	_main_ui = Control.new()
	_main_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(_main_ui)

	_bg(_main_ui, Color(0, 0, 0, 0))  # transparent — see 3D background

	_label(_main_ui, "MATVGTA", 80, Color(0, 0.8, 1), Vector2(960, 80), HORIZONTAL_ALIGNMENT_CENTER)
	_label(_main_ui, "Neon City Simulator", 28, Color(0.5, 0.3, 0.8), Vector2(960, 140), HORIZONTAL_ALIGNMENT_CENTER)

	_label(_main_ui, "WORLD SIZE", 22, Color(0.6, 0.6, 0.7), Vector2(960, 220), HORIZONTAL_ALIGNMENT_CENTER)

	var sizes = ["Small", "Medium", "Large", "XL", "Giant"]
	for i in range(sizes.size()):
		var btn = _btn(_main_ui, sizes[i], Vector2(660 + i * 160, 270), Vector2(140, 45))
		btn.name = "size_%d" % i
		btn.pressed.connect(_select_size.bind(i))
		if i == _selected_size:
			(btn.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color(0, 0.4, 0.2)

	_label(_main_ui, "────────────────────", 16, Color(0.15, 0.2, 0.35), Vector2(960, 340), HORIZONTAL_ALIGNMENT_CENTER)

	var btn_data = [
		["NEW GAME",  Color(0, 0.8, 0.4), Vector2(960, 410)],
		["LOAD GAME", Color(0, 0.6, 0.9), Vector2(960, 475)],
		["SETTINGS",  Color(0.9, 0.7, 0), Vector2(960, 540)],
		["EXIT",      Color(0.9, 0.2, 0.2), Vector2(960, 605)],
	]
	for d in btn_data:
		var b = _btn(_main_ui, d[0], d[2], Vector2(280, 50))
		b.pressed.connect(_on_button.bind(d[0]))

	# ── Loading screen ──
	_loading_ui = Control.new()
	_loading_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_ui.visible = false
	_ui_layer.add_child(_loading_ui)

	_bg(_loading_ui, Color(0.01, 0.01, 0.03, 0.95))

	_label(_loading_ui, "GENERATING WORLD", 48, Color(0, 0.8, 1), Vector2(960, 350), HORIZONTAL_ALIGNMENT_CENTER)

	var progress_bg = PanelContainer.new()
	progress_bg.position = Vector2(560, 430)
	progress_bg.custom_minimum_size = Vector2(800, 40)
	var pbs = StyleBoxFlat.new()
	pbs.bg_color = Color(0.08, 0.08, 0.12)
	pbs.corner_radius_top_left = 8
	pbs.corner_radius_top_right = 8
	pbs.corner_radius_bottom_left = 8
	pbs.corner_radius_bottom_right = 8
	progress_bg.add_theme_stylebox_override("panel", pbs)
	_loading_ui.add_child(progress_bg)

	var bar = ProgressBar.new()
	bar.name = "progress"
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0, 0.7, 1)
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	bar.add_theme_stylebox_override("fill", fill)
	progress_bg.add_child(bar)

	_label(_loading_ui, "Preparing...", 20, Color(0.5, 0.5, 0.6), Vector2(960, 490), HORIZONTAL_ALIGNMENT_CENTER).name = "loading_status"

	# ── Settings ──
	_settings_ui = Control.new()
	_settings_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_ui.visible = false
	_ui_layer.add_child(_settings_ui)

	_bg(_settings_ui, Color(0.01, 0.01, 0.03, 0.92))

	_label(_settings_ui, "SETTINGS", 52, Color(0, 0.8, 1), Vector2(960, 60), HORIZONTAL_ALIGNMENT_CENTER)
	_label(_settings_ui, "─────────────────────", 16, Color(0.15, 0.2, 0.35), Vector2(960, 110), HORIZONTAL_ALIGNMENT_CENTER)

	_label(_settings_ui, "Graphics Quality", 26, Color(0.7, 0.7, 0.8), Vector2(960, 160), HORIZONTAL_ALIGNMENT_CENTER)

	var presets = ["Potato", "Low", "Medium", "High", "Ultra"]
	for i in range(presets.size()):
		var b = _btn(_settings_ui, presets[i], Vector2(560 + i * 170, 210), Vector2(150, 50))
		b.name = "preset_%d" % i
		b.pressed.connect(_on_preset.bind(i))

	_label(_settings_ui, "FSR 2.2 Resolution Scale", 26, Color(0.7, 0.7, 0.8), Vector2(960, 310), HORIZONTAL_ALIGNMENT_CENTER)

	var fsr_vals = ["100%", "77%", "67%", "59%", "50%"]
	var fsr_names = ["Off", "Ultra Qual", "Quality", "Balanced", "Ultra Perf"]
	for i in range(fsr_vals.size()):
		var b = _btn(_settings_ui, fsr_vals[i] + "\n" + fsr_names[i], Vector2(560 + i * 170, 360), Vector2(150, 60))
		b.name = "fsr_%d" % i
		b.pressed.connect(_on_fsr.bind(i))

	_label(_settings_ui, "─────────────────────", 16, Color(0.15, 0.2, 0.35), Vector2(960, 460), HORIZONTAL_ALIGNMENT_CENTER)

	var back = _btn(_settings_ui, "BACK", Vector2(960, 500), Vector2(200, 50))
	back.pressed.connect(_show_main)

func _bg(parent: Control, color: Color) -> void:
	var r = ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)

func _label(parent: Control, text: String, size: int, color: Color, pos: Vector2, align: HorizontalAlignment) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.position = pos
	l.size = Vector2(600, size * 1.5)
	l.offset_left = -300
	l.offset_right = 300
	l.position = pos
	parent.add_child(l)
	return l

func _btn(parent: Control, text: String, pos: Vector2, sz: Vector2) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos - sz / 2
	b.custom_minimum_size = sz
	b.size = sz
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.08, 0.15, 0.8)
	s.border_color = Color(0, 0.4, 0.8, 0.5)
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 8
	s.corner_radius_top_right = 8
	s.corner_radius_bottom_left = 8
	s.corner_radius_bottom_right = 8
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", s)
	var h = s.duplicate()
	h.bg_color = Color(0.0, 0.15, 0.35, 0.9)
	h.border_color = Color(0, 0.7, 1, 0.8)
	b.add_theme_stylebox_override("hover", h)
	var p = s.duplicate()
	p.bg_color = Color(0, 0.2, 0.5, 1)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
	parent.add_child(b)
	return b

func _on_button(btn_name: String) -> void:
	match btn_name:
		"NEW GAME":
			_main_ui.visible = false
			_loading_ui.visible = true
			new_game_selected.emit(_selected_size)
		"LOAD GAME":
			load_game_selected.emit()
		"SETTINGS":
			_main_ui.visible = false
			_settings_ui.visible = true
		"EXIT":
			exit_requested.emit()

func _select_size(idx: int) -> void:
	_selected_size = idx
	for i in range(5):
		var b = _main_ui.get_node_or_null("size_%d" % i)
		if b:
			var s = b.get_theme_stylebox("normal") as StyleBoxFlat
			s.bg_color = Color(0, 0.5, 0.25) if i == idx else Color(0.05, 0.08, 0.15, 0.8)

func _show_main() -> void:
	_settings_ui.visible = false
	_main_ui.visible = true

func _on_preset(idx: int) -> void:
	SettingsManager.apply_preset(idx)
	_refresh_preset_highlights()

func _on_fsr(idx: int) -> void:
	var modes = [SettingsManager.FSRMode.OFF, SettingsManager.FSRMode.ULTRA_QUALITY, SettingsManager.FSRMode.QUALITY, SettingsManager.FSRMode.BALANCED, SettingsManager.FSRMode.PERFORMANCE]
	SettingsManager.set_fsr(idx != 0, modes[idx])
	_refresh_fsr_highlights()

func _refresh_preset_highlights() -> void:
	for i in range(5):
		var b = _settings_ui.get_node_or_null("preset_%d" % i)
		if b:
			var s = b.get_theme_stylebox("normal") as StyleBoxFlat
			s.bg_color = Color(0, 0.5, 0.25) if SettingsManager.current_preset == i else Color(0.05, 0.08, 0.15, 0.8)

func _refresh_fsr_highlights() -> void:
	for i in range(5):
		var b = _settings_ui.get_node_or_null("fsr_%d" % i)
		if b:
			var s = b.get_theme_stylebox("normal") as StyleBoxFlat
			s.bg_color = Color(0, 0.4, 0.6) if SettingsManager.fsr_mode == i else Color(0.05, 0.08, 0.15, 0.8)

# ── Loading progress ──

func update_progress(progress: float) -> void:
	if not _loading_ui:
		return
	var bar = _loading_ui.get_node_or_null("progress")
	if bar:
		bar.value = progress * 100
	var status = _loading_ui.get_node_or_null("loading_status")
	if status:
		if progress < 0.3:
			status.text = "Generating chunks... %d%%" % int(progress * 100)
		elif progress < 0.8:
			status.text = "Merging meshes... %d%%" % int(progress * 100)
		else:
			status.text = "Baking navigation... %d%%" % int(progress * 100)

func show_loading() -> void:
	_main_ui.visible = false
	_loading_ui.visible = true
