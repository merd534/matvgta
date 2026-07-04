extends Node3D

## PoliceDirector3D — 1-5 star wanted system with police spawn/despawn.
## Crimes: camera alerts, pickpocketing, guard knockouts, theft.
## Police search backalleys and vents if player witnessed entering.

signal wanted_level_changed(stars: int)
signal police_spawned(police: Node3D)
signal police_dispatched(message: String)

enum CrimeType { CAMERA_ALERT, PICKPOCKET_DETECTED, GUARD_KNOCKOUT, THEFT, VENT_WITNESSED }

@export var max_wanted_stars: int = 5
@export var star_decay_time: float = 30.0
@export var police_per_star: Array = [0, 1, 2, 3, 5]
@export var spawn_radius_min: float = 20.0
@export var spawn_radius_max: float = 50.0
@export var search_duration: float = 60.0

var current_stars: int = 0
var _crime_heat: float = 0.0
var _decay_timer: float = 0.0
var _active_police: Array = []
var _player_last_pos: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator

const CRIME_WEIGHTS: Dictionary = {
	CrimeType.CAMERA_ALERT: 15.0,
	CrimeType.PICKPOCKET_DETECTED: 20.0,
	CrimeType.GUARD_KNOCKOUT: 25.0,
	CrimeType.THEFT: 10.0,
	CrimeType.VENT_WITNESSED: 30.0,
}

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()

func _process(delta: float) -> void:
	if _crime_heat > 0:
		_decay_timer += delta
		if _decay_timer >= star_decay_time:
			_decay_timer = 0.0
			_crime_heat = maxf(0, _crime_heat - 10.0)
			_evaluate_wanted_level()

	# Clean up invalid references
	_active_police = _active_police.filter(func(p): return is_instance_valid(p))

	# Update police targets
	for police in _active_police:
		if police.has_method("investigate"):
			if police.global_position.distance_to(_player_last_pos) > 5.0:
				police.investigate(_player_last_pos)

func report_crime(crime: CrimeType, crime_pos: Vector3, severity: float = 1.0) -> void:
	var weight = CRIME_WEIGHTS.get(crime, 10.0) * severity
	_crime_heat += weight
	_player_last_pos = crime_pos
	_decay_timer = 0.0
	_evaluate_wanted_level()
	_dispatch_police(crime_pos)

func _evaluate_wanted_level() -> void:
	var new_stars: int
	if _crime_heat <= 0:
		new_stars = 0
	elif _crime_heat < 20:
		new_stars = 1
	elif _crime_heat < 50:
		new_stars = 2
	elif _crime_heat < 80:
		new_stars = 3
	elif _crime_heat < 120:
		new_stars = 4
	else:
		new_stars = 5

	new_stars = mini(new_stars, max_wanted_stars)

	if new_stars != current_stars:
		current_stars = new_stars
		wanted_level_changed.emit(current_stars)
		_manage_police_count()

func _dispatch_police(crime_pos: Vector3) -> void:
	var needed = _get_needed_police_count()
	var current = _active_police.size()
	if current >= needed:
		return
	var to_spawn = needed - current

	for i in range(to_spawn):
		var spawn_pos = _get_spawn_position(crime_pos)
		var police = _spawn_police(spawn_pos)
		if police:
			_active_police.append(police)
			police.investigate(crime_pos)
			police_dispatched.emit("Police dispatched to sector")

func _get_needed_police_count() -> int:
	if current_stars < police_per_star.size():
		return police_per_star[current_stars]
	return police_per_star[-1]

func _manage_police_count() -> void:
	var needed = _get_needed_police_count()

	# Remove excess police
	while _active_police.size() > needed:
		var excess = _active_police.pop_back()
		if is_instance_valid(excess):
			excess.queue_free()

	# Add missing police
	if _active_police.size() < needed:
		var to_add = needed - _active_police.size()
		for i in range(to_add):
			var pos = _get_spawn_position(_player_last_pos)
			var police = _spawn_police(pos)
			if police:
				_active_police.append(police)

func _spawn_police(pos: Vector3) -> Node3D:
	var police = _create_police_unit()
	police.position = pos
	add_child(police)
	police_spawned.emit(police)
	return police

func _create_police_unit() -> CharacterBody3D:
	var police = CharacterBody3D.new()
	police.name = "Police_%d" % _rng.randi()
	police.add_to_group("guards")

	# Body
	var body = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	body.rotation.x = PI / 2

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.1, 0.3)
	body.material_override = mat
	police.add_child(body)

	# Head
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	head.mesh = sphere
	head.position.y = 1.85
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.6)
	head.material_override = head_mat
	police.add_child(head)

	# Hat
	var hat = MeshInstance3D.new()
	var hat_mesh = CylinderMesh.new()
	hat_mesh.top_radius = 0.2
	hat_mesh.bottom_radius = 0.22
	hat_mesh.height = 0.12
	hat.mesh = hat_mesh
	hat.position.y = 2.05
	var hat_mat = StandardMaterial3D.new()
	hat_mat.albedo_color = Color(0.02, 0.05, 0.2)
	hat.material_override = hat_mat
	police.add_child(hat)

	# Collision
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	police.add_child(col)

	# Add GuardAI script
	var script = load("res://scripts/systems/GuardAI.gd")
	if script:
		police.set_script(script)

	return police

func _get_spawn_position(target: Vector3) -> Vector3:
	var angle = _rng.randf_range(0, TAU)
	var dist = _rng.randf_range(spawn_radius_min, spawn_radius_max)
	return target + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

func clear_wanted() -> void:
	_crime_heat = 0
	current_stars = 0
	_decay_timer = 0
	for police in _active_police:
		if is_instance_valid(police):
			police.queue_free()
	_active_police.clear()
	wanted_level_changed.emit(0)

func get_wanted_stars() -> int:
	return current_stars

func is_wanted() -> bool:
	return current_stars > 0
