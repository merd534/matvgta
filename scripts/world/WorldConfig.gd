class_name WorldConfig
extends RefCounted

## Pure data class holding world generation parameters.

enum WorldSize { SMALL, MEDIUM, LARGE, EXTRA_LARGE, GIANT }

# Chunk grid dimensions (X × Z in chunks)
const SIZE_MAP: Dictionary = {
	WorldSize.SMALL:       Vector2i(2,  2),
	WorldSize.MEDIUM:      Vector2i(4,  4),
	WorldSize.LARGE:       Vector2i(6,  6),
	WorldSize.EXTRA_LARGE: Vector2i(8,  8),
	WorldSize.GIANT:       Vector2i(12, 12),
}

const CHUNK_SIZE: float = 64.0        # metres per chunk side
const FLOOR_HEIGHT: float = 3.5       # metres per storey
const MIN_BUILDING_FLOORS: int = 2
const MAX_BUILDING_FLOORS_REGULAR: int = 6
const MAX_BUILDING_FLOORS_WEALTHY: int = 8
const BUILDING_FOOTPRINT_MIN: float = 8.0
const BUILDING_FOOTPRINT_MAX: float = 20.0
const STREET_WIDTH: float = 10.0
const VENT_CROSS_SECTION: float = 0.8  # metres

var world_size: WorldSize = WorldSize.MEDIUM
var seed_value: int = 0

var grid_dimensions: Vector2i:
	get: return SIZE_MAP[world_size]

func _init(size: WorldSize = WorldSize.MEDIUM, s: int = 0) -> void:
	world_size = size
	seed_value = s if s != 0 else randi()

func chunk_world_origin(chunk_pos: Vector2i) -> Vector3:
	return Vector3(chunk_pos.x * CHUNK_SIZE, 0.0, chunk_pos.y * CHUNK_SIZE)

func total_chunks() -> int:
	return grid_dimensions.x * grid_dimensions.y
