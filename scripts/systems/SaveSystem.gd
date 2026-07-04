extends Node

## SaveSystem — serialize world seed, player position, inventory, money, NPC states.
## Format: ConfigFile for robustness.

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(error: String)

const MAX_SLOTS: int = 5
const SAVE_DIR: String = "user://saves/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_game(slot: int = 0) -> bool:
	var path = _get_save_path(slot)
	var cfg = ConfigFile.new()

	# World state — read seed from existing generator, don't create new one
	var gen = get_node_or_null("/root/Main/WorldGenerator")
	var seed_val = 0
	if gen and gen.get("config") and gen.config:
		seed_val = gen.config.seed_value
	cfg.set_value("world", "seed", seed_val)
	cfg.set_value("world", "size", 1)

	# Player state
	var player = _get_player()
	if player:
		cfg.set_value("player", "position", player.global_position)
		cfg.set_value("player", "rotation", player.rotation)
		cfg.set_value("player", "money", _get_inventory().get_money() if _get_inventory() else 0)

	# Inventory
	var inv = _get_inventory()
	if inv:
		cfg.set_value("inventory", "items", inv.get_items())

	# Wanted level
	var director = _get_police_director()
	if director:
		cfg.set_value("police", "wanted_stars", director.get_wanted_stars())

	# NPC states
	var citizens = get_tree().get_nodes_in_group("npc")
	var citizen_data = {}
	for c in citizens:
		if c.has_method("get_state_name"):
			citizen_data[c.citizen_name] = {
				"position": c.global_position,
				"state": c.get_state_name(),
			}
	cfg.set_value("npcs", "citizens", citizen_data)

	# Save
	var error = cfg.save(path)
	if error != OK:
		save_failed.emit("Error %d" % error)
		return false

	save_completed.emit(slot)
	return true

func load_game(slot: int = 0) -> bool:
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		save_failed.emit("Save file not found")
		return false

	var cfg = ConfigFile.new()
	var error = cfg.load(path)
	if error != OK:
		save_failed.emit("Load error %d" % error)
		return false

	# Apply player state
	var player = _get_player()
	if player and cfg.has_section_key("player", "position"):
		player.global_position = cfg.get_value("player", "position", Vector3.ZERO)
		player.rotation = cfg.get_value("player", "rotation", Vector3.ZERO)

	# Apply inventory
	var inv = _get_inventory()
	if inv:
		if cfg.has_section_key("inventory", "items"):
			var items = cfg.get_value("inventory", "items", [])
			for item in items:
				inv.add_item(item)
		if cfg.has_section_key("player", "money"):
			inv.add_money(cfg.get_value("player", "money", 0))

	# Apply wanted level
	var director = _get_police_director()
	if director and cfg.has_section_key("police", "wanted_stars"):
		var stars = cfg.get_value("police", "wanted_stars", 0)
		for i in range(stars):
			director.report_crime(0, player.global_position if player else Vector3.ZERO, 0.1)

	load_completed.emit(slot)
	return true

func delete_save(slot: int = 0) -> void:
	var path = _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_save_info(slot: int) -> Dictionary:
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false}

	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return {"exists": false}

	return {
		"exists": true,
		"position": cfg.get_value("player", "position", Vector3.ZERO),
		"money": cfg.get_value("player", "money", 0),
	}

func has_saves() -> bool:
	for i in range(MAX_SLOTS):
		if FileAccess.file_exists(_get_save_path(i)):
			return true
	return false

func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.cfg" % slot

func _get_player() -> Node3D:
	var main = get_node_or_null("/root/Main")
	if main:
		return main.get_node_or_null("Player")
	return null

func _get_inventory() -> Node:
	var main = get_node_or_null("/root/Main")
	if main:
		var hud_layer = main.get_node_or_null("HUDLayer")
		if hud_layer:
			var hud = hud_layer.get_node_or_null("HUD")
			if hud:
				return hud.get_node_or_null("Inventory")
	return null

func _get_police_director() -> Node:
	var main = get_node_or_null("/root/Main")
	if main:
		var systems = main.get_node_or_null("Systems")
		if systems:
			# Try both names — PoliceDirector3D or PoliceDirector
			var dir = systems.get_node_or_null("PoliceDirector3D")
			if dir:
				return dir
			return systems.get_node_or_null("PoliceDirector")
	return null
