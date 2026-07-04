class_name BuildingGenerator
extends RefCounted

## Generates detailed multi-story buildings with room types, varied shapes, neon accents.

var _rng: RandomNumberGenerator
var _factory: ProceduralAssetFactory

# Shared materials
var _mat_wall: StandardMaterial3D
var _mat_floor: StandardMaterial3D
var _mat_ceiling: StandardMaterial3D
var _mat_neon_blue: StandardMaterial3D
var _mat_neon_pink: StandardMaterial3D
var _mat_neon_green: StandardMaterial3D
var _mat_window: StandardMaterial3D
var _mat_window_lit: StandardMaterial3D
var _mat_door: StandardMaterial3D
var _mat_door_frame: StandardMaterial3D

func _init(seed_val: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val
	_factory = ProceduralAssetFactory.new(seed_val)
	_init_mats()

func _init_mats() -> void:
	_mat_wall = _m(Color(0.22, 0.22, 0.25))
	_mat_floor = _m(Color(0.18, 0.18, 0.2))
	_mat_ceiling = _m(Color(0.25, 0.25, 0.27))
	_mat_door = _m(Color(0.3, 0.2, 0.12))
	_mat_door_frame = _m(Color(0.25, 0.18, 0.1))
	_mat_neon_blue = _me(Color(0, 0.2, 0.5), Color(0, 0.5, 1), 3.0)
	_mat_neon_pink = _me(Color(0.4, 0, 0.3), Color(1, 0, 0.5), 3.0)
	_mat_neon_green = _me(Color(0, 0.4, 0.2), Color(0, 1, 0.4), 2.0)
	_mat_window = _m(Color(0.08, 0.1, 0.15))
	_mat_window_lit = _me(Color(0.1, 0.12, 0.2), Color(0.3, 0.5, 1.0), 0.5)

func generate_building(origin: Vector3, footprint: Vector2, floors: int, is_wealthy: bool, bid: int) -> Node3D:
	var root = Node3D.new()
	root.name = "Building_%d" % bid
	root.position = origin

	var w = footprint.x
	var d = footprint.y
	var shell_h = floors * WorldConfig.FLOOR_HEIGHT

	# Choose building shape
	var shape = _rng.randi_range(0, 2)  # 0=rect, 1=L-shape, 2=step-back
	match shape:
		0: _build_rect(root, w, d, floors, is_wealthy, shell_h)
		1: _build_l_shape(root, w, d, floors, is_wealthy, shell_h)
		2: _build_step_back(root, w, d, floors, is_wealthy, shell_h)

	# Building shell collision
	var col_body = StaticBody3D.new()
	col_body.name = "BuildingCollider"
	col_body.position = Vector3(w / 2, shell_h / 2, d / 2)
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(w, shell_h, d)
	col_shape.shape = box
	col_body.add_child(col_shape)
	root.add_child(col_body)

	# Neon accent strips
	var neon_mats = [_mat_neon_blue, _mat_neon_pink, _mat_neon_green]
	for i in range(min(3, floors)):
		var ny = (i + 1) * WorldConfig.FLOOR_HEIGHT - 0.3
		var nm = neon_mats[i % 3]
		root.add_child(_box(Vector3(w + 0.1, 0.08, 0.05), Vector3(w / 2, ny, -0.03), nm))
		root.add_child(_box(Vector3(0.05, 0.08, d + 0.1), Vector3(-0.03, ny, d / 2), nm))

	# Neon sign on ground floor (30% chance)
	if _rng.randf() > 0.7:
		var neon_sign = _factory.make_neon_sign()
		neon_sign.position = Vector3(w / 2, 3.0, -0.3)
		root.add_child(neon_sign)

	# AC units on roof
	for i in range(_rng.randi_range(1, 3)):
		var ac = _box(Vector3(1.2, 0.7, 0.8), Vector3(w * (0.2 + i * 0.3), shell_h + 0.55, d * 0.3), _m(Color(0.35, 0.35, 0.38)))
		root.add_child(ac)

	# Roof pipes
	if _rng.randf() > 0.4:
		var pipe = _factory.make_pipe(w * 0.6)
		pipe.position = Vector3(w * 0.3, shell_h + 0.1, d * 0.8)
		pipe.rotation.y = _rng.randf_range(0, PI)
		root.add_child(pipe)

	return root

func _build_rect(root: Node3D, w: float, d: float, floors: int, wealthy: bool, shell_h: float) -> void:
	# Shell
	root.add_child(_box(Vector3(w, shell_h, d), Vector3(w / 2, shell_h / 2, d / 2), _mat_wall))
	_add_windows_all_faces(root, w, d, floors, wealthy)
	_add_interior(root, w, d, floors, wealthy)

func _build_l_shape(root: Node3D, w: float, d: float, floors: int, wealthy: bool, shell_h: float) -> void:
	# L-shape: two rectangles
	var w1 = w * 0.65
	var d1 = d
	var w2 = w * 0.35
	var d2 = d * 0.5
	root.add_child(_box(Vector3(w1, shell_h, d1), Vector3(w1 / 2, shell_h / 2, d1 / 2), _mat_wall))
	root.add_child(_box(Vector3(w2, shell_h, d2), Vector3(w1 + w2 / 2, shell_h / 2, d2 / 2), _mat_wall))
	_add_windows_all_faces(root, w1, d1, floors, wealthy)
	_add_windows_all_faces(root, w2, d2, floors, wealthy)
	_add_interior(root, w1, d1, floors, wealthy)
	_add_interior(root, w2, d2, floors, wealthy)

func _build_step_back(root: Node3D, w: float, d: float, floors: int, wealthy: bool, _shell_h: float) -> void:
	# Step-back: upper floors are smaller (penthouse style)
	var step_floor = max(2, floors - 2)
	for f in range(floors):
		var shrink = 0.0
		if f >= step_floor:
			shrink = (f - step_floor + 1) * 0.8
		var fw = max(w - shrink * 2, w * 0.5)
		var fd = max(d - shrink * 2, d * 0.5)
		var fy = f * WorldConfig.FLOOR_HEIGHT
		var fh = WorldConfig.FLOOR_HEIGHT
		root.add_child(_box(Vector3(fw, fh, fd), Vector3(w / 2, fy + fh / 2, d / 2), _mat_wall))
		_add_windows_single_floor(root, fw, fd, fy, wealthy)
	_add_interior(root, w, d, floors, wealthy)

func _add_windows_all_faces(root: Node3D, w: float, d: float, floors: int, wealthy: bool) -> void:
	for f in range(floors):
		_add_windows_single_floor(root, w, d, f * WorldConfig.FLOOR_HEIGHT, wealthy)

func _add_windows_single_floor(root: Node3D, w: float, d: float, fy: float, _wealthy: bool) -> void:
	var spacing = 2.5
	var win_h = 1.0
	var win_w = 0.8

	# Front (z=0)
	for xi in range(int(w / spacing)):
		var wx = 0.8 + xi * spacing
		if wx > w - 0.5: break
		var lit = _rng.randf() > 0.35
		root.add_child(_box(Vector3(win_w, win_h, 0.05), Vector3(wx, fy + 1.2, -0.03), _mat_window_lit if lit else _mat_window))
	# Back (z=d)
	for xi in range(int(w / spacing)):
		var wx = 0.8 + xi * spacing
		if wx > w - 0.5: break
		var lit = _rng.randf() > 0.35
		root.add_child(_box(Vector3(win_w, win_h, 0.05), Vector3(wx, fy + 1.2, d + 0.03), _mat_window_lit if lit else _mat_window))
	# Sides
	for zi in range(int(d / spacing)):
		var wz = 0.8 + zi * spacing
		if wz > d - 0.5: break
		var lit = _rng.randf() > 0.35
		root.add_child(_box(Vector3(0.05, win_h, win_w), Vector3(-0.03, fy + 1.2, wz), _mat_window_lit if lit else _mat_window))
		root.add_child(_box(Vector3(0.05, win_h, win_w), Vector3(w + 0.03, fy + 1.2, wz), _mat_window_lit if lit else _mat_window))

func _add_interior(root: Node3D, w: float, d: float, floors: int, wealthy: bool) -> void:
	for f in range(floors):
		var fy = f * WorldConfig.FLOOR_HEIGHT
		# Floor slab
		root.add_child(_box(Vector3(w - 0.2, 0.15, d - 0.2), Vector3(w / 2, fy + 0.075, d / 2), _mat_floor))
		# Ceiling
		root.add_child(_box(Vector3(w - 0.2, 0.1, d - 0.2), Vector3(w / 2, fy + WorldConfig.FLOOR_HEIGHT - 0.05, d / 2), _mat_ceiling))

		# Divide into rooms
		var room_cols = _rng.randi_range(2, 3)
		var room_rows = _rng.randi_range(2, 3)
		var cw = (w - 0.6) / room_cols
		var ch = (d - 0.6) / room_rows

		for rc in range(room_cols):
			for rr in range(room_rows):
				var rx = 0.3 + rc * cw
				var rz = 0.3 + rr * ch
				var room_type = _factory.random_room_type(wealthy)

				# Room content from factory
				var content = _factory.build_room_content(room_type, cw, ch, wealthy)
				content.position = Vector3(rx + cw / 2, fy, rz + ch / 2)
				root.add_child(content)

				# Interior walls (thin boxes)
				if rc < room_cols - 1:
					var wall_x = 0.3 + (rc + 1) * cw
					root.add_child(_box(Vector3(0.1, WorldConfig.FLOOR_HEIGHT, ch), Vector3(wall_x, fy + WorldConfig.FLOOR_HEIGHT / 2, rz + ch / 2), _mat_wall))
				if rr < room_rows - 1:
					var wall_z = 0.3 + (rr + 1) * ch
					root.add_child(_box(Vector3(cw, WorldConfig.FLOOR_HEIGHT, 0.1), Vector3(rx + cw / 2, fy + WorldConfig.FLOOR_HEIGHT / 2, wall_z), _mat_wall))

		# Doors (colored strips in walls)
		for rc in range(room_cols):
			var door_x = 0.3 + rc * cw + cw / 2
			root.add_child(_box(Vector3(0.9, 2.1, 0.08), Vector3(door_x, fy + 1.05, 0.15), _mat_door))
			# Door frame
			root.add_child(_box(Vector3(1.0, 0.08, 0.1), Vector3(door_x, fy + 2.15, 0.15), _mat_door_frame))

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
