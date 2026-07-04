extends Node3D

## PickpocketSystem — approach NPCs from behind in stealth to steal loot.
## Success rate based on distance, angle, player visibility, and NPC awareness.

signal pickpocket_success(target: Node3D, items: Array)
signal pickpocket_failed(target: Node3D)
signal pickpocket_detected(target: Node3D)

@export var interaction_distance: float = 1.8
@export var max_angle: float = 45.0           # max angle from behind (degrees)
@export var base_success_rate: float = 0.7
@export var visibility_penalty: float = 0.8   # multiplied by player visibility
@export var detection_range: float = 5.0

var _rng: RandomNumberGenerator

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()

func can_pickpocket(player: Node3D, target: Node3D) -> Dictionary:
	var result = {
		"possible": false,
		"reason": "",
		"success_rate": 0.0,
	}

	if not target.is_in_group("npc"):
		result["reason"] = "Not an NPC"
		return result

	# Distance check
	var dist = player.global_position.distance_to(target.global_position)
	if dist > interaction_distance:
		result["reason"] = "Too far"
		return result

	# Behind check
	var target_forward = -target.global_basis.z
	var to_player = (player.global_position - target.global_position).normalized()
	var angle = rad_to_deg(target_forward.angle_to(to_player))

	if angle > max_angle:
		result["reason"] = "Not behind target"
		return result

	# NPC awareness check
	if target.has_method("is_alerted") and target.is_alerted():
		result["reason"] = "NPC is alert"
		return result

	# Calculate success rate
	var rate = base_success_rate

	# Visibility penalty
	if player.has_method("get_visibility"):
		var vis = player.get_visibility()
		rate -= vis * visibility_penalty

	# Distance bonus (closer = easier)
	rate += (1.0 - dist / interaction_distance) * 0.15

	# Angle bonus (more directly behind = easier)
	rate += (1.0 - angle / max_angle) * 0.1

	rate = clampf(rate, 0.1, 0.95)

	result["possible"] = true
	result["success_rate"] = rate
	return result

func attempt_pickpocket(player: Node3D, target: Node3D) -> Dictionary:
	var check = can_pickpocket(player, target)
	if not check["possible"]:
		pickpocket_failed.emit(target)
		return {"success": false, "reason": check["reason"]}

	var roll_result = _rng.randf()
	var success = roll_result < check["success_rate"]

	if success:
		var items = _steal_items(target)
		pickpocket_success.emit(target, items)
		return {"success": true, "items": items}
	else:
		# Check if detected
		if _rng.randf() < 0.6:  # 60% chance to be caught on failure
			_detect_player(target)
			pickpocket_detected.emit(target)
			return {"success": false, "detected": true}

		pickpocket_failed.emit(target)
		return {"success": false, "detected": false}

func _steal_items(target: Node3D) -> Array:
	var items: Array = []

	# Generate 1-3 random items
	var count = _rng.randi_range(1, 3)
	for i in range(count):
		var rarity = _roll_rarity()
		items.append({
			"name": _get_item_name(rarity),
			"rarity": rarity,
			"value": _calc_value(rarity),
		})

	# Remove from NPC if they have loot
	if target.has_method("remove_loot"):
		for item in items:
			target.remove_loot(item["name"])

	return items

func _roll_rarity() -> int:
	var rarity_roll = _rng.randf()
	if rarity_roll < 0.5: return 0
	elif rarity_roll < 0.8: return 1
	elif rarity_roll < 0.95: return 2
	else: return 3

func _get_item_name(rarity: int) -> String:
	var items = {
		0: ["coins", "pocket_lint", "old_ticket", "gum_wrapper", "receipt"],
		1: ["wallet", "phone", "keys", "headphones", "lighter"],
		2: ["gold_chain", "smart_watch", "encrypted_usb", "fake_id"],
		3: ["diamond_ring", "access_card", "classified_note"],
	}
	var pool = items.get(rarity, items[0])
	return pool[_rng.randi() % pool.size()]

func _calc_value(rarity: int) -> int:
	match rarity:
		0: return _rng.randi_range(1, 15)
		1: return _rng.randi_range(20, 80)
		2: return _rng.randi_range(100, 400)
		3: return _rng.randi_range(500, 2000)
	return 0

func _detect_player(target: Node3D) -> void:
	# Make NPC aware and alert nearby guards
	if target.has_method("set_alerted"):
		target.set_alerted(true)

	# Alert guards
	for guard in get_tree().get_nodes_in_group("guards"):
		if guard.global_position.distance_to(target.global_position) < detection_range:
			if guard.has_method("investigate"):
				guard.investigate(target.global_position)
