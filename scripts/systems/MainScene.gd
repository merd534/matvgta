extends Node3D

## MainScene — root node manager with proper cleanup.

@onready var world_gen = $WorldGenerator
@onready var player = $Player
@onready var systems = $Systems

var _menu: Node3D
var _hud: Control
var _inventory: Control
var _dialogue: Control
var _save_system: Node
var _asset_loader: Node
var _audio_system: Node
var _black_market: Node3D
var _wanted_ui: Control
var _initialized: bool = false
var _chunk_count: int = 0
var _total_chunks: int = 0

func _ready() -> void:
	if world_gen:
		world_gen.set_script(null)
	_create_subsystems()
	_show_menu()

func _create_subsystems() -> void:
	_save_system = load("res://scripts/systems/SaveSystem.gd").new()
	_save_system.name = "SaveSystem"
	add_child(_save_system)

	_asset_loader = load("res://scripts/systems/AssetLoader.gd").new()
	_asset_loader.name = "AssetLoader"
	add_child(_asset_loader)

	_audio_system = load("res://scripts/systems/DynamicAudio.gd").new()
	_audio_system.name = "DynamicAudio"
	add_child(_audio_system)

	_black_market = load("res://scripts/systems/BlackMarket.gd").new()
	_black_market.name = "BlackMarket"
	_black_market.position = Vector3(-50, 0, -50)
	add_child(_black_market)

	_dialogue = load("res://scripts/systems/DialogueSystem.gd").new()
	_dialogue.name = "DialogueSystem"
	var dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "DialogueLayer"
	add_child(dialogue_layer)
	dialogue_layer.add_child(_dialogue)

func _show_menu() -> void:
	_menu = load("res://scripts/systems/MainMenu3D.gd").new()
	_menu.name = "MainMenu"
	add_child(_menu)
	_menu.new_game_selected.connect(_on_new_game)
	_menu.load_game_selected.connect(_on_load_game)
	_menu.exit_requested.connect(_on_exit)

func _on_new_game(world_size: int) -> void:
	print("[MainScene] New game requested, size=%d" % world_size)
	_menu.show_loading()
	_chunk_count = 0
	_total_chunks = 0

	# Clean up old game state but keep menu alive for progress
	for child in systems.get_children():
		child.queue_free()
	if _hud:
		var hud_layer = _hud.get_parent()
		_hud.queue_free()
		_hud = null
		_inventory = null
		_wanted_ui = null
		if hud_layer and hud_layer is CanvasLayer:
			hud_layer.queue_free()
	for child in world_gen.get_children():
		child.queue_free()

	world_gen.set_script(load("res://scripts/world/WorldGenerator3D.gd"))
	world_gen.set("world_size", world_size as WorldConfig.WorldSize)
	world_gen.set("random_seed", randi())

	world_gen.generation_finished.connect(_on_world_generated, CONNECT_ONE_SHOT)
	if world_gen.chunk_generated.is_connected(_on_chunk_generated):
		world_gen.chunk_generated.disconnect(_on_chunk_generated)
	world_gen.chunk_generated.connect(_on_chunk_generated)
	world_gen.generate()

func _cleanup_game_state() -> void:
	for child in systems.get_children():
		child.queue_free()

	# Free HUD and its CanvasLayer
	if _hud:
		var hud_layer = _hud.get_parent()
		_hud.queue_free()
		_hud = null
		_inventory = null
		_wanted_ui = null
		if hud_layer and hud_layer is CanvasLayer:
			hud_layer.queue_free()

	# Free menu (3D node, no CanvasLayer)
	if _menu:
		_menu.queue_free()
		_menu = null

	# Free world gen children
	for child in world_gen.get_children():
		child.queue_free()

	_initialized = false

func _on_chunk_generated(_chunk_pos: Vector2i, total: int) -> void:
	_total_chunks = total
	_chunk_count += 1
	if _menu and _menu.has_method("update_progress"):
		var progress = float(_chunk_count) / float(total) * 0.6
		_menu.update_progress(progress)

