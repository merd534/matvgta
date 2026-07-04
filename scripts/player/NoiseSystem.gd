extends Node3D

## NoiseSystem — visualizes and distributes player noise radius.
## Running emits a visible noise sphere that alerts nearby guards.

@export var player: NodePath
@export var noise_indicator_enabled: bool = true

var current_noise_radius: float = 0.0
var _player: Node3D
var _noise_mesh: MeshInstance3D
var _noise_material: StandardMaterial3D

func _ready() -> void:
	_player = get_node(player) as Node3D if player else get_parent() as Node3D
	if _player:
		_player.noise_emitted.connect(_on_noise_emitted)
	_setup_noise_visual()

func _setup_noise_visual() -> void:
	_noise_mesh = MeshInstance3D.new()
	_noise_mesh.name = "NoiseIndicator"
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_noise_mesh.mesh = sphere

	_noise_material = StandardMaterial3D.new()
	_noise_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_noise_material.albedo_color = Color(1.0, 0.3, 0.3, 0.15)
	_noise_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_noise_material.no_depth_test = true
	_noise_mesh.material_override = _noise_material

	add_child(_noise_mesh)
	_noise_mesh.visible = false

func _process(_delta: float) -> void:
	if not _player:
		return

	# Smooth radius interpolation
	var target = current_noise_radius
	_noise_mesh.scale = Vector3.ONE * target
	_noise_mesh.global_position = _player.global_position

	# Fade alpha based on radius
	var alpha = clampf(target / 15.0, 0.0, 0.25)
	_noise_material.albedo_color.a = alpha
	_noise_mesh.visible = target > 0.5

func _on_noise_emitted(_pos: Vector3, radius: float) -> void:
	current_noise_radius = radius

func get_noise_level() -> String:
	if current_noise_radius < 1.0:
		return "SILENT"
	elif current_noise_radius < 5.0:
		return "QUIET"
	elif current_noise_radius < 10.0:
		return "LOUD"
	else:
		return "VERY_LOUD"
