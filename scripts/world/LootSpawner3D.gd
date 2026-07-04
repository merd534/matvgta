class_name LootSpawner3D
extends Node3D

## LootSpawner3D — spawns randomized loot containers throughout the world.
## Containers: safes (wealthy only, require hacking), desks, drawers, cabinets.

signal loot_collected(container_name: String, items: Array)

@export var interaction_distance: float = 2.0
@export var loot_seed: int = 0

var _loot_table: LootTable
var _containers: Array = []

func _ready() -> void:
	_loot_table = LootTable.new(loot_seed if loot_seed != 0 else randi())

func register_container(container: Node3D, is_wealthy: bool, container_type: String) -> void:
	_containers.append({
		"node": container,
		"wealthy": is_wealthy,
		"type": container_type,
		"loot": _loot_table.roll(is_wealthy),
		"collected": false,
		"requires_hacking": is_wealthy and container_type == "safe",
	})

func spawn_container(pos: Vector3, is_wealthy: bool, container_type: String, container_name: String) -> Node3D:
	var container = _create_container(container_type, container_name)
	container.position = pos
	add_child(container)
	register_container(container, is_wealthy, container_type)
	return container

func spawn_containers_in_building(building: Node3D, is_wealthy: bool) -> void:
	# Buildings don't have named Floor_/Room_ children.
	# Spawn containers directly under the building at random positions.
	var child_count = building.get_child_count()
	if child_count == 0:
		return
	var count = randi_range(1, 3) if is_wealthy else randi_range(0, 2)
	for i in range(count):
		var offset = Vector3(
			randf_range(-2.0, 2.0),
			0.3,
			randf_range(-2.0, 2.0)
		)
		var c_type = _random_container_type(is_wealthy)
		var c_name = "%s_%d" % [building.name, i]
		spawn_container(building.global_position + offset, is_wealthy, c_type, c_name)

func _random_container_type(wealthy: bool) -> String:
	var types = ["desk", "drawer", "cabinet"]
	if wealthy:
		types.append("safe")
		types.append("safe")
	return types[randi() % types.size()]

func _create_container(container_type: String, container_name: String) -> Node3D:
	var root = Node3D.new()
	root.name = "Container_%s_%s" % [container_type, container_name]

	var mesh: MeshInstance3D
	match container_type:
		"safe":
			mesh = _create_safe()
		"desk":
			mesh = _create_desk()
		"drawer":
			mesh = _create_drawer()
		"cabinet":
			mesh = _create_cabinet()
		_:
			mesh = _create_desk()

	root.add_child(mesh)

	# Interaction area
	var area = Area3D.new()
	area.name = "InteractArea"
	area.collision_layer = 0
	area.collision_mask = 1
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	col.shape = shape
	area.add_child(col)
	root.add_child(area)

	# Label
	var label = Label3D.new()
	label.text = container_name
	label.font_size = 16
	label.position = Vector3(0, 1.2, 0)
	label.visible = false
	root.add_child(label)

	return root

func _create_safe() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.5)
	mi.mesh = box
	mi.position = Vector3(0, 0.3, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.28)
	mat.metallic = 0.9
	mat.roughness = 0.2
	mi.material_override = mat

	var sb = StaticBody3D.new()
	sb.position = Vector3.ZERO
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	return mi

func _create_desk() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.2, 0.05, 0.6)
	mi.mesh = box
	mi.position = Vector3(0, 0.75, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.25, 0.15)
	mi.material_override = mat

	var sb = StaticBody3D.new()
	sb.position = Vector3.ZERO
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	return mi

func _create_drawer() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.5, 0.4, 0.4)
	mi.mesh = box
	mi.position = Vector3(0, 0.5, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.32)
	mi.material_override = mat

	var sb = StaticBody3D.new()
	sb.position = Vector3.ZERO
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	return mi

func _create_cabinet() -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 1.8, 0.5)
	mi.mesh = box
	mi.position = Vector3(0, 0.9, 0)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.28, 0.3)
	mi.material_override = mat

	var sb = StaticBody3D.new()
	sb.position = Vector3.ZERO
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	return mi

func get_nearest_container(pos: Vector3) -> Dictionary:
	var nearest = {}
	var min_dist = interaction_distance

	for c in _containers:
		if c["collected"]:
			continue
		var dist = pos.distance_to(c["node"].global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = c

	return nearest

func collect_loot(container_data: Dictionary) -> Array:
	if container_data.is_empty() or container_data.get("collected", true):
		return []

	container_data["collected"] = true
	var items = container_data["loot"]
	loot_collected.emit(container_data["node"].name, items)
	return items
