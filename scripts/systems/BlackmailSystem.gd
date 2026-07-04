extends Node

## BlackmailSystem — finding blackmail documents in wealthy safes
## and using them in the dialogue system for extortion.

signal blackmail_found(document: Dictionary)
signal blackmail_used(target: String, document: Dictionary)

var _documents: Array = []
var _rng: RandomNumberGenerator

const BLACKMAIL_TYPES: Array = [
	{"type": "financial", "name": "Offshore Account Records", "extort_value": 2000},
	{"type": "affair", "name": "Photographic Evidence", "extort_value": 1500},
	{"type": "corruption", "name": "Bribery Documents", "extort_value": 3000},
	{"type": "embezzlement", "name": "Embezzlement Ledger", "extort_value": 2500},
	{"type": "illegal_activity", "name": "Illegal Operations Files", "extort_value": 4000},
	{"type": "tax_evasion", "name": "Tax Evasion Proof", "extort_value": 2000},
	{"type": "insider_trading", "name": "Insider Trading Records", "extort_value": 3500},
]

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()

func generate_blackmail() -> Dictionary:
	var template = BLACKMAIL_TYPES[_rng.randi() % BLACKMAIL_TYPES.size()]
	var doc = {
		"type": template["type"],
		"name": template["name"],
		"id": "blackmail_%d" % _rng.randi(),
		"used": false,
		"extort_value": _rng.randi_range(
			int(template["extort_value"] * 0.7),
			int(template["extort_value"] * 1.3)
		),
	}
	_documents.append(doc)
	blackmail_found.emit(doc)
	return doc

func use_blackmail(doc_id: String, target_name: String) -> Dictionary:
	for doc in _documents:
		if doc["id"] == doc_id and not doc["used"]:
			doc["used"] = true
			blackmail_used.emit(target_name, doc)
			return {
				"success": true,
				"payment": doc["extort_value"],
				"message": "Extorted $%d from %s" % [doc["extort_value"], target_name]
			}

	return {"success": false, "message": "Document not found or already used"}

func get_unused_documents() -> Array:
	return _documents.filter(func(d): return not d["used"])

func has_unused_blackmail() -> bool:
	return get_unused_documents().size() > 0

func get_blackmail_for_target(target_name: String) -> Array:
	return _documents.filter(func(d): return not d["used"])
