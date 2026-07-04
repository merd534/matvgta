extends Node3D

## WorldGenerator3D — procedural city generator.

signal generation_started
signal chunk_generated(chunk_pos: Vector2i, total: int)
signal generation_finished

@export var world_size: WorldConfig.WorldSize = WorldConfig.WorldSize.MEDIUM
@export var random_seed: int = 0

var config: WorldConfig
var _district_planner: DistrictPlanner
var _generated_chunks: Dictionary = {}

func generate() -> void:
	print("[WorldGen] Starting generation... size=%d" % world_size)

	config = WorldConfig.new(world_size, random_seed if random_seed != 0 else randi())
	_district_planner = DistrictPlanner.new(config.grid_dimensions, config.seed_value)

	for child in get_children():
		child.queue_free()
	_generated_chunks.clear()

	generation_started.emit()

	var chunk_positions = _spiral_order(config.grid_dimensions)
	var total = chunk_positions.size()
	print("[WorldGen] Grid: %s, Total chunks: %d" % [config.grid_dimensions, total])

	for i in range(total):
		var cp = chunk_positions[i]
		var origin = config.chunk_world_origin(cp)
		var chunk_seed = config.seed_value + cp.x * 73856093 + cp.y * 19349663
		var chunk_gen = ChunkGenerator.new(chunk_seed, _district_planner)
		var chunk_node = chunk_gen.generate_chunk(cp, origin)
		add_child(chunk_node)
		_generated_chunks[cp] = chunk_node
		chunk_generated.emit(cp, total)
		if i % 2 == 0:
			await get_tree().process_frame

	print("[WorldGen] All %d chunks created" % _generated_chunks.size())

	# Skip mesh merging
	var async_baker = AsyncNavigationBaker.new()
	async_baker.bake_all_async(self)

	await get_tree().create_timer(1.5).timeout
	print("[WorldGen] Generation complete!")
	generation_finished.emit()

func get_chunk(chunk_pos: Vector2i) -> Node3D:
	return _generated_chunks.get(chunk_pos)

func get_district_type(chunk_pos: Vector2i) -> DistrictPlanner.DistrictType:
	return _district_planner.get_district(chunk_pos)

func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / WorldConfig.CHUNK_SIZE),
		floori(world_pos.z / WorldConfig.CHUNK_SIZE)
	)

func _spiral_order(grid: Vector2i) -> Array:
	var center = grid / 2
	var result: Array = []
	var visited: Dictionary = {}
	var total = grid.x * grid.y
	var queue: Array = [center]
	visited["%d_%d" % [center.x, center.y]] = true
	var dirs = [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]

	while not queue.is_empty() and result.size() < total:
		var pos = queue.pop_front()
		if pos.x >= 0 and pos.x < grid.x and pos.y >= 0 and pos.y < grid.y:
			result.append(pos)
			var neighbors: Array = []
			for d in dirs:
				var n = pos + d
				var key = "%d_%d" % [n.x, n.y]
				if not visited.has(key) and n.x >= 0 and n.x < grid.x and n.y >= 0 and n.y < grid.y:
					visited[key] = true
					neighbors.append(n)
			neighbors.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
			queue.append_array(neighbors)

	return result
