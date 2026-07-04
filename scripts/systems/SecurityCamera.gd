extends Node3D

## SecurityCamera — rotational camera with Area3D vision cone + raycast LOS.
## States: IDLE (scanning), ALERT (player spotted), DISABLED (EMP/hacked).

signal player_spotted(camera: Node3D, player: Node3D)
signal player_lost(camera: Node3D)
signal camera_disabled(camera: Node3D)
signal camera_enabled(camera: Node3D)

enum State { IDLE, ALERT, DISABLED }

@export var scan_speed: float = 45.0          # degrees per second
@export var scan_range: float = 90.0          # total scan arc in degrees
@export var vision_range: float = 20.0
@export var vision_angle: float = 60.0        # full cone angle
@export var alert_duration: float = 5.0       # seconds before losing player
@export var disabled_duration: float = 30.0   # seconds when EMP'd

var current_state: State = State.IDLE
var _target_player: Node3D = null
var _alert_timer: float = 0.0
var _disabled_timer: float = 0.0
var _scan_direction: float = 0.0
var _scan_forward: bool = true
var _vision_cone: Area3D
var _raycast: RayCast3D
var _cone_mesh: MeshInstance3D
var _cone_material: StandardMaterial3D
var _camera_head: Node3D

func _ready() -> void:
	_setup_camera_head()
	_setup_vision_cone()
	_setup_raycast()
	_setup_visuals()

func _setup_camera_head() -> void:
	_camera_head = Node3D.new()
	_camera_head.name = "CameraHead"
	add_child(_camera_head)

func _setup_vision_cone() -> void:
	_vision_cone = Area3D.new()
	_vision_cone.name = "VisionCone"
	_vision_cone.collision_layer = 0
	_vision_cone.collision_mask = 1  # detect player

	# Cone shape using CylinderMesh approximation
	var cone = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = vision_range * sin(deg_to_rad(vision_angle / 2))
	shape.height = vision_range
	cone.shape = shape
	cone.rotation.x = PI / 2  # lay horizontal
	cone.position.z = vision_range / 2

	_vision_cone.add_child(cone)
	_vision_cone.body_entered.connect(_on_body_entered)
	_vision_cone.body_exited.connect(_on_body_exited)
	_camera_head.add_child(_vision_cone)

func _setup_raycast() -> void:
	_raycast = RayCast3D.new()
	_raycast.name = "LineOfSight"
	_raycast.target_position = Vector3(0, 0, -vision_range)
	_raycast.enabled = true
	_raycast.collision_mask = 1
	_camera_head.add_child(_raycast)

func _setup_visuals() -> void:
	# Camera body
	var body = MeshInstance3D.new()
	body.name = "CameraBody"
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 0.25, 0.4)
	body.mesh = box
	body.position = Vector3(0, 0, 0)

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.15, 0.18)
	body_mat.metallic = 0.7
	body_mat.roughness = 0.3
	body.material_override = body_mat
	add_child(body)

	# Vision cone visual (transparent triangle)
	_cone_mesh = MeshInstance3D.new()
	_cone_mesh.name = "ConeVisual"
	var cone_mesh = PrismMesh.new()
	cone_mesh.size = Vector3(0.1, vision_range, vision_range * 0.8)
	_cone_mesh.mesh = cone_mesh
	_cone_mesh.position = Vector3(0, 0, vision_range / 2)
	_cone_mesh.rotation.x = -PI / 2

	_cone_material = StandardMaterial3D.new()
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.albedo_color = Color(0.2, 1.0, 0.2, 0.08)
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_material.no_depth_test = true
	_cone_mesh.material_override = _cone_material
	_camera_head.add_child(_cone_mesh)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.ALERT:
			_process_alert(delta)
		State.DISABLED:
			_process_disabled(delta)

func _process_idle(delta: float) -> void:
	# Scan back and forth
	var half_range = deg_to_rad(scan_range / 2)
	_scan_direction += scan_speed * delta * (1 if _scan_forward else -1)

	if abs(_scan_direction) >= half_range:
		_scan_forward = !_scan_forward

	_camera_head.rotation.y = deg_to_rad(_scan_direction)

	# Check if player is in cone
	_check_player_visibility()

func _process_alert(delta: float) -> void:
	_alert_timer -= delta
	if _target_player:
		# Track player
		var to_player = _target_player.global_position - global_position
		_camera_head.rotation.y = atan2(-to_player.x, -to_player.z)

		_raycast.target_position = Vector3(0, 0, -vision_range)
		_raycast.force_raycast_update()

		if _raycast.is_colliding():
			var hit = _raycast.get_collider()
			if hit == _target_player:
				_alert_timer = alert_duration
			else:
				_alert_timer -= delta * 2  # lose faster if obstructed

	if _alert_timer <= 0:
		_set_state(State.IDLE)
		player_lost.emit(self)

func _process_disabled(delta: float) -> void:
	_disabled_timer -= delta
	if _disabled_timer <= 0:
		_set_state(State.IDLE)
		camera_enabled.emit(self)

func _check_player_visibility() -> void:
	for body in _vision_cone.get_overlapping_bodies():
		if not body.has_method("get_visibility"):
			continue

		var to_body = body.global_position - global_position
		var dist = to_body.length()
		if dist > vision_range:
			continue

		# Angle check
		var forward = -_camera_head.global_basis.z
		var angle = forward.angle_to(to_body.normalized())
		if angle > deg_to_rad(vision_angle / 2):
			continue

		# Line of sight raycast
		_raycast.target_position = to_body
		_raycast.force_raycast_update()

		if _raycast.is_colliding() and _raycast.get_collider() == body:
			# Player visibility check
			var vis = body.get_visibility()
			if vis > 0.15:  # threshold to spot
				_target_player = body
				_set_state(State.ALERT)
				player_spotted.emit(self, body)
				return

func _set_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			_cone_material.albedo_color = Color(0.2, 1.0, 0.2, 0.08)
		State.ALERT:
			_cone_material.albedo_color = Color(1.0, 0.1, 0.1, 0.2)
			_alert_timer = alert_duration
		State.DISABLED:
			_cone_material.albedo_color = Color(0.3, 0.3, 0.3, 0.05)
			_disabled_timer = disabled_duration
			camera_disabled.emit(self)

func disable(duration: float = -1.0) -> void:
	if current_state == State.DISABLED:
		return
	if duration > 0:
		disabled_duration = duration
	_set_state(State.DISABLED)

func enable() -> void:
	if current_state == State.DISABLED:
		_disabled_timer = 0

func is_disabled() -> bool:
	return current_state == State.DISABLED

func is_alert() -> bool:
	return current_state == State.ALERT

func _on_body_entered(_body: Node3D) -> void:
	pass  # vision cone overlap detected

func _on_body_exited(body: Node3D) -> void:
	if body == _target_player:
		pass  # will lose via alert timer
