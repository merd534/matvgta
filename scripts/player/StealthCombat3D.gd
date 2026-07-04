extends Node3D

## StealthCombat3D — close-quarters non-lethal takedown.
## Approach NPC from behind in Crouch/Vent → prompt → strangle → unconscious.

signal takedown_performed(target: Node3D)
signal takedown_failed(reason: String)
signal body_ready(body: Node3D)

@export var player: NodePath
@export var interaction_distance: float = 2.0
@export var max_angle: float = 50.0
@export var takedown_duration: float = 1.5
@export var detection_range: float = 12.0

var _player: Node3D
var _is_taking_down: bool = false
var _takedown_timer: float = 0.0
var _current_target: Node3D = null
var _unconscious_bodies: Array = []

func _ready() -> void:
	_player = get_node(player) as Node3D if player else get_parent() as Node3D

func _process(delta: float) -> void:
	if _is_taking_down:
		_takedown_timer += delta
		if _takedown_timer >= takedown_duration:
			_complete_takedown()

func can_takedown(target: Node3D) -> Dictionary:
	var result = {"possible": false, "reason": ""}

	if not _player:
		return result

	# Must be crouching or in vent
	var state = _player.get("current_state")
	if state == null:
		return result

	var StateEnum = _player.State
	if state != StateEnum.CROUCH and state != StateEnum.VENT_CRAWL:
		result["reason"] = "Must be crouching"
		return result

	# Distance check
	var dist = _player.global_position.distance_to(target.global_position)
	if dist > interaction_distance:
		result["reason"] = "Too far"
		return result

	# Behind check
	var target_forward = -target.global_basis.z
	var to_player = (_player.global_position - target.global_position).normalized()
	var angle = rad_to_deg(target_forward.angle_to(to_player))

	if angle > max_angle:
		result["reason"] = "Not behind target"
		return result

	# Target must be alive and not already unconscious
	if target.has_method("is_alerted") and target.is_alerted():
		result["reason"] = "Target is alert"
		return result

	if target in _unconscious_bodies:
		result["reason"] = "Already unconscious"
		return result

	# Witness check — are there civilians nearby who would see?
	if _witnesses_present(target):
		result["reason"] = "Witnesses nearby"
		return result

	result["possible"] = true
	return result

func attempt_takedown(target: Node3D) -> bool:
	var check = can_takedown(target)
	if not check["possible"]:
		takedown_failed.emit(check["reason"])
		return false

	_is_taking_down = true
	_takedown_timer = 0.0
	_current_target = target

	# Freeze target
	if target.has_method("set_physics_process"):
		target.set_physics_process(false)

	return true

func _complete_takedown() -> void:
	_is_taking_down = false

	if _current_target and is_instance_valid(_current_target):
		# Make unconscious
		_make_unconscious(_current_target)
		_unconscious_bodies.append(_current_target)
		takedown_performed.emit(_current_target)
		body_ready.emit(_current_target)

	_current_target = null
	_takedown_timer = 0.0

func _make_unconscious(npc: Node3D) -> void:
	# Visual feedback — change color to indicate unconscious
	if npc.has_node("CitizenBody") or npc.has_node("GuardBody"):
		var body = npc.get_node_or_null("CitizenBody") or npc.get_node_or_null("GuardBody")
		if body and body is MeshInstance3D:
			var mat = body.get_surface_override_material(0)
			if mat:
				mat.albedo_color = mat.albedo_color.darkened(0.4)

	# Disable AI
	if npc.has_method("set_process"):
		npc.set_process(false)
	if npc.has_method("set_physics_process"):
		npc.set_physics_process(false)

	# Lay down (rotate to side)
	npc.rotation.z = PI / 2

func is_unconscious(npc: Node3D) -> bool:
	return npc in _unconscious_bodies

func pickup_body(body: Node3D) -> bool:
	if body in _unconscious_bodies:
		_unconscious_bodies.erase(body)
		return true
	return false

func get_unconscious_bodies() -> Array:
	return _unconscious_bodies

func _witnesses_present(target: Node3D) -> bool:
	var civilians = get_tree().get_nodes_in_group("npc")
	for civ in civilians:
		if civ == target:
			continue
		if not civ.is_inside_tree():
			continue
		var dist = civ.global_position.distance_to(target.global_position)
		if dist < detection_range:
			# Check line of sight
			var dir_to_target = (target.global_position - civ.global_position).normalized()
			var civ_forward = -civ.global_basis.z
			var angle = rad_to_deg(civ_forward.angle_to(dir_to_target))
			if angle < 60:  # within civilian's field of view
				return true
	return false
