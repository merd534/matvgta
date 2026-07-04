extends Node

## SettingsManager — deep graphics presets using RenderingServer/Viewport.
## 5 presets: POTATO, LOW, MEDIUM, HIGH, ULTRA
## FSR 2.2 with 4 quality modes.

signal preset_changed(preset: Preset)
signal fsr_changed(enabled: bool, mode: FSRMode)

enum Preset { POTATO, LOW, MEDIUM, HIGH, ULTRA }

## FSR 2.2 quality modes (rendering resolution scale)
enum FSRMode { ULTRA_QUALITY, QUALITY, BALANCED, PERFORMANCE, OFF }

const PRESET_NAMES: Dictionary = {
	Preset.POTATO: "Potato",
	Preset.LOW: "Low",
	Preset.MEDIUM: "Medium",
	Preset.HIGH: "High",
	Preset.ULTRA: "Ultra",
}

const FSR_MODE_NAMES: Dictionary = {
	FSRMode.OFF: "Off",
	FSRMode.ULTRA_QUALITY: "Ultra Quality (77%)",
	FSRMode.QUALITY: "Quality (67%)",
	FSRMode.BALANCED: "Balanced (59%)",
	FSRMode.PERFORMANCE: "Performance (50%)",
}

const FSR_SCALE: Dictionary = {
	FSRMode.OFF: 1.0,
	FSRMode.ULTRA_QUALITY: 0.77,
	FSRMode.QUALITY: 0.67,
	FSRMode.BALANCED: 0.59,
	FSRMode.PERFORMANCE: 0.50,
}

var current_preset: Preset = Preset.MEDIUM
var fsr_enabled: bool = false
var fsr_mode: FSRMode = FSRMode.QUALITY
var _settings_path: String = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func apply_preset(preset: Preset) -> void:
	current_preset = preset
	_apply_graphics(preset)
	preset_changed.emit(preset)

func _apply_graphics(preset: Preset) -> void:
	var vp = get_viewport()
	# Set tonemap via Environment resource (Godot 4.6 API)
	_set_tonemap_aces()
	match preset:
		Preset.POTATO:
			RenderingServer.directional_shadow_atlas_set_size(256, true)
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
			ProjectSettings.set_setting("rendering/screen_space_subsurface_scattering/enable", false)
			ProjectSettings.set_setting("rendering/environment/ssao_enabled", false)
			ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 0)
			if vp:
				vp.scaling_3d_scale = 0.5
				vp.scaling_3d_mode = 1  # FSR 1.0
			_set_view_distance(50)

		Preset.LOW:
			RenderingServer.directional_shadow_atlas_set_size(512, true)
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
			ProjectSettings.set_setting("rendering/environment/ssao_enabled", false)
			if vp:
				vp.scaling_3d_scale = 0.75
				vp.scaling_3d_mode = 1  # FSR 1.0
			_set_view_distance(100)

		Preset.MEDIUM:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)
			ProjectSettings.set_setting("rendering/environment/ssao_enabled", true)
			if vp:
				vp.scaling_3d_scale = 1.0
				vp.scaling_3d_mode = 0  # Disabled
			_set_view_distance(200)

		Preset.HIGH:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 4)
			ProjectSettings.set_setting("rendering/environment/ssao_enabled", true)
			if vp:
				vp.scaling_3d_scale = 1.0
				vp.scaling_3d_mode = 0  # Disabled
			_set_view_distance(400)

		Preset.ULTRA:
			RenderingServer.directional_shadow_atlas_set_size(8192, true)
			ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 8)
			ProjectSettings.set_setting("rendering/environment/ssao_enabled", true)
			if vp:
				vp.scaling_3d_scale = 1.0
				vp.scaling_3d_mode = 0  # Disabled
			_set_view_distance(800)

func _set_tonemap_aces() -> void:
	var vp = get_viewport()
	var world_env = null
	if vp:
		var w3d = vp.get_world_3d()
		if w3d:
			world_env = w3d.environment
	if not world_env:
		var main = get_tree().get_first_node_in_group("main_scene") if get_tree() else null
		if main:
			var we = main.get_node_or_null("WorldEnvironment")
			if we and we is WorldEnvironment:
				world_env = we.environment
	if world_env:
		world_env.tonemap_mode = 3  # ACES (value 3 in Environment.ToneMap)
		world_env.tonemap_white = 6.0

