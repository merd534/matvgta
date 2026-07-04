extends Node3D

## BlackMarket — hidden vendor for selling stolen goods.
## Dynamic pricing based on supply/demand and faction reputation.

signal item_sold(item: Dictionary, price: int)
signal item_bought(item: Dictionary, price: int)
signal transaction_failed(reason: String)

@export var vendor_name: String = "Fence"
@export var price_multiplier: float = 1.0
@export var stock_refresh_time: float = 120.0

var _inventory: Array = []
var _sold_history: Dictionary = {}
var _rng: RandomNumberGenerator
var _refresh_timer: float = 0.0

const BASE_PRICES: Dictionary = {
	"wallet": 30,
	"phone": 45,
	"headphones": 20,
	"gold_watch": 800,
	"diamond_ring": 1500,
	"laptop": 200,
	"camera": 150,
	"jewelry": 350,
	"encrypted_disk": 500,
	"fake_id": 400,
	"lockpick_set": 250,
	"night_vision_goggles": 600,
	"blackmail_file": 1000,
	"classified_documents": 2000,
	"master_hacking_tool": 3000,
	"safe_combination": 150,
	"keycard": 100,
	"employee_access_card": 300,
	"security_bypass_tool": 450,
}

const SHOP_STOCK: Array = [
	{"name": "lockpick_set", "rarity": 2, "base_price": 250},
	{"name": "emp_device", "rarity": 3, "base_price": 800},
	{"name": "fake_id", "rarity": 2, "base_price": 400},
	{"name": "night_vision_goggles", "rarity": 3, "base_price": 600},
	{"name": "silencer", "rarity": 3, "base_price": 500},
	{"name": "hacking_tool_basic", "rarity": 1, "base_price": 150},
	{"name": "hacking_tool_advanced", "rarity": 3, "base_price": 700},
	{"name": "keycard_blank", "rarity": 1, "base_price": 100},
	{"name": "body_armor_light", "rarity": 2, "base_price": 350},
]

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()
	_refresh_stock()

func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= stock_refresh_time:
		_refresh_timer = 0.0
		_refresh_stock()

func sell_item(item: Dictionary) -> int:
	var item_name = item.get("name", "")
	var base_price = BASE_PRICES.get(item_name, 10)

	# Dynamic pricing: more sold = lower price
	var sold_count = _sold_history.get(item_name, 0)
	var supply_factor = maxf(0.5, 1.0 - sold_count * 0.05)

	# Rarity bonus
	var rarity = item.get("rarity", 0)
	var rarity_mult = 1.0 + rarity * 0.3

	# Wealthy items fetch more
	var value_bonus = item.get("value", 0) * 0.2

	var final_price = int((base_price * supply_factor * rarity_mult + value_bonus) * price_multiplier)
	final_price = maxi(1, final_price)

	_sold_history[item_name] = sold_count + 1
	item_sold.emit(item, final_price)
	return final_price

func buy_item(item_name: String) -> Dictionary:
	for i in range(_inventory.size()):
		var stock = _inventory[i]
		if stock["name"] == item_name:
			var price = _get_buy_price(stock)
			_inventory.remove_at(i)
			item_bought.emit(stock, price)
			return stock

	transaction_failed.emit("Item not in stock")
	return {}

func _get_buy_price(stock: Dictionary) -> int:
	var base = stock.get("base_price", 100)
	var rarity = stock.get("rarity", 0)
	var rarity_mult = 1.0 + rarity * 0.4
	return int(base * rarity_mult * price_multiplier)

func get_sell_price(item: Dictionary) -> int:
	var item_name = item.get("name", "")
	var base_price = BASE_PRICES.get(item_name, 10)
	var sold_count = _sold_history.get(item_name, 0)
	var supply_factor = maxf(0.5, 1.0 - sold_count * 0.05)
	var rarity = item.get("rarity", 0)
	var rarity_mult = 1.0 + rarity * 0.3
	var value_bonus = item.get("value", 0) * 0.2
	return int((base_price * supply_factor * rarity_mult + value_bonus) * price_multiplier)

func get_shop_inventory() -> Array:
	return _inventory.duplicate()

func get_sellable_items(inventory: Array) -> Array:
	var sellable: Array = []
	for item in inventory:
		if item is Dictionary and item.get("name", "") in BASE_PRICES:
			sellable.append(item)
	return sellable

func _refresh_stock() -> void:
	_inventory.clear()
	var count = _rng.randi_range(3, 6)
	var available: Array = []
	for item in SHOP_STOCK:
		available.append(item.duplicate())
	available.shuffle()

	for i in range(min(count, available.size())):
		_inventory.append(available[i])

func set_reputation(faction: String, value: int) -> void:
	# Higher rep = better prices
	match faction:
		"criminal":
			price_multiplier = 1.0 + value * 0.05
		"police":
			price_multiplier = maxf(0.5, 1.0 - value * 0.03)
