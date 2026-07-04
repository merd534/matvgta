extends Node3D

## EMPGadget — portable hacking device.
## Creates a 4m sphere on activation, disabling all cameras inside for 30s.

signal emp_activated(position: Vector3, radius: float)
signal emp_deactivated()

@export var emp_radius: float = 4.0
@export var emp_duration: float = 30.0
@export var cooldown: float = 45.0
@export var activation_time: float = 0.5

var _is_active: bool = false
var _cooldown_timer: float = 0.0
var _active_timer: float = 0.0
var _player: Node3D
var _emp_mesh: MeshInstance3D
var _emp_material: StandardMaterial3D
var _emp_sound: AudioStreamPlayer3D

func _ready() -> void:
	_player = get_parent()
	_setup_emp_visual()
	_setup_audio()

func _setup_emp_visual() -> void:
	_emp_mesh = MeshInstance3D.new()
	_emp_mesh.name = "EMPSphere"
	var sphere = SphereMesh.new()
	sphere.radius = emp_radius
	sphere.height = emp_radius * 2
	sphere.radial_segments = 32
	sphere.rings = 16
	_emp_mesh.mesh = sphere

	_emp_material = StandardMaterial3D.new()
	_emp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_emp_material.albedo_color = Color(0.0, 0.6, 1.0, 0.0)
	_emp_material.emission_enabled = true
	_emp_material.emission = Color(0.0, 0.5, 1.0)
	_emp_material.emission_energy_multiplier = 0.0
	_emp_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_emp_material.no_depth_test = true
	_emp_mesh.material_override = _emp_material
	_emp_mesh.visible = false
	add_child(_emp_mesh)

func _setup_audio() -> void:
	_emp_sound = AudioStreamPlayer3D.new()
	_emp_sound.name = "EMPSound"
	add_child(_emp_sound)

func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	if _is_active:
		_active_timer -= delta
		_animate_emp()

		if _active_timer <= 0:
			_deactivate_emp()

func can_activate() -> bool:
	return _cooldown_timer <= 0 and not _is_active

func activate() -> void:
	if not can_activate():
		return

	_is_active = true
	_active_timer = activation_time + emp_duration
	_emp_mesh.visible = true
	_emp_mesh.global_position = _player.global_position

	# Disable cameras in radius
	_disable_cameras_in_radius()

	emp_activated.emit(global_position, emp_radius)

func _disable_cameras_in_radius() -> void:
	var cameras = get_tree().get_nodes_in_group("security_cameras")
	for cam in cameras:
		if not cam.has_method("disable"):
			continue
		var dist = _emp_mesh.global_position.distance_to(cam.global_position)
		if dist <= emp_radius:
			cam.disable(emp_duration)

func _deactivate_emp() -> void:
	_is_active = false
	_cooldown_timer = cooldown
	_emp_mesh.visible = false
	emp_deactivated.emit()

func _animate_emp() -> void:
	var progress = _active_timer / (activation_time + emp_duration)

	# Fade out in last 20%
	if progress < 0.2:
		_emp_material.albedo_color.a = progress * 0.2
		_emp_material.emission_energy_multiplier = progress * 3.0
	else:
		_emp_material.albedo_color.a = 0.04
		_emp_material.emission_energy_multiplier = 2.0

	# Pulse
	var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.7
	_emp_material.emission_energy_multiplier *= pulse

func get_cooldown_progress() -> float:
	if _cooldown_timer <= 0:
		return 1.0
	return 1.0 - (_cooldown_timer / cooldown)

func is_ready() -> bool:
	return can_activate()
