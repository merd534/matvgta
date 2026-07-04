extends Node3D

## VentHighlightSystem — highlights ventilation grates when player enters a building.
## All vents on the current floor glow via Material Emission.
## Player can interact with vents to enter/exit them.

signal vent_entered(vent_area: Area3D)
signal vent_exited(vent_area: Area3D)

@export var player: NodePath
@export var highlight_color: Color = Color(0.2, 0.8, 1.0, 1.0)
@export var highlight_pulse_speed: float = 2.0
@export var interaction_distance: float = 2.5

var _player: Node3D
var _current_building: Node3D = null
var _highlighted_vents: Array = []
var _nearest_vent: MeshInstance3D = null
var _player_in_vent: bool = false
var _time: float = 0.0

func _ready() -> void:
	_player = get_node(player) as Node3D if player else get_parent() as Node3D
	if _player:
		_player.state_changed.connect(_on_player_state_changed)

func _on_player_state_changed(_new_state) -> void:
	pass  # Placeholder — update vent highlight on state change if needed

func _process(delta: float) -> void:
	_time += delta

	# Detect building entry
	_detect_building()

	# Highlight nearest vent for interaction
	_update_nearest_vent()

	# Pulse effect on highlighted vents
	_apply_pulse()

func _detect_building() -> void:
	if not _player:
		return

	# Raycast downward to find floor, then check parent building
	var space_state = get_world_3d().direct_space_state
	var from = _player.global_position
	var to = from + Vector3(0, -3, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)

	var new_building = null
	if result:
		var collider = result["collider"]
		new_building = _find_building_parent(collider)

	if new_building != _current_building:
		_exit_building()
		if new_building:
			_enter_building(new_building)

func _find_building_parent(node: Node) -> Node3D:
	var current = node
	while current:
		if current.name.begins_with("Building_"):
			return current
		current = current.get_parent()
	return null

func _enter_building(building: Node3D) -> void:
	_current_building = building
	_highlight_floor_vents()

func _exit_building() -> void:
	_clear_vent_highlights()
	_current_building = null

func _highlight_floor_vents() -> void:
	if not _current_building or not _player:
		return

	_clear_vent_highlights()

	var player_y = _player.global_position.y
	var floor_idx = floori(player_y / WorldConfig.FLOOR_HEIGHT)

	# Find all vent ducts on this floor (MeshInstance3D in vent_areas group)
	var vents = _current_building.find_children("*", "MeshInstance3D", true, false)
	for vent in vents:
		if not vent.is_in_group("vent_areas"):
			continue

		# Check if vent is on the same floor
		var vent_y = vent.global_position.y
		var vent_floor = floori(vent_y / WorldConfig.FLOOR_HEIGHT)
		if vent_floor == floor_idx:
			_apply_highlight(vent)
			_highlighted_vents.append(vent)

func _clear_vent_highlights() -> void:
	for vent in _highlighted_vents:
		_remove_highlight(vent)
	_highlighted_vents.clear()

func _apply_highlight(vent: MeshInstance3D) -> void:
	# Vent IS the MeshInstance3D — apply highlight directly
	var mat = vent.get_surface_override_material(0)
	if not mat:
		mat = vent.mesh.surface_get_material(0) if vent.mesh else null
	if mat is StandardMaterial3D:
		mat.emission_enabled = true
		mat.emission = highlight_color
		mat.emission_energy_multiplier = 0.0  # will pulse
	elif not mat:
		var new_mat = StandardMaterial3D.new()
		new_mat.emission_enabled = true
		new_mat.emission = highlight_color
		new_mat.emission_energy_multiplier = 0.0
		vent.set_surface_override_material(0, new_mat)

func _remove_highlight(vent: MeshInstance3D) -> void:
	var mat = vent.get_surface_override_material(0)
	if mat is StandardMaterial3D:
		mat.emission_energy_multiplier = 0.0
		mat.emission_enabled = false

func _apply_pulse() -> void:
	var pulse = (sin(_time * highlight_pulse_speed * PI) + 1.0) * 0.5
	var energy = pulse * 3.0
	for vent in _highlighted_vents:
		if vent is MeshInstance3D:
			var mat = vent.get_surface_override_material(0)
			if mat is StandardMaterial3D:
				mat.emission_energy_multiplier = energy

func _update_nearest_vent() -> void:
	if not _player:
		return

	_nearest_vent = null
	var min_dist = interaction_distance

	for vent in _highlighted_vents:
		var dist = _player.global_position.distance_to(vent.global_position)
		if dist < min_dist:
			min_dist = dist
			_nearest_vent = vent

func can_interact_with_vent() -> bool:
	return _nearest_vent != null

func interact_with_vent() -> void:
	if not _nearest_vent or not _player:
		return

	if _player_in_vent:
		_exit_vent()
	else:
		_enter_vent(_nearest_vent)

func _enter_vent(vent: MeshInstance3D) -> void:
	_player_in_vent = true
	_player.global_position = vent.global_position + Vector3(0, 0.3, 0)
	if _player.has_method("enter_vent"):
		_player.enter_vent()
	vent_entered.emit(vent)

func _exit_vent() -> void:
	_player_in_vent = false
	if _player.has_method("exit_vent"):
		_player.exit_vent()
	vent_exited.emit(null)

func is_in_vent() -> bool:
	return _player_in_vent
