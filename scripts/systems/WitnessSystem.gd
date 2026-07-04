extends Node3D

## WitnessSystem — social stealth & crowd reaction.
## If a takedown or crime is seen by civilians, they panic, flee, call police.
## Increases Wanted level rapidly and triggers area-wide alert.

signal witness_saw_crime(witness: Node3D, crime_type: String)
signal panic_started(position: Vector3, radius: float)
signal police_called(position: Vector3)

@export var player: NodePath
@export var detection_range: float = 15.0
@export var field_of_view: float = 70.0
@export var panic_flee_distance: float = 30.0

var _police_director: Node = null
var _panicked_civilians: Array = []

func _ready() -> void:
	# Find police director
	var systems = get_node_or_null("/root/Main/Systems")
	if systems:
		_police_director = systems.get_node_or_null("PoliceDirector3D")
		if not _police_director:
			_police_director = systems.get_node_or_null("PoliceDirector")

func report_crime(crime_type: String, crime_position: Vector3, severity: float = 1.0) -> void:
	## Call this when any crime occurs (takedown, theft, etc).
	var witnesses = _scan_witnesses(crime_position)

	if witnesses.is_empty():
		return

	# Each witness reacts
	for witness in witnesses:
		_trigger_panic(witness, crime_position)

	# Escalate wanted level per witness
	if _police_director:
		var crime = _resolve_crime_type(crime_type)
		_police_director.report_crime(crime, crime_position, severity * witnesses.size())

	police_called.emit(crime_position)
	panic_started.emit(crime_position, panic_flee_distance)

func report_takedown(takedown_position: Node3D) -> void:
	## Specific call for stealth takedowns.
	report_crime("takedown", takedown_position.global_position, 2.0)

func _scan_witnesses(crime_pos: Vector3) -> Array:
	var witnesses: Array = []
	var civilians = get_tree().get_nodes_in_group("npc")

	for civ in civilians:
		if not civ.is_inside_tree():
			continue
		if civ.has_method("is_alerted") and civ.is_alerted():
			continue

		var dist = civ.global_position.distance_to(crime_pos)
		if dist > detection_range:
			continue

		# Field of view check
		var dir_to_crime = (crime_pos - civ.global_position).normalized()
		var civ_forward = -civ.global_basis.z
		var angle = rad_to_deg(civ_forward.angle_to(dir_to_crime))

		if angle < field_of_view / 2:
			if _has_line_of_sight(civ.global_position + Vector3(0, 1.5, 0), crime_pos + Vector3(0, 1, 0)):
				witnesses.append(civ)

	return witnesses

func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	return result.is_empty() or (result["collider"] as Node3D).is_in_group("npc")

func _trigger_panic(witness: Node3D, crime_pos: Vector3) -> void:
	if witness in _panicked_civilians:
		return

	_panicked_civilians.append(witness)
	witness_saw_crime.emit(witness, "witnessed_crime")

	# Set NPC to alert/panic state
	if witness.has_method("set_alerted"):
		witness.set_alerted(true)

	# Visual panic indicator
	_show_panic_icon(witness)

	# Make them flee
	var flee_dir = (witness.global_position - crime_pos).normalized()
	var flee_target = witness.global_position + flee_dir * panic_flee_distance

	if witness.has_method("_flee"):
		witness._target_pos = flee_target
		witness._set_state(witness.State.FLEE)

	# Remove from panicked list after some time
	await get_tree().create_timer(20.0).timeout
	if is_instance_valid(witness):
		_panicked_civilians.erase(witness)

func _show_panic_icon(witness: Node3D) -> void:
	var icon = Label3D.new()
	icon.text = "!"
	icon.font_size = 48
	icon.position = Vector3(0, 2.5, 0)
	icon.modulate = Color(1.0, 0.0, 0.0)
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	witness.add_child(icon)

	# Remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(icon):
		icon.queue_free()

func _resolve_crime_type(crime_name: String) -> int:
	# Map string to CrimeType enum value
	match crime_name:
		"takedown": return 2  # GUARD_KNOCKOUT
		"theft": return 3     # THEFT
		"vent": return 4      # VENT_WITNESSED
		_: return 0           # CAMERA_ALERT

func get_panic_level() -> int:
	return _panicked_civilians.size()

func clear_panic() -> void:
	for civ in _panicked_civilians:
		if is_instance_valid(civ) and civ.has_method("set_alerted"):
			civ.set_alerted(false)
	_panicked_civilians.clear()
