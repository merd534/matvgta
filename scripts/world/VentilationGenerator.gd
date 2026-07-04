class_name VentilationGenerator
extends RefCounted

## Procedurally generates ventilation shafts. Uses shared materials.

var _rng: RandomNumberGenerator
var _mat_vent: StandardMaterial3D
var _mat_grate: StandardMaterial3D

func _init(seed_val: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val

	_mat_vent = StandardMaterial3D.new()
	_mat_vent.albedo_color = Color(0.2, 0.2, 0.2)
	_mat_vent.cull_mode = BaseMaterial3D.CULL_BACK

	_mat_grate = StandardMaterial3D.new()
	_mat_grate.albedo_color = Color(0.35, 0.35, 0.35)
	_mat_grate.metallic = 0.8
	_mat_grate.roughness = 0.3

func generate_vents(_building: Node3D, floors: int, footprint: Vector2) -> Node3D:
	var vent_root = Node3D.new()
	vent_root.name = "Ventilation"

	var cs = WorldConfig.VENT_CROSS_SECTION

	for floor_idx in range(floors):
		var y_base = floor_idx * WorldConfig.FLOOR_HEIGHT

		# Only 1 horizontal duct per floor (was 1-3)
		var duct_length = _rng.randf_range(footprint.x * 0.4, footprint.x * 0.8)
		var duct_pos = Vector3(
			_rng.randf_range(1.0, footprint.x - 1.0),
			y_base + WorldConfig.FLOOR_HEIGHT - 0.4,
			_rng.randf_range(1.0, footprint.y - 1.0)
		)
		var duct = _create_duct_simple(
			Vector3(duct_length, cs, cs),
			duct_pos,
			"HDuct_%d" % floor_idx
		)
		vent_root.add_child(duct)

		# Vertical shaft (connects floors) — only one mesh, no inner hollow
		if floor_idx < floors - 1:
			var shaft_pos = Vector3(
				_rng.randf_range(1.5, footprint.x - 1.5),
				y_base + WorldConfig.FLOOR_HEIGHT * 0.5,
				_rng.randf_range(1.5, footprint.y - 1.5)
			)
			var shaft = _create_duct_simple(
				Vector3(cs, WorldConfig.FLOOR_HEIGHT + 0.2, cs),
				shaft_pos,
				"VShaft_%d" % floor_idx
			)
			vent_root.add_child(shaft)

	return vent_root

func _create_duct_simple(size: Vector3, pos: Vector3, node_name: String) -> MeshInstance3D:
	var box = BoxMesh.new()
	box.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = box
	mi.position = pos
	mi.name = node_name
	mi.material_override = _mat_vent
	mi.add_to_group("vent_areas")

	var sb = StaticBody3D.new()
	sb.position = Vector3.ZERO
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	return mi