func _set_view_distance(distance: float) -> void:
	# Set far clip on all Camera3D nodes in the scene tree
	var cameras = get_tree().get_nodes_in_group("camera")
	for cam in cameras:
		if cam is Camera3D:
			cam.far = distance
	# Also try finding cameras by type if group is empty
	if cameras.is_empty():
		var root = get_tree().root
		_find_and_update_cameras(root, distance)
	# Apply to any future cameras via this setting
	ProjectSettings.set_setting("rendering/defaults/default_clear_distance", distance)

func _find_and_update_cameras(node: Node, distance: float) -> void:
	for child in node.get_children():
		if child is Camera3D:
			child.far = distance
		if child.get_child_count() > 0:
			_find_and_update_cameras(child, distance)

# ── FSR 2.2 ──

func set_fsr(enabled: bool, mode: FSRMode = FSRMode.QUALITY) -> void:
	fsr_enabled = enabled
	fsr_mode = mode if enabled else FSRMode.OFF
	_apply_fsr()
	fsr_changed.emit(fsr_enabled, fsr_mode)

func toggle_fsr() -> void:
	set_fsr(!fsr_enabled, fsr_mode if not fsr_enabled else FSRMode.QUALITY)

func cycle_fsr_mode(direction: int = 1) -> FSRMode:
	var modes = [FSRMode.OFF, FSRMode.ULTRA_QUALITY, FSRMode.QUALITY, FSRMode.BALANCED, FSRMode.PERFORMANCE]
	var idx = modes.find(fsr_mode)
	idx = (idx + direction) % modes.size()
	if idx < 0:
		idx = modes.size() - 1
	fsr_mode = modes[idx]
	fsr_enabled = fsr_mode != FSRMode.OFF
	_apply_fsr()
	fsr_changed.emit(fsr_enabled, fsr_mode)
	return fsr_mode

func _apply_fsr() -> void:
	var vp = get_viewport()
	if not vp:
		return

	if fsr_enabled and fsr_mode != FSRMode.OFF:
		vp.scaling_3d_mode = 2  # FSR 2.0
		vp.scaling_3d_scale = FSR_SCALE[fsr_mode]
	else:
		_apply_fsr_for_preset(current_preset)

func _apply_fsr_for_preset(preset: Preset) -> void:
	var vp = get_viewport()
	if not vp:
		return
	match preset:
		Preset.POTATO:
			vp.scaling_3d_scale = 0.5
			vp.scaling_3d_mode = 1  # FSR 1.0
		Preset.LOW:
			vp.scaling_3d_scale = 0.75
			vp.scaling_3d_mode = 1  # FSR 1.0
		_:
			vp.scaling_3d_scale = 1.0
			vp.scaling_3d_mode = 0  # Disabled

func get_fsr_info() -> Dictionary:
	return {
		"enabled": fsr_enabled,
		"mode": fsr_mode,
		"mode_name": FSR_MODE_NAMES.get(fsr_mode, "Unknown"),
		"scale": FSR_SCALE.get(fsr_mode, 1.0),
	}

# ── Presets ──

func cycle_preset(direction: int = 1) -> Preset:
	var values = Preset.values()
	var idx = values.find(current_preset)
	idx = (idx + direction) % values.size()
	if idx < 0:
		idx = values.size() - 1
	apply_preset(values[idx])
	return current_preset

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("settings", "preset", current_preset)
	cfg.set_value("settings", "language", Localization.current_language)
	cfg.set_value("settings", "fsr_enabled", fsr_enabled)
	cfg.set_value("settings", "fsr_mode", fsr_mode)
	cfg.set_value("settings", "master_volume", AudioServer.get_bus_volume_db(0))
	var music_idx = AudioServer.get_bus_index("Music")
	cfg.set_value("settings", "music_volume", AudioServer.get_bus_volume_db(music_idx) if music_idx >= 0 else 0.0)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	cfg.set_value("settings", "sfx_volume", AudioServer.get_bus_volume_db(sfx_idx) if sfx_idx >= 0 else 0.0)
	cfg.save(_settings_path)

func load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_settings_path) == OK:
		current_preset = cfg.get_value("settings", "preset", Preset.MEDIUM)
		fsr_enabled = cfg.get_value("settings", "fsr_enabled", false)
		fsr_mode = cfg.get_value("settings", "fsr_mode", FSRMode.QUALITY)
		var lang = cfg.get_value("settings", "language", "ru")
		Localization.set_language(lang)
		var master = cfg.get_value("settings", "master_volume", 0.0)
		AudioServer.set_bus_volume_db(0, master)
	apply_preset(current_preset)
	_apply_fsr()
