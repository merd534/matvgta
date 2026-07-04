extends CharacterBody3D

## CitizenAI — NPC with daily routine lifecycle.
## States: SLEEP, LEAVE_HOME, WALK_TO_WORK, WORK, WALK_HOME, IDLE_HOME
## Player can stalk wealthy targets to rob empty homes.

signal routine_changed(state: State, citizen_name: String)

enum State { SLEEP, LEAVE_HOME, WALK_TO_WORK, WORK, WALK_HOME, IDLE_HOME, FLEE }

@export var citizen_name: String = "Citizen"
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.0
@export var home_position: Vector3 = Vector3.ZERO
@export var work_position: Vector3 = Vector3.ZERO
@export var sleep_start_hour: int = 23
@export var work_start_hour: int = 9
@export var work_end_hour: int = 17
@export var is_wealthy: bool = false
@export var daily_cash: int = 0

var current_state: State = State.SLEEP
var _target_pos: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator
var _alerted: bool = false
var _loot: Array = []
var _patrol_points: Array = []
var _patrol_idx: int = 0
var _work_timer: float = 0.0
var _sleep_timer: float = 0.0
var _label: Label3D
var _body_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("npc")
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(citizen_name)
	_setup_visuals()
	_generate_routine()
	_loot = _generate_daily_loot()

func _setup_visuals() -> void:
	# Body
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "CitizenBody"
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	_body_mesh.mesh = capsule
	_body_mesh.position.y = 0.85
	_body_mesh.rotation.x = PI / 2

	var mat = StandardMaterial3D.new()
	if is_wealthy:
		mat.albedo_color = Color(0.6, 0.4, 0.1)
	else:
		mat.albedo_color = Color(0.3, 0.3, 0.35)
	_body_mesh.material_override = mat
	add_child(_body_mesh)

	# Head
	var head = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	head.mesh = sphere
	head.position.y = 1.75
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.6)
	head.material_override = head_mat
	add_child(head)

	# Name label
	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.text = citizen_name
	_label.font_size = 14
	_label.position = Vector3(0, 2.1, 0)
	_label.visible = false
	add_child(_label)

	# Collision
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)

func _generate_routine() -> void:
	# Generate work commute path
	var mid = (home_position + work_position) / 2.0
	for i in range(_rng.randi_range(2, 4)):
		var offset = Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8))
		_patrol_points.append(mid + offset)
	_patrol_points.append(work_position)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	match current_state:
		State.SLEEP:
			_process_sleep(delta)
		State.LEAVE_HOME:
			_process_move_to(home_position + Vector3(2, 0, 0), State.WALK_TO_WORK)
		State.WALK_TO_WORK:
			_process_patrol(delta, State.WORK)
		State.WORK:
			_process_work(delta)
		State.WALK_HOME:
			_process_patrol(delta, State.IDLE_HOME)
		State.IDLE_HOME:
			velocity.x = 0
			velocity.z = 0
		State.FLEE:
			_process_flee(delta)

	move_and_slide()
	_label.visible = current_state != State.SLEEP

func _process_sleep(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_sleep_timer += delta
	# Wake up after simulated time (simplified)
	if _sleep_timer > 5.0:
		_sleep_timer = 0.0
		_set_state(State.LEAVE_HOME)

func _process_move_to(target: Vector3, next_state: State) -> void:
	var dir = (target - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if global_position.distance_to(target) < 2.0:
		_set_state(next_state)

func _process_patrol(_delta: float, arrived_state: State) -> void:
	if _patrol_points.is_empty():
		_set_state(arrived_state)
		return

	var target = _patrol_points[_patrol_idx]
	var dir = (target - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if global_position.distance_to(target) < 2.0:
		_patrol_idx += 1
		if _patrol_idx >= _patrol_points.size():
			_patrol_idx = 0
			_set_state(arrived_state)

func _process_work(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_work_timer += delta
	if _work_timer > 8.0:
		_work_timer = 0.0
		_patrol_idx = 0
		_set_state(State.WALK_HOME)

func _process_flee(_delta: float) -> void:
	var dir = (_target_pos - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if global_position.distance_to(_target_pos) < 2.0:
		_set_state(State.IDLE_HOME)

func _set_state(new_state: State) -> void:
	current_state = new_state
	routine_changed.emit(new_state, citizen_name)

func is_home_empty() -> bool:
	return current_state in [State.WALK_TO_WORK, State.WORK, State.WALK_HOME]

func is_alerted() -> bool:
	return _alerted

func set_alerted(value: bool) -> void:
	_alerted = value
	if value:
		_flee()

func _flee() -> void:
	_target_pos = home_position
	_set_state(State.FLEE)

func remove_loot(item_name: String) -> void:
	_loot = _loot.filter(func(item): return item.get("name", "") != item_name)

func get_loot() -> Array:
	return _loot

func _generate_daily_loot() -> Array:
	var items: Array = []
	var count = _rng.randi_range(1, 3) if is_wealthy else _rng.randi_range(0, 1)
	for i in range(count):
		items.append({
			"name": "wallet" if _rng.randf() > 0.5 else "phone",
			"rarity": 1 if is_wealthy else 0,
			"value": _rng.randi_range(20, 80) if is_wealthy else _rng.randi_range(5, 20),
		})
	return items

func get_state_name() -> String:
	match current_state:
		State.SLEEP: return "Sleeping"
		State.LEAVE_HOME: return "Leaving"
		State.WALK_TO_WORK: return "Commute"
		State.WORK: return "Working"
		State.WALK_HOME: return "Returning"
		State.IDLE_HOME: return "Home"
		State.FLEE: return "Fleeing"
	return "Unknown"
