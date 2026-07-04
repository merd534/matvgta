extends Node3D

## StealthSystem — evaluates player visibility based on light exposure.
##
## Uses raycasts to nearby lights (OmniLight3D, SpotLight3D) to calculate
## how exposed the player is. Combined with the player's state for final visibility.

signal stealth_visibility_changed(visibility: float)

@export var player: NodePath
@export var light_scan_interval: float = 0.15
@export var max_light_distance: float = 30.0

var current_visibility: float = 0.0  # 0 = invisible, 1 = fully visible
var _player: Node3D
var _scan_timer: float = 0.0
var _light_cache: Array = []

func _ready() -> void:
	_player = get_node(player) as Node3D if player else get_parent() as Node3D

func _physics_process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= light_scan_interval:
		_scan_timer = 0.0
		_scan_lights()
		_calculate_visibility()

func _scan_lights() -> void:
	_light_cache.clear()
	var lights = get_tree().get_nodes_in_group("stealth_light")
	for light in lights:
		if not light.visible:
			continue
		var dist = _player.global_position.distance_to(light.global_position)
		if dist <= max_light_distance:
			_light_cache.append(light)

func _calculate_visibility() -> void:
	var state_vis = _player.get_visibility()  # 0-1 from player state

	# In vent = always invisible
	if state_vis <= 0.0:
		current_visibility = 0.0
		stealth_visibility_changed.emit(current_visibility)
		return

	var light_exposure = 0.0

	for light in _light_cache:
		var dist = _player.global_position.distance_to(light.global_position)
		var intensity = _get_light_intensity(light)
		var falloff = 1.0 - clampf(dist / max_light_distance, 0.0, 1.0)

		# SpotLight directional check
		if light is SpotLight3D:
			var to_player = (_player.global_position - light.global_position).normalized()
			var light_dir = -light.global_basis.z
			var angle = light_dir.angle_to(to_player)
			if angle > deg_to_rad(light.spot_angle):
				falloff *= 0.05  # outside cone = minimal exposure

		light_exposure += intensity * falloff

	light_exposure = clampf(light_exposure, 0.0, 1.0)

	# Raycast shadow check — is player actually in direct light?
	var shadow_factor = _raycast_shadow_check()
	light_exposure *= shadow_factor

	# Combine state + light
	current_visibility = state_vis * light_exposure
	current_visibility = clampf(current_visibility, 0.0, 1.0)

	stealth_visibility_changed.emit(current_visibility)

func _get_light_intensity(light: Light3D) -> float:
	if light is OmniLight3D:
		return light.light_energy
	elif light is SpotLight3D:
		return light.light_energy
	return light.light_energy

func _raycast_shadow_check() -> float:
	## Raycast upward from player to check if light has clear path.
	if _light_cache.is_empty():
		return 0.1  # ambient only = low exposure

	var space_state = get_world_3d().direct_space_state
	var from = _player.global_position + Vector3(0, 1.0, 0)
	var hits = 0

	for light in _light_cache.slice(0, min(3, _light_cache.size())):
		var query = PhysicsRayQueryParameters3D.create(from, light.global_position)
		query.exclude = [_player.get_rid()]
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			hits += 1

	return float(hits) / max(1, min(3, _light_cache.size()))

func is_in_shadow() -> bool:
	return current_visibility < 0.1

func get_stealth_rating() -> String:
	if current_visibility < 0.05:
		return "HIDDEN"
	elif current_visibility < 0.3:
		return "SHADOWED"
	elif current_visibility < 0.6:
		return "PARTIAL"
	else:
		return "EXPOSED"
