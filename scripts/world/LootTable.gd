class_name LootTable
extends RefCounted

## LootTable — defines item pools and drop chances per district tier.

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_WEIGHTS: Dictionary = {
	Rarity.COMMON:    50,
	Rarity.UNCOMMON:  30,
	Rarity.RARE:      15,
	Rarity.EPIC:       4,
	Rarity.LEGENDARY:  1,
}

const COMMON_ITEMS: Array = [
	"paper", "pen", "old_phone", "coins", "usb_drive",
	"energy_drink", "cigarettes", "lighter", "gum", "receipt",
]

const UNCOMMON_ITEMS: Array = [
	"wallet", "keycard", "smartphone", "headphones", "sunglasses",
	"watch", "portable_charger", "flash_drive", "notebook", "badge",
]

const RARE_ITEMS: Array = [
	"laptop", "jewelry", "camera", "encrypted_disk", "fake_id",
	"lockpick_set", "suppressed_magazine", "night_vision_goggles",
]

const EPIC_ITEMS: Array = [
	"gold_watch", "diamond_ring", "safe_combination", "blackmail_file",
	"employee_access_card", "security_bypass_tool", "prototype_device",
]

const LEGENDARY_ITEMS: Array = [
	"ceo_keycard", "classified_documents", "encrypted_evidence",
	"rare_artifact", "master_hacking_tool",
]

var _rng: RandomNumberGenerator

func _init(seed_val: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val if seed_val != 0 else randi()

func roll(is_wealthy: bool) -> Array:
	var item_count = _rng.randi_range(1, 3) if is_wealthy else _rng.randi_range(0, 2)
	var items: Array = []

	for i in range(item_count):
		var rarity = _roll_rarity(is_wealthy)
		var item = _get_random_item(rarity)
		items.append({
			"name": item,
			"rarity": rarity,
			"value": _calc_value(rarity),
		})

	return items

func _roll_rarity(wealthy: bool) -> Rarity:
	# Wealthy zones get better drops
	var weights = RARITY_WEIGHTS.duplicate()
	if wealthy:
		weights[Rarity.RARE] *= 2
		weights[Rarity.EPIC] *= 3
		weights[Rarity.LEGENDARY] *= 5
	else:
		weights[Rarity.EPIC] = 0
		weights[Rarity.LEGENDARY] = 0

	var total = 0
	for w in weights.values():
		total += w

	var roll_result = _rng.randi_range(0, total - 1)
	var cumulative = 0
	for rarity in weights:
		cumulative += weights[rarity]
		if roll_result < cumulative:
			return rarity

	return Rarity.COMMON

func _get_random_item(rarity: Rarity) -> String:
	var pool: Array
	match rarity:
		Rarity.COMMON:    pool = COMMON_ITEMS
		Rarity.UNCOMMON:  pool = UNCOMMON_ITEMS
		Rarity.RARE:      pool = RARE_ITEMS
		Rarity.EPIC:      pool = EPIC_ITEMS
		Rarity.LEGENDARY: pool = LEGENDARY_ITEMS
		_: pool = COMMON_ITEMS
	return pool[_rng.randi() % pool.size()]

func _calc_value(rarity: Rarity) -> int:
	match rarity:
		Rarity.COMMON:    return _rng.randi_range(5, 25)
		Rarity.UNCOMMON:  return _rng.randi_range(30, 100)
		Rarity.RARE:      return _rng.randi_range(150, 500)
		Rarity.EPIC:      return _rng.randi_range(600, 2000)
		Rarity.LEGENDARY: return _rng.randi_range(3000, 10000)
	return 0
