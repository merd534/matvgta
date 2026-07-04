extends CharacterBody3D

## Player3D — First/Third-person controller with stealth states.
## States: IDLE, WALK, RUN, CROUCH, VENT_CRAWL

signal state_changed(new_state: State)
signal noise_emitted(position: Vector3, radius: float)

enum State { IDLE, WALK, RUN, CROUCH, VENT_CRAWL }

@export var walk_speed: float = 4.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 2.0
@export var vent_speed: float = 1.5
@export var jump_velocity: float = 6.0
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.002
@export var camera_distance: float = 3.0

var current_state: State = State.IDLE
var is_first_person: bool = true
var noise_radius: float = 0.0

var _camera_pivot: Node3D
var _camera: Camera3D
var _camera_arm: Node3D
var _collision: CollisionShape3D
var _standing_height: float = 1.8
var _crouch_height: float = 0.9
var _vent_height: float = 0.6
var _yaw: float = 0.0
var _pitch: float = 0.0
var _headbonk: RayCast3D
var _is_in_vent: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_camera()
	_setup_collision()
	_setup_headbonk_raycast()
	_create_subsystems()

func _input(event: InputEvent) -> void:
	# Always recapture mouse on click if it's free
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

func _setup_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)

	_camera_arm = Node3D.new()
	_camera_arm.name = "CameraArm"
	_camera_pivot.add_child(_camera_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera_arm.add_child(_camera)
	_update_camera_position()

func _setup_collision() -> void:
	_collision = get_node_or_null("CollisionShape3D")
	if not _collision:
		_collision = CollisionShape3D.new()
		_collision.name = "CollisionShape3D"
		add_child(_collision)
	var shape = CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = _standing_height
	_collision.shape = shape
	_collision.position.y = _standing_height / 2

func _setup_headbonk_raycast() -> void:
	_headbonk = RayCast3D.new()
	_headbonk.name = "HeadbonkRay"
	_headbonk.target_position = Vector3(0, 0.5, 0)
	_headbonk.enabled = true
	add_child(_headbonk)

func _create_subsystems() -> void:
	var stealth = load("res://scripts/player/StealthSystem.gd").new()
	stealth.name = "StealthSystem"
	stealth.player = NodePath("..")
	add_child(stealth)

	var noise = load("res://scripts/player/NoiseSystem.gd").new()
	noise.name = "NoiseSystem"
	noise.player = NodePath("..")
	add_child(noise)

	var vent = load("res://scripts/world/VentHighlightSystem.gd").new()
	vent.name = "VentHighlightSystem"
	vent.player = NodePath("..")
	add_child(vent)

	var combat = load("res://scripts/player/StealthCombat3D.gd").new()
	combat.name = "StealthCombat3D"
	combat.player = NodePath("..")
	add_child(combat)

	var disposal = load("res://scripts/player/BodyDisposalSystem.gd").new()
	disposal.name = "BodyDisposalSystem"
	disposal.player = NodePath("..")
	add_child(disposal)

	var emp = load("res://scripts/player/EMPGadget.gd").new()
	emp.name = "EMPGadget"
	add_child(emp)

	var pickpocket = load("res://scripts/systems/PickpocketSystem.gd").new()
	pickpocket.name = "PickpocketSystem"
	add_child(pickpocket)

	var witness = load("res://scripts/systems/WitnessSystem.gd").new()
	witness.name = "WitnessSystem"
	add_child(witness)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clampf(_pitch, -PI / 2.2, PI / 2.2)
		_camera_pivot.rotation.y = _yaw
		_camera.rotation.x = _pitch

	if event.is_action_pressed("toggle_camera"):
		is_first_person = !is_first_person
		_update_camera_position()

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# State detection
	var was_sprinting = Input.is_action_pressed("sprint")
	var was_crouching = Input.is_action_pressed("crouch")
	var was_vent = _is_in_vent
	var old_state = current_state

	if was_vent:
		current_state = State.VENT_CRAWL
	elif was_crouching:
		current_state = State.CROUCH
	elif was_sprinting and velocity.length() > 1.0:
		current_state = State.RUN
	elif velocity.length() > 0.5:
		current_state = State.WALK
	else:
		current_state = State.IDLE

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (_camera_pivot.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed = _get_speed_for_state()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 0.2)
		velocity.z = move_toward(velocity.z, 0, speed * 0.2)

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	# Collision shape update for crouch
	_update_collision_shape()

	# Noise emission
	_update_noise()

	if current_state != old_state:
		state_changed.emit(current_state)

func _get_speed_for_state() -> float:
	match current_state:
		State.VENT_CRAWL: return vent_speed
		State.CROUCH: return crouch_speed
		State.RUN: return run_speed
		State.WALK: return walk_speed
		_: return 0.0

func _update_collision_shape() -> void:
	if not _collision or not _collision.shape:
		return
	var target_height: float
	match current_state:
		State.VENT_CRAWL: target_height = _vent_height
		State.CROUCH: target_height = _crouch_height
		_: target_height = _standing_height

	# Check headbonk before standing up
	if current_state != State.CROUCH and current_state != State.VENT_CRAWL:
		_headbonk.force_raycast_update()
		if _headbonk.is_colliding():
			var hit_y = to_local(_headbonk.get_collision_point()).y
			if hit_y < target_height + 0.2:
				current_state = State.CROUCH
				target_height = _crouch_height

	var cap = _collision.shape as CapsuleShape3D
	if cap:
		cap.height = target_height
		_collision.position.y = target_height / 2

func _update_camera_position() -> void:
	if is_first_person:
		_camera.position = Vector3(0, _standing_height - 0.2, 0)
		_camera.far = 500.0
		_camera_arm.position = Vector3.ZERO
	else:
		_camera.position = Vector3(0, 0, camera_distance)
		_camera_arm.position = Vector3(0, _standing_height, 0)

func _update_noise() -> void:
	match current_state:
		State.RUN:
			noise_radius = 12.0
		State.WALK:
			noise_radius = 3.0
		_:
			noise_radius = 0.0

	if noise_radius > 0:
		noise_emitted.emit(global_position, noise_radius)

func enter_vent() -> void:
	_is_in_vent = true
	current_state = State.VENT_CRAWL

func exit_vent() -> void:
	_is_in_vent = false

func get_visibility() -> float:
	## Returns 0.0 (invisible) to 1.0 (fully visible).
	## Used by StealthSystem for detailed calculation.
	var base = 1.0
	match current_state:
		State.CROUCH: base = 0.3
		State.VENT_CRAWL: base = 0.0
		State.WALK: base = 0.6
		State.RUN: base = 1.0
	return base
