class_name ChunkGenerator
extends RefCounted

## Generates detailed chunks: roads, buildings, street furniture, lighting.

var _building_gen: BuildingGenerator
var _vent_gen: VentilationGenerator
var _district_planner: DistrictPlanner
var _factory: ProceduralAssetFactory
var _chunk_size: float
var _rng: RandomNumberGenerator

var _mat_ground: StandardMaterial3D
var _mat_road: StandardMaterial3D
var _mat_sidewalk: StandardMaterial3D
var _mat_road_line: StandardMaterial3D

func _init(seed_val: int, district_planner: DistrictPlanner) -> void:
	_district_planner = district_planner
	_chunk_size = WorldConfig.CHUNK_SIZE
	_building_gen = BuildingGenerator.new(seed_val)
	_vent_gen = VentilationGenerator.new(seed_val + 1000)
	_factory = ProceduralAssetFactory.new(seed_val + 2000)
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val + 3000

	_mat_ground = _m(Color(0.25, 0.25, 0.3))
	_mat_road = _m(Color(0.15, 0.15, 0.18))
	_mat_sidewalk = _m(Color(0.3, 0.3, 0.33))
	_mat_road_line = _me(Color(0.3, 0.3, 0.1), Color(0.8, 0.8, 0.2), 0.5)

func generate_chunk(chunk_pos: Vector2i, chunk_origin: Vector3) -> Node3D:
	var root = Node3D.new()
	root.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]
	root.position = chunk_origin

	var nav = NavigationRegion3D.new()
	nav.name = "NavRegion"
	var nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.5
	nav.navigation_mesh = nav_mesh
	root.add_child(nav)

	var wealthy = _district_planner.is_wealthy(chunk_pos)
	var cs = _chunk_size
	var road_w = WorldConfig.STREET_WIDTH

	# Ground collision — StaticBody3D so player and NPCs don't fall through
	var ground_body = StaticBody3D.new()
	ground_body.name = "GroundCollider"
	ground_body.position = Vector3(cs / 2, -0.1, cs / 2)
	var ground_col = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(cs, 0.2, cs)
	ground_col.shape = ground_shape
	ground_body.add_child(ground_col)
	root.add_child(ground_body)

	# Ground
	root.add_child(_box(Vector3(cs, 0.2, cs), Vector3(cs / 2, -0.1, cs / 2), _mat_ground))

	# Roads — cross through center
	root.add_child(_box(Vector3(cs, 0.25, road_w), Vector3(cs / 2, 0.01, cs / 2), _mat_road))
	root.add_child(_box(Vector3(road_w, 0.25, cs), Vector3(cs / 2, 0.01, cs / 2), _mat_road))

	# Road center lines (dashed)
	for i in range(int(cs / 4)):
		var lx = i * 4.0
		root.add_child(_box(Vector3(2.0, 0.01, 0.15), Vector3(lx, 0.15, cs / 2), _mat_road_line))
		root.add_child(_box(Vector3(0.15, 0.01, 2.0), Vector3(cs / 2, 0.15, lx), _mat_road_line))

	# Sidewalks
	var sw = 2.0
	for side in [-1, 1]:
		root.add_child(_box(Vector3(cs, 0.3, sw), Vector3(cs / 2, 0.05, cs / 2 + side * (road_w / 2 + sw / 2)), _mat_sidewalk))
		root.add_child(_box(Vector3(sw, 0.3, cs), Vector3(cs / 2 + side * (road_w / 2 + sw / 2), 0.05, cs / 2), _mat_sidewalk))

	# Buildings — 2×2 in quadrants
	var cell = cs / 2.0
	var margin = road_w * 0.5 + sw
	var bid = chunk_pos.x * 1000 + chunk_pos.y

	for bx in range(2):
		for bz in range(2):
			var ox = bx * cell + margin
			var oz = bz * cell + margin
			var fw = minf(cell - margin, 18.0)
			var fd = minf(cell - margin, 18.0)
			if fw < 5.0: fw = 5.0
			if fd < 5.0: fd = 5.0

			var max_f = 8 if wealthy else 6
			var floors = 2 + (abs(hash("%d_%d_%d" % [bid, chunk_pos.x, chunk_pos.y])) % (max_f - 1))

			var building = _building_gen.generate_building(
				Vector3(ox, 0, oz),
				Vector2(fw, fd), floors, wealthy, bid
			)
			nav.add_child(building)

			var vents = _vent_gen.generate_vents(building, floors, Vector2(fw, fd))
			building.add_child(vents)

			# Street lights
			if _rng.randf() > 0.4:
				root.add_child(_make_lamp(Vector3(ox + fw + 1, 0, oz + fd / 2)))
			if _rng.randf() > 0.6:
				root.add_child(_make_lamp(Vector3(ox + fw / 2, 0, oz - 1)))

			bid += 1

	# Street furniture — pass Vector3.ZERO since root already has chunk_origin
	_add_street_furniture(root, Vector3.ZERO, cs, wealthy)

	return root