func _on_world_generated() -> void:
	print("[MainScene] World generated! Setting up game...")
	if _menu and _menu.has_method("update_progress"):
		_menu.update_progress(1.0)
	if player:
		var old_player = player
		# Remove old player
		old_player.get_parent().remove_child(old_player)
		old_player.queue_free()
		# Create new player with script — _ready() runs when added to tree
		player = CharacterBody3D.new()
		player.name = "Player"
		player.set_script(load("res://scripts/player/Player3D.gd"))
		player.global_position = Vector3(32, 2, 32)
		add_child(player)

	_setup_simulation()

	if _menu:
		_menu.queue_free()
		_menu = null

	_create_hud()
	_initialized = true
	print("[MainScene] Setup complete!")

func _on_load_game() -> void:
	if _save_system:
		_save_system.load_game(0)

func _on_exit() -> void:
	get_tree().quit()

func _setup_simulation() -> void:
	_spawn_citizens()
	_spawn_cameras()
	_spawn_terminals()

	# Create alarm system and register all cameras
	var alarm = load("res://scripts/systems/AlarmSystem.gd").new()
	alarm.name = "AlarmSystem"
	systems.add_child(alarm)
	for cam in systems.get_children():
		if cam.has_signal("player_spotted") and cam != alarm:
			alarm.register_camera(cam)

	# Create police director
	var director = load("res://scripts/systems/PoliceDirector3D.gd").new()
	director.name = "PoliceDirector3D"
	systems.add_child(director)

	# Create blackmail system
	var blackmail = load("res://scripts/systems/BlackmailSystem.gd").new()
	blackmail.name = "BlackmailSystem"
	systems.add_child(blackmail)

func _spawn_citizens() -> void:
	var buildings = world_gen.find_children("Building_*", "Node3D", true, false)
	# Cap at 15 citizens (was 30)
	var count = min(buildings.size(), 15)
	for i in range(count):
		var building = buildings[i]
		# Determine wealth from district planner using building position
		var chunk_pos = world_gen.world_to_chunk(building.global_position)
		var wealthy = false
		if world_gen._district_planner:
			wealthy = world_gen._district_planner.is_wealthy(chunk_pos)
		var citizen = load("res://scripts/systems/CitizenAI.gd").new()
		citizen.citizen_name = "Citizen_%d" % i
		citizen.home_position = building.global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		citizen.work_position = citizen.home_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		citizen.is_wealthy = wealthy
		citizen.position = citizen.home_position
		systems.add_child(citizen)

func _spawn_cameras() -> void:
	var buildings = world_gen.find_children("Building_*", "Node3D", true, false)
	var cam_count = 0
	# Cap at 20 cameras total (was unlimited)
	for building in buildings:
		if cam_count >= 20:
			break
		if randf() < 0.3:
			var cam = load("res://scripts/systems/SecurityCamera.gd").new()
			cam.position = building.global_position + Vector3(randf_range(-3, 3), 2.5, randf_range(-3, 3))
			cam.add_to_group("security_cameras")
			systems.add_child(cam)
			cam_count += 1

func _spawn_terminals() -> void:
	var buildings = world_gen.find_children("Building_*", "Node3D", true, false)
	var term_count = 0
	# Cap at 10 terminals total (was unlimited)
	for building in buildings:
		if term_count >= 10:
			break
		if randf() < 0.4:
			var terminal = load("res://scripts/systems/HackingTerminal.gd").new()
			terminal.position = building.global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))
			systems.add_child(terminal)
			term_count += 1

func _create_hud() -> void:
	# HUD also needs CanvasLayer to render over 3D
	var layer = CanvasLayer.new()
	layer.name = "HUDLayer"
	add_child(layer)

	_hud = load("res://scripts/systems/PlayerHUD.gd").new()
	_hud.name = "HUD"
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.player = player.get_path() if player else NodePath("")
	layer.add_child(_hud)

	_inventory = load("res://scripts/systems/InventorySystem.gd").new()
	_inventory.name = "Inventory"
	_inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_inventory)

	_wanted_ui = load("res://scripts/systems/WantedUI.gd").new()
	_wanted_ui.name = "WantedUI"
	_hud.add_child(_wanted_ui)
	# Connect to PoliceDirector if it exists
	var director = systems.get_node_or_null("PoliceDirector3D")
	if director:
		_wanted_ui._director = director
		if director.has_signal("wanted_level_changed"):
			director.wanted_level_changed.connect(_wanted_ui._on_wanted_changed)

func _input(event: InputEvent) -> void:
	if not _initialized:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if _inventory:
			_inventory.toggle()

func save_game() -> void:
	if _save_system:
		_save_system.save_game(0)

func auto_save() -> void:
	save_game()
