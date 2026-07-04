extends Node3D

## BodyDisposalSystem — pick up, carry, and hide unconscious bodies
## in ventilation shafts or dumpsters to prevent alarm.

signal body_picked_up(body: Node3D)
signal body_dropped(body: Node3D)
signal body_hidden(body: Node3D, hiding_spot: String)

@export var player: NodePath
@export var pickup_distance: float = 2.0
@export var carry_offset: Vector3 = Vector3(0, 0.5, -0.8)
@export var vent_hide_distance: float = 3.0
@export var dumpster_hide_distance: float = 3.0

var _player: Node3D
var _carried_body: Node3D = null
var _body_original_parent: Node = null
var _stealth_combat: Node = null

func _ready() -> void:
	_player = get_node(player) as Node3D if player else get_parent() as Node3D
	# Find StealthCombat3D sibling
	_stealth_combat = _player.get_node_or_null("StealthCombat3D")

func _process(_delta: float) -> void:
	if _carried_body and is_instance_valid(_carried_body):
		# Body follows player
		_carried_body.global_position = _player.global_position + _player.global_basis * carry_offset
		_carried_body.global_rotation = _player.global_rotation
		# Lay flat
		_carried_body.rotation.z = PI / 2

func can_pickup(body: Node3D) -> bool:
	if not _player:
		return false
	if _carried_body:
		return false
	if not _is_unconscious(body):
		return false
	var dist = _player.global_position.distance_to(body.global_position)
	return dist < pickup_distance

func pickup(body: Node3D) -> bool:
	if not can_pickup(body):
		return false

	_carried_body = body
	_body_original_parent = body.get_parent()

	# Reparent to player so it moves with us
	body.get_parent().remove_child(body)
	_player.add_child(body)

	# Disable collision on the body
	_disable_body_collision(body)

	body_picked_up.emit(body)
	return true

func drop() -> void:
	if not _carried_body:
		return

	var body = _carried_body
	_carried_body = null

	# Reparent back to world
	_player.remove_child(body)
	var world = get_node_or_null("/root/Main")
	if world:
		world.add_child(body)
	else:
		_body_original_parent.add_child(body)

	body.global_position = _player.global_position + _player.global_basis * Vector3(0, 0, -1.0)
	body.global_rotation = _player.global_rotation
	body.rotation.z = PI / 2

	_enable_body_collision(body)
	body_dropped.emit(body)

func try_hide_in_vent() -> bool:
	if not _carried_body:
		return false

	var vent = _find_nearest_vent()
	if not vent:
		return false

	var body = _carried_body
	_carried_body = null

	# Move body into vent
	_player.remove_child(body)
	vent.add_child(body)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO

	_disable_body_collision(body)
	body_hidden.emit(body, "vent")
	return true

func try_hide_in_dumpster() -> bool:
	if not _carried_body:
		return false

	var dumpster = _find_nearest_dumpster()
	if not dumpster:
		return false

	var body = _carried_body
	_carried_body = null

	_player.remove_child(body)
	dumpster.add_child(body)
	body.position = Vector3(0, -0.5, 0)
	body.rotation = Vector3.ZERO

	_disable_body_collision(body)
	body_hidden.emit(body, "dumpster")
	return true

func is_carrying() -> bool:
	return _carried_body != null

func get_carried_body() -> Node3D:
	return _carried_body

func _find_nearest_vent() -> Node3D:
	if not _player:
		return null

	var vents = get_tree().get_nodes_in_group("vent_areas")
	var nearest: Node3D = null
	var min_dist = vent_hide_distance

	for vent in vents:
		if not vent.is_inside_tree():
			continue
		var dist = _player.global_position.distance_to(vent.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = vent

	return nearest

func _find_nearest_dumpster() -> Node3D:
	var dumpsters = get_tree().get_nodes_in_group("dumpsters")
	var nearest: Node3D = null
	var min_dist = dumpster_hide_distance

	for d in dumpsters:
		if not d.is_inside_tree():
			continue
		var dist = _player.global_position.distance_to(d.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = d

	return nearest

func _is_unconscious(body: Node3D) -> bool:
	if _stealth_combat and _stealth_combat.has_method("is_unconscious"):
		return _stealth_combat.is_unconscious(body)
	# Fallback — check visual state
	if body.has_node("CitizenBody") or body.has_node("GuardBody"):
		return body.rotation.z != 0
	return false

func _disable_body_collision(body: Node3D) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
		elif child is StaticBody3D:
			child.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

func _enable_body_collision(body: Node3D) -> void:
	for child in body.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", false)
		elif child is StaticBody3D:
			child.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