func _add_street_furniture(root: Node3D, origin: Vector3, cs: float, wealthy: bool) -> void:
	var road_w = WorldConfig.STREET_WIDTH

	# Dumpsters in alleys
	for i in range(_rng.randi_range(1, 3)):
		var dx = origin.x + _rng.randf_range(2, cs - 2)
		var dz = origin.z + _rng.randf_range(2, cs - 2)
		# Avoid road center
		if absf(dx - origin.x - cs / 2) < road_w and absf(dz - origin.z - cs / 2) < road_w:
			continue
		var dumpster = _factory.make_dumpster()
		dumpster.position = Vector3(dx, 0, dz)
		dumpster.rotation.y = _rng.randf_range(0, PI)
		root.add_child(dumpster)

	# Electrical boxes on building walls
	for i in range(_rng.randi_range(1, 2)):
		var ex = origin.x + _rng.randf_range(3, cs - 3)
		var ez = origin.z + _rng.randf_range(3, cs - 3)
		var ebox = _factory.make_electrical_box()
		ebox.position = Vector3(ex, 1.0, ez)
		root.add_child(ebox)

	# Vent grates on sidewalks
	for i in range(_rng.randi_range(2, 4)):
		var gx = origin.x + _rng.randf_range(2, cs - 2)
		var gz = origin.z + _rng.randf_range(2, cs - 2)
		var grate = _factory.make_vent_grate()
		grate.position = Vector3(gx, 0.05, gz)
		grate.rotation.x = -PI / 2
		root.add_child(grate)

	# CCTV cameras on poles (if wealthy)
	if wealthy:
		for i in range(_rng.randi_range(1, 2)):
			var cx = origin.x + _rng.randf_range(5, cs - 5)
			var cz = origin.z + _rng.randf_range(5, cs - 5)
			var pole = _box(Vector3(0.08, 3.5, 0.08), Vector3(cx, 1.75, cz), _m(Color(0.3, 0.3, 0.32)))
			root.add_child(pole)
			var cam = _factory.make_cctv_camera()
			cam.position = Vector3(cx, 3.5, cz)
			cam.rotation.y = _rng.randf_range(0, TAU)
			root.add_child(cam)

	# Neon signs on some buildings
	for i in range(_rng.randi_range(0, 2)):
		var sx = origin.x + _rng.randf_range(5, cs - 5)
		var sz = origin.z + _rng.randf_range(5, cs - 5)
		var neon_sign = _factory.make_neon_sign()
		neon_sign.position = Vector3(sx, 3.5, sz)
		neon_sign.rotation.y = _rng.randf_range(0, TAU)
		root.add_child(neon_sign)

func _make_lamp(pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.name = "StreetLamp"
	n.position = pos
	n.add_child(_box(Vector3(0.1, 4.5, 0.1), Vector3(0, 2.25, 0), _m(Color(0.3, 0.3, 0.32))))
	n.add_child(_box(Vector3(0.4, 0.15, 0.15), Vector3(0, 4.5, 0), _m(Color(0.2, 0.2, 0.22))))
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.92, 0.7)
	light.light_energy = 4.0
	light.omni_range = 18.0
	light.position = Vector3(0, 4.4, 0)
	light.add_to_group("stealth_light")
	n.add_child(light)
	return n

func _m(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _me(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = base
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if mat:
		mi.material_override = mat
	return mi
