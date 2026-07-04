class_name DistrictPlanner
extends RefCounted

## Assigns a district type to each chunk using spatial hashing + random seed.
## District types: REGULAR (neon) or WEALTHY (tall, dense, high-value).

enum DistrictType { REGULAR, WEALTHY }

var _rng: RandomNumberGenerator
var _grid: Vector2i
var _wealthy_ratio: float = 0.2  # ~20 % of chunks are wealthy

func _init(grid: Vector2i, seed_val: int) -> void:
	_grid = grid
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

func get_district(chunk_pos: Vector2i) -> DistrictType:
	# Spatial hash: deterministic per chunk
	var hash_val: int = chunk_pos.x * 73856093 ^ chunk_pos.y * 19349663
	_rng.seed = hash_val
	if _rng.randf() < _wealthy_ratio:
		return DistrictType.WEALTHY
	return DistrictType.REGULAR

func is_wealthy(chunk_pos: Vector2i) -> bool:
	return get_district(chunk_pos) == DistrictType.WEALTHY
