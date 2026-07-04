extends CharacterBody3D

## GuardAI — patrol, investigate, and chase states.
## Responds to alarm system and camera alerts.

signal guard_lost_player(guard: Node3D)
signal guard_spotted_player(guard: Node3D, player: Node3D)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, RETURN }

@export var walk_speed: float = 3.5
@export var chase_speed: float = 7.0
@export var investigate_speed: float = 4.0
@export var vision_range: float = 15.0
@export var vision_angle: float = 70.0
@export var hearing_range: float = 12.0
@export var search_time: float = 10.0
@export var gravity: float = 20.0

var current_state: State = State.PATROL
var _target_player: Node3D = null
var _investigate_point: Vector3 = Vector3.ZERO
var _patrol_points: Array = []
var _patrol_idx: int = 0
var _search_timer: float = 0.0
var _last_known_pos: Vector3 = Vector3.ZERO
var _head: Node3D
var _vision_ray: RayCast3D
var _cone_visual: MeshInstance3D
var _cone_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("guards")
	_setup_visuals()
	_setup_vision()
	_generate_patrol_points()

func _setup_visuals() -> void:
	# Body
	var body = MeshInstance3D.new()
	body.name = "GuardBody"
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	body.rotation.x = PI / 2

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.2, 0.15)
	body.material_override = body_mat
	add_child(body)

	# Head
	_head = Node3D.new()
	_head.name = "GuardHead"
	_head.position.y = 1.8
	add_child(_head)

	# Vision indicator
	_cone_visual = MeshInstance3D.new()
	_cone_visual.name = "VisionCone"
	var cone = PrismMesh.new()
	cone.size = Vector3(0.1, vision_range * 0.6, vision_range * 0.5)
	_cone_visual.mesh = cone
	_cone_visual.position = Vector3(0, 0, -vision_range * 0.3)
	_cone_visual.rotation.x = -PI / 2

	_cone_mat = StandardMaterial3D.new()
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.albedo_color = Color(1.0, 1.0, 0.2, 0.06)
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = true
	_cone_visual.material_override = _cone_mat
	_head.add_child(_cone_visual)

	# Collision
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

func _setup_vision() -> void:
	_vision_ray = RayCast3D.new()
	_vision_ray.name = "VisionRay"
	_vision_ray.target_position = Vector3(0, 0, -vision_range)
	_vision_ray.enabled = true
	_vision_ray.collision_mask = 1
	_head.add_child(_vision_ray)

func _generate_patrol_points() -> void:
	var base = global_position
	for i in range(randi_range(3, 6)):
		var offset = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		_patrol_points.append(base + offset)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.CHASE:
			_process_chase(delta)
		State.SEARCH:
			_process_search(delta)
		State.RETURN:
			_process_return(delta)

	move_and_slide()
	_update_visuals()

func _process_patrol(_delta: float) -> void:
	_cone_mat.albedo_color = Color(1.0, 1.0, 0.2, 0.06)

	if _patrol_points.is_empty():
		return

	var target = _patrol_points[_patrol_idx]
	var dir = (target - global_position).normalized()
	dir.y = 0

	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed

	# Face direction
	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	# Check distance to patrol point
	if global_position.distance_to(target) < 1.5:
		_patrol_idx = (_patrol_idx + 1) % _patrol_points.size()

	_check_vision()

func _process_investigate(delta: float) -> void:
	_cone_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.1)

	var dir = (_investigate_point - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * investigate_speed
	velocity.z = dir.z * investigate_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if global_position.distance_to(_investigate_point) < 2.0:
		current_state = State.SEARCH
		_search_timer = search_time

	_check_vision()

func _process_chase(delta: float) -> void:
	_cone_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.15)

	if not _target_player or not is_instance_valid(_target_player):
		_lose_player()
		return

	var dir = (_target_player.global_position - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	_last_known_pos = _target_player.global_position

	# Check if still in range
	var dist = global_position.distance_to(_target_player.global_position)
	if dist > vision_range * 1.5:
		_lose_player()

func _process_search(delta: float) -> void:
	_cone_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.1)

	_search_timer -= delta
	velocity.x = 0
	velocity.z = 0

	# Look around
	_head.rotation.y += delta * 2.0

	_check_vision()

	if _search_timer <= 0:
		current_state = State.RETURN

func _process_return(delta: float) -> void:
	_cone_mat.albedo_color = Color(0.5, 0.5, 0.5, 0.05)

	var target = _patrol_points[_patrol_idx] if not _patrol_points.is_empty() else global_position
	var dir = (target - global_position).normalized()
	dir.y = 0

	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed

	if dir.length() > 0.1:
		look_at(global_position + dir, Vector3.UP)

	if global_position.distance_to(target) < 2.0:
		current_state = State.PATROL

func _check_vision() -> void:
	for body in get_tree().get_nodes_in_group("player"):
		if not body.has_method("get_visibility"):
			continue

		var to_body = body.global_position - global_position
		var dist = to_body.length()
		if dist > vision_range:
			continue

		# Angle check
		var forward = -_head.global_basis.z
		var angle = forward.angle_to(to_body.normalized())
		if angle > deg_to_rad(vision_angle / 2):
			continue

		# Raycast LOS
		_vision_ray.target_position = to_body
		_vision_ray.force_raycast_update()

		if _vision_ray.is_colliding() and _vision_ray.get_collider() == body:
			var vis = body.get_visibility()
			if vis > 0.1:
				_target_player = body
				_last_known_pos = body.global_position
				current_state = State.CHASE
				guard_spotted_player.emit(self, body)
				return

func investigate(pos: Vector3) -> void:
	_investigate_point = pos
	current_state = State.INVESTIGATE

func _lose_player() -> void:
	_target_player = null
	current_state = State.SEARCH
	_search_timer = search_time
	guard_lost_player.emit(self)

func get_state_name() -> String:
	match current_state:
		State.PATROL: return "PATROL"
		State.INVESTIGATE: return "INVESTIGATE"
		State.CHASE: return "CHASE"
		State.SEARCH: return "SEARCH"
		State.RETURN: return "RETURN"
	return "UNKNOWN"

func _update_visuals() -> void:
	pass
