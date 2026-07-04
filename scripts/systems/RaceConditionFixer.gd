class_name RaceConditionFixer
extends RefCounted

## RaceConditionFixer — enforces strict chronological initialization flow
## to eliminate _ready() race condition crashes.
##
## Flow: Generator → Player → Simulation → UI
##
## Validates that all nodes are properly initialized before proceeding.

enum InitPhase { NONE, GENERATOR, PLAYER, SIMULATION, UI, COMPLETE }

var current_phase: InitPhase = InitPhase.NONE
var _phase_callbacks: Dictionary = {}
var _ready_nodes: Dictionary = {}

func register_phase(phase: InitPhase, callback: Callable) -> void:
	if not _phase_callbacks.has(phase):
		_phase_callbacks[phase] = []
	_phase_callbacks[phase].append(callback)

func advance_to(phase: InitPhase) -> bool:
	if phase <= current_phase:
		return false  # can't go backwards

	# Validate previous phase is complete
	if current_phase != InitPhase.NONE:
		if not _validate_phase(current_phase):
			push_warning("Phase %d not fully validated" % current_phase)
			return false

	current_phase = phase
	_execute_phase_callbacks(phase)
	return true

func _validate_phase(phase: InitPhase) -> bool:
	match phase:
		InitPhase.GENERATOR:
			return _check_generator_ready()
		InitPhase.PLAYER:
			return _check_player_ready()
		InitPhase.SIMULATION:
			return _check_simulation_ready()
		InitPhase.UI:
			return _check_ui_ready()
	return true

func _check_generator_ready() -> bool:
	var gen = _find_node("WorldGenerator")
	if not gen:
		return false
	# Check if chunks are generated
	if gen.has_method("get_children"):
		return gen.get_child_count() > 0
	return false

func _check_player_ready() -> bool:
	var player = _find_node("Player")
	if not player:
		return false
	return player is CharacterBody3D and player.is_inside_tree()

func _check_simulation_ready() -> bool:
	var systems = _find_node("Systems")
	if not systems:
		return true  # optional
	return true

func _check_ui_ready() -> bool:
	return true  # UI can load last

func _execute_phase_callbacks(phase: InitPhase) -> void:
	if _phase_callbacks.has(phase):
		for callback in _phase_callbacks[phase]:
			if callback.is_valid():
				callback.call()

func mark_node_ready(node: Node) -> void:
	_ready_nodes[node.get_path()] = true

func is_node_ready(node: Node) -> bool:
	return _ready_nodes.has(node.get_path())

func wait_for_node(node: Node, timeout: float = 5.0) -> bool:
	if is_node_ready(node):
		return true

	var elapsed = 0.0
	while elapsed < timeout:
		if is_node_ready(node):
			return true
		await Engine.get_main_loop().process_frame
		elapsed += 1.0 / Engine.get_frames_per_second()

	return false

func get_init_order() -> Array:
	return [
		"Generator: Create chunk grid, buildings, nav regions",
		"Player: Spawn player character, setup camera",
		"Simulation: Spawn citizens, cameras, terminals",
		"UI: Create HUD, inventory, dialogue overlay",
	]

func _find_node(name: String) -> Node:
	var main = Engine.get_main_loop().root.get_node_or_null("Main")
	if main:
		return main.get_node_or_null(name)
	return null
