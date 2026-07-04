extends StaticBody3D

## HackingTerminal — security terminal that disables cameras on the floor for a duration.
## Player interacts with E key to hack. Shows progress bar during hack.

signal hack_started(terminal: Node3D)
signal hack_completed(terminal: Node3D)

@export var hack_duration: float = 4.0
@export var camera_disable_duration: float = 20.0
@export var interaction_distance: float = 2.5
@export var requires_keycard: bool = false
@export var min_hack_skill: int = 0

var _is_hacking: bool = false
var _hack_timer: float = 0.0
var _is_hacked: bool = false
var _screen_mesh: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _progress_bar: MeshInstance3D
var _progress_mat: StandardMaterial3D
var _label: Label3D

func _ready() -> void:
	add_to_group("hacking_terminals")
	_setup_visuals()

func _setup_visuals() -> void:
	# Terminal body
	var body = MeshInstance3D.new()
	body.name = "TerminalBody"
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 1.2, 0.3)
	body.mesh = box
	body.position = Vector3(0, 0.6, 0)

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.12, 0.12, 0.15)
	body_mat.metallic = 0.6
	body.material_override = body_mat
	add_child(body)

	# Screen
	_screen_mesh = MeshInstance3D.new()
	_screen_mesh.name = "Screen"
	var screen_box = BoxMesh.new()
	screen_box.size = Vector3(0.6, 0.4, 0.02)
	_screen_mesh.mesh = screen_box
	_screen_mesh.position = Vector3(0, 0.8, -0.16)

	_screen_mat = StandardMaterial3D.new()
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.0, 0.8, 0.3)
	_screen_mat.emission_energy_multiplier = 2.0
	_screen_mesh.material_override = _screen_mat
	add_child(_screen_mesh)

	# Progress bar (initially hidden)
	_progress_bar = MeshInstance3D.new()
	_progress_bar.name = "ProgressBar"
	var bar = BoxMesh.new()
	bar.size = Vector3(0.5, 0.05, 0.01)
	_progress_bar.mesh = bar
	_progress_bar.position = Vector3(0, 0.5, -0.16)
	_progress_bar.visible = false

	_progress_mat = StandardMaterial3D.new()
	_progress_mat.emission_enabled = true
	_progress_mat.emission = Color(0.0, 1.0, 0.5)
	_progress_mat.emission_energy_multiplier = 3.0
	_progress_bar.material_override = _progress_mat
	add_child(_progress_bar)

	# Label
	_label = Label3D.new()
	_label.name = "Label"
	_label.text = "[E] Hack Terminal"
	_label.font_size = 18
	_label.position = Vector3(0, 1.4, 0)
	_label.visible = false
	add_child(_label)

	# Collision
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 1.2, 0.3)
	col.shape = shape
	col.position.y = 0.6
	add_child(col)

func _process(delta: float) -> void:
	_update_label()

	if _is_hacking:
		_hack_timer += delta
		_update_progress()

		if _hack_timer >= hack_duration:
			_complete_hack()

func can_interact(player_pos: Vector3) -> bool:
	return global_position.distance_to(player_pos) < interaction_distance and not _is_hacked

func start_hack() -> void:
	if _is_hacking or _is_hacked:
		return
	_is_hacking = true
	_hack_timer = 0.0
	_progress_bar.visible = true
	_screen_mat.emission = Color(1.0, 0.5, 0.0)
	_screen_mat.emission_energy_multiplier = 3.0
	hack_started.emit(self)

func cancel_hack() -> void:
	_is_hacking = false
	_hack_timer = 0.0
	_progress_bar.visible = false
	_screen_mat.emission = Color(0.0, 0.8, 0.3)
	_screen_mat.emission_energy_multiplier = 2.0

func _complete_hack() -> void:
	_is_hacking = false
	_is_hacked = true
	_progress_bar.visible = false
	_screen_mat.emission = Color(1.0, 0.0, 0.0)
	_screen_mat.emission_energy_multiplier = 1.0
	_label.text = "HACKED"

	# Disable all cameras on this floor
	_disable_floor_cameras()
	hack_completed.emit(self)

	# Reset after duration
	await get_tree().create_timer(camera_disable_duration).timeout
	if is_instance_valid(self):
		_reset_terminal()

func _disable_floor_cameras() -> void:
	var floor_y = global_position.y
	var floor_idx = floori(floor_y / WorldConfig.FLOOR_HEIGHT)

	var cameras = get_tree().get_nodes_in_group("security_cameras")
	for cam in cameras:
		if not cam.has_method("disable"):
			continue
		var cam_floor = floori(cam.global_position.y / WorldConfig.FLOOR_HEIGHT)
		if cam_floor == floor_idx:
			cam.disable(camera_disable_duration)

func _reset_terminal() -> void:
	_is_hacked = false
	_screen_mat.emission = Color(0.0, 0.8, 0.3)
	_screen_mat.emission_energy_multiplier = 2.0
	_label.text = "[E] Hack Terminal"

func _update_progress() -> void:
	var progress = clampf(_hack_timer / hack_duration, 0.0, 1.0)
	_progress_bar.scale.x = progress
	_progress_mat.emission = Color(
		1.0 - progress,
		progress,
		0.0
	)

func _update_label() -> void:
	var player = _get_nearest_player()
	if player and can_interact(player.global_position):
		_label.visible = true
	else:
		_label.visible = false

func _get_nearest_player() -> Node3D:
	for body in get_tree().get_nodes_in_group("player"):
		if body.has_method("get_visibility"):
			return body
	return null
