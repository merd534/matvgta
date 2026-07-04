class_name ProceduralAssetFactory
extends RefCounted

## Programmatic mesh factory — builds 30+ unique 3D objects from primitives.

var _rng: RandomNumberGenerator

# Shared materials
var _mat_wood: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_fabric: StandardMaterial3D
var _mat_concrete: StandardMaterial3D
var _mat_neon_blue: StandardMaterial3D
var _mat_neon_pink: StandardMaterial3D
var _mat_screen: StandardMaterial3D
var _mat_dark: StandardMaterial3D

func _init(seed_val: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_val if seed_val != 0 else randi()
	_init_materials()

func _init_materials() -> void:
	_mat_wood = _mat(Color(0.4, 0.28, 0.15))
	_mat_metal = _mat(Color(0.5, 0.5, 0.52))
	_mat_metal.metallic = 0.8
	_mat_metal.roughness = 0.3
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.albedo_color = Color(0.3, 0.4, 0.5, 0.3)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_fabric = _mat(Color(0.35, 0.25, 0.2))
	_mat_concrete = _mat(Color(0.35, 0.35, 0.37))
	_mat_dark = _mat(Color(0.1, 0.1, 0.12))
	_mat_neon_blue = _mat_emission(Color(0, 0.2, 0.5), Color(0, 0.5, 1), 3.0)
	_mat_neon_pink = _mat_emission(Color(0.4, 0, 0.3), Color(1, 0, 0.5), 3.0)
	_mat_screen = _mat_emission(Color(0.05, 0.08, 0.15), Color(0.2, 0.4, 0.8), 1.5)

# ═══════════════════════════════════════════
# INTERIOR FURNITURE
# ═══════════════════════════════════════════

func make_desk(wealthy: bool = false) -> Node3D:
	var n = Node3D.new()
	n.name = "Desk"
	# Tabletop
	n.add_child(_box(Vector3(1.4, 0.06, 0.7), Vector3(0, 0.75, 0), _mat_wood if not wealthy else _mat(Color(0.25, 0.15, 0.08))))
	# Legs
	for x in [-0.6, 0.6]:
		for z in [-0.28, 0.28]:
			n.add_child(_box(Vector3(0.06, 0.72, 0.06), Vector3(x, 0.36, z), _mat_metal))
	# Drawer
	n.add_child(_box(Vector3(0.4, 0.15, 0.55), Vector3(0.35, 0.6, 0), _mat(Color(0.35, 0.25, 0.15))))
	return n

func make_chair(wealthy: bool = false) -> Node3D:
	var n = Node3D.new()
	n.name = "Chair"
	var seat_mat = _mat_fabric if not wealthy else _mat(Color(0.15, 0.15, 0.2))
	# Seat
	n.add_child(_box(Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), seat_mat))
	# Back
	n.add_child(_box(Vector3(0.45, 0.45, 0.06), Vector3(0, 0.7, -0.2), seat_mat))
	# Legs
	for x in [-0.18, 0.18]:
		for z in [-0.18, 0.18]:
			n.add_child(_box(Vector3(0.04, 0.43, 0.04), Vector3(x, 0.21, z), _mat_metal))
	return n

func make_bed(wealthy: bool = false) -> Node3D:
	var n = Node3D.new()
	n.name = "Bed"
	# Frame
	n.add_child(_box(Vector3(1.6, 0.35, 2.0), Vector3(0, 0.175, 0), _mat_wood))
	# Mattress
	n.add_child(_box(Vector3(1.5, 0.2, 1.9), Vector3(0, 0.45, 0), _mat(Color(0.8, 0.8, 0.85) if not wealthy else Color(0.9, 0.85, 0.95))))
	# Pillow
	n.add_child(_box(Vector3(0.5, 0.1, 0.35), Vector3(0, 0.6, -0.7), _mat(Color(0.9, 0.9, 0.92))))
	# Headboard
	n.add_child(_box(Vector3(1.6, 0.6, 0.08), Vector3(0, 0.8, -0.95), _mat_wood if not wealthy else _mat(Color(0.2, 0.12, 0.06))))
	return n

func make_filing_cabinet() -> Node3D:
	var n = Node3D.new()
	n.name = "FilingCabinet"
	n.add_child(_box(Vector3(0.5, 1.2, 0.5), Vector3(0, 0.6, 0), _mat_metal))
	for i in range(4):
		n.add_child(_box(Vector3(0.35, 0.02, 0.01), Vector3(0, 0.15 + i * 0.28, -0.26), _mat(Color(0.4, 0.4, 0.42))))
	return n

func make_sofa(wealthy: bool = false) -> Node3D:
	var n = Node3D.new()
	n.name = "Sofa"
	var col = Color(0.3, 0.2, 0.15) if not wealthy else Color(0.15, 0.15, 0.25)
	# Seat
	n.add_child(_box(Vector3(1.8, 0.3, 0.8), Vector3(0, 0.35, 0), _mat(col)))
	# Back
	n.add_child(_box(Vector3(1.8, 0.5, 0.15), Vector3(0, 0.6, -0.35), _mat(col)))
	# Arms
	n.add_child(_box(Vector3(0.15, 0.3, 0.8), Vector3(-0.85, 0.5, 0), _mat(col)))
	n.add_child(_box(Vector3(0.15, 0.3, 0.8), Vector3(0.85, 0.5, 0), _mat(col)))
	return n

func make_toilet() -> Node3D:
	var n = Node3D.new()
	n.name = "Toilet"
	# Bowl
	n.add_child(_box(Vector3(0.4, 0.35, 0.5), Vector3(0, 0.175, 0), _mat(Color(0.9, 0.9, 0.92))))
	# Tank
	n.add_child(_box(Vector3(0.35, 0.4, 0.15), Vector3(0, 0.45, -0.2), _mat(Color(0.88, 0.88, 0.9))))
	return n

func make_sink() -> Node3D:
	var n = Node3D.new()
	n.name = "Sink"
	# Basin
	n.add_child(_box(Vector3(0.5, 0.12, 0.4), Vector3(0, 0.85, 0), _mat(Color(0.85, 0.85, 0.88))))
	# Pedestal
	n.add_child(_box(Vector3(0.15, 0.8, 0.15), Vector3(0, 0.4, 0), _mat(Color(0.8, 0.8, 0.82))))
	# Faucet
	n.add_child(_box(Vector3(0.04, 0.15, 0.04), Vector3(0, 0.95, -0.12), _mat_metal))
	return n

func make_kitchen_counter() -> Node3D:
	var n = Node3D.new()
	n.name = "KitchenCounter"
	n.add_child(_box(Vector3(1.5, 0.06, 0.6), Vector3(0, 0.9, 0), _mat(Color(0.25, 0.25, 0.28))))
	n.add_child(_box(Vector3(1.5, 0.85, 0.6), Vector3(0, 0.425, 0), _mat(Color(0.35, 0.35, 0.38))))
	return n

func make_ceiling_light() -> Node3D:
	var n = Node3D.new()
	n.name = "CeilingLight"
	n.add_child(_box(Vector3(0.6, 0.05, 0.6), Vector3(0, 0, 0), _mat(Color(0.8, 0.8, 0.85))))
	var light = OmniLight3D.new()
	light.light_color = Color(1, 0.95, 0.85)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0, -0.1, 0)
	light.add_to_group("stealth_light")
	n.add_child(light)
	return n

func make_bookshelf() -> Node3D:
	var n = Node3D.new()
	n.name = "Bookshelf"
	n.add_child(_box(Vector3(0.8, 1.8, 0.3), Vector3(0, 0.9, 0), _mat_wood))
	# Shelves
	for i in range(4):
		n.add_child(_box(Vector3(0.75, 0.03, 0.28), Vector3(0, 0.3 + i * 0.45, 0.01), _mat_wood))
	return n

# ═══════════════════════════════════════════
# EXTERIOR PROPS
# ═══════════════════════════════════════════

func make_dumpster() -> Node3D:
	var n = Node3D.new()
	n.name = "Dumpster"
	n.add_child(_box(Vector3(1.4, 0.9, 0.9), Vector3(0, 0.45, 0), _mat(Color(0.15, 0.25, 0.12))))
	# Lid
	n.add_child(_box(Vector3(1.4, 0.06, 0.9), Vector3(0, 0.93, 0), _mat(Color(0.12, 0.2, 0.1))))
	return n

func make_electrical_box() -> Node3D:
	var n = Node3D.new()
	n.name = "ElectricalBox"
	n.add_child(_box(Vector3(0.5, 0.6, 0.2), Vector3(0, 0.3, 0), _mat_metal))
	# Warning label
	n.add_child(_box(Vector3(0.2, 0.15, 0.01), Vector3(0, 0.35, -0.11), _mat(Color(1, 0.8, 0))))
	return n

func make_neon_sign(text: String = "BAR") -> Node3D:
	var n = Node3D.new()
	n.name = "NeonSign_" + text
	# Backing
	n.add_child(_box(Vector3(2.0, 0.8, 0.1), Vector3(0, 0, 0), _mat_dark))
	# Neon tubes (simplified as colored boxes)
	var neon_mat = _mat_neon_pink if _rng.randf() > 0.5 else _mat_neon_blue
	for i in range(text.length()):
		var x = -0.7 + i * 0.35
		n.add_child(_box(Vector3(0.2, 0.3, 0.05), Vector3(x, 0, 0.06), neon_mat))
	# Point light
	var light = OmniLight3D.new()
	light.light_color = neon_mat.emission
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position = Vector3(0, 0, 0.5)
	light.add_to_group("stealth_light")
	n.add_child(light)
	return n

func make_pipe(length: float = 3.0) -> Node3D:
	var n = Node3D.new()
	n.name = "Pipe"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.08
	cylinder.height = length
	var mi = MeshInstance3D.new()
	mi.mesh = cylinder
	mi.rotation.x = PI / 2
	mi.position.z = length / 2
	mi.material_override = _mat_metal
	n.add_child(mi)
	return n

func make_vent_grate() -> Node3D:
	var n = Node3D.new()
	n.name = "VentGrate"
	n.add_child(_box(Vector3(0.6, 0.6, 0.08), Vector3(0, 0, 0), _mat_metal))
	# Bars
	for i in range(4):
		var y = -0.2 + i * 0.13
		n.add_child(_box(Vector3(0.5, 0.03, 0.09), Vector3(0, y, 0), _mat(Color(0.4, 0.4, 0.42))))
	return n

# ═══════════════════════════════════════════
# ELECTRONICS
# ═══════════════════════════════════════════

func make_computer() -> Node3D:
	var n = Node3D.new()
	n.name = "Computer"
	# Monitor
	n.add_child(_box(Vector3(0.5, 0.35, 0.04), Vector3(0, 0.45, 0), _mat_dark))
	n.add_child(_box(Vector3(0.45, 0.3, 0.02), Vector3(0, 0.45, -0.01), _mat_screen))
	# Stand
	n.add_child(_box(Vector3(0.06, 0.12, 0.06), Vector3(0, 0.24, 0), _mat_metal))
	# Base
	n.add_child(_box(Vector3(0.25, 0.02, 0.15), Vector3(0, 0.18, 0), _mat_metal))
	# Keyboard
	n.add_child(_box(Vector3(0.4, 0.02, 0.15), Vector3(0, 0.18, 0.25), _mat(Color(0.15, 0.15, 0.17))))
	return n

func make_cctv_camera() -> Node3D:
	var n = Node3D.new()
	n.name = "CCTVCamera"
	# Mount
	n.add_child(_box(Vector3(0.15, 0.15, 0.1), Vector3(0, 0, 0), _mat_metal))
	# Arm
	n.add_child(_box(Vector3(0.04, 0.2, 0.04), Vector3(0, -0.15, 0.1), _mat_metal))
	# Body
	n.add_child(_box(Vector3(0.12, 0.1, 0.2), Vector3(0, -0.2, 0.2), _mat(Color(0.2, 0.2, 0.22))))
	# Lens
	var lens = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.04
	lens.mesh = sphere
	lens.position = Vector3(0, -0.2, 0.32)
	lens.material_override = _mat(Color(0.1, 0.1, 0.15))
	n.add_child(lens)
	# Red LED
	n.add_child(_box(Vector3(0.02, 0.02, 0.01), Vector3(0.04, -0.17, 0.31), _mat_emission(Color(0.3, 0, 0), Color(1, 0, 0), 3.0)))
	return n

func make_alarm_speaker() -> Node3D:
	var n = Node3D.new()
	n.name = "AlarmSpeaker"
	n.add_child(_box(Vector3(0.25, 0.25, 0.12), Vector3(0, 0, 0), _mat(Color(0.7, 0.7, 0.72))))
	n.add_child(_box(Vector3(0.15, 0.15, 0.01), Vector3(0, 0, 0.07), _mat(Color(0.1, 0.1, 0.12))))
	return n

func make_door_keypad() -> Node3D:
	var n = Node3D.new()
	n.name = "DoorKeypad"
	n.add_child(_box(Vector3(0.12, 0.2, 0.04), Vector3(0, 0, 0), _mat(Color(0.2, 0.2, 0.22))))
	n.add_child(_box(Vector3(0.08, 0.1, 0.01), Vector3(0, 0.02, 0.02), _mat(Color(0.1, 0.3, 0.1))))
	return n

func make_server_rack() -> Node3D:
	var n = Node3D.new()
	n.name = "ServerRack"
	n.add_child(_box(Vector3(0.6, 1.8, 0.5), Vector3(0, 0.9, 0), _mat(Color(0.12, 0.12, 0.14))))
	# Blinking LEDs
	for i in range(6):
		var y = 0.2 + i * 0.25
		var led_color = Color(0, 1, 0) if _rng.randf() > 0.3 else Color(1, 0, 0)
		n.add_child(_box(Vector3(0.02, 0.02, 0.01), Vector3(-0.25, y, 0.26), _mat_emission(led_color * 0.2, led_color, 2.0)))
	return n

# ═══════════════════════════════════════════
# ROOM TYPE BUILDERS
# ═══════════════════════════════════════════

enum RoomType { OFFICE, APARTMENT, RESTAURANT, CORRIDOR, STAIRWELL, SERVER_ROOM, BATHROOM, PENTHOUSE }

func build_room_content(room_type: RoomType, width: float, depth: float, wealthy: bool) -> Node3D:
	var n = Node3D.new()
	n.name = "RoomContent"

	match room_type:
		RoomType.OFFICE:
			n.add_child(make_desk(wealthy))
			n.add_child(make_chair(wealthy))
			if _rng.randf() > 0.3:
				n.add_child(make_computer())
			if _rng.randf() > 0.5:
				n.add_child(make_filing_cabinet())
			if _rng.randf() > 0.4:
				n.add_child(make_bookshelf())
		RoomType.APARTMENT:
			n.add_child(make_bed(wealthy))
			n.add_child(make_sofa(wealthy))
			if _rng.randf() > 0.3:
				n.add_child(make_kitchen_counter())
		RoomType.RESTAURANT:
			for i in range(_rng.randi_range(2, 4)):
				var table_x = _rng.randf_range(-width / 3, width / 3)
				var table_z = _rng.randf_range(-depth / 3, depth / 3)
				var table = _box(Vector3(0.8, 0.05, 0.8), Vector3(table_x, 0.75, table_z), _mat_wood)
				n.add_child(table)
				n.add_child(make_chair(false))
		RoomType.BATHROOM:
			n.add_child(make_toilet())
			n.add_child(make_sink())
		RoomType.SERVER_ROOM:
			for i in range(_rng.randi_range(2, 4)):
				var rack = make_server_rack()
				rack.position.x = -1.0 + i * 0.8
				n.add_child(rack)
		RoomType.CORRIDOR:
			n.add_child(make_ceiling_light())
		RoomType.STAIRWELL:
			pass  # empty shaft
		RoomType.PENTHOUSE:
			n.add_child(make_bed(true))
			n.add_child(make_sofa(true))
			n.add_child(make_kitchen_counter())
			n.add_child(make_ceiling_light())

	# Ceiling light for all rooms
	if room_type != RoomType.STAIRWELL and _rng.randf() > 0.3:
		var light = make_ceiling_light()
		light.position.y = WorldConfig.FLOOR_HEIGHT - 0.1
		n.add_child(light)

	return n

func random_room_type(wealthy: bool) -> RoomType:
	if wealthy:
		var roll = _rng.randf()
		if roll < 0.3: return RoomType.PENTHOUSE
		elif roll < 0.6: return RoomType.OFFICE
		elif roll < 0.8: return RoomType.APARTMENT
		else: return RoomType.SERVER_ROOM
	else:
		var roll = _rng.randf()
		if roll < 0.35: return RoomType.APARTMENT
		elif roll < 0.6: return RoomType.OFFICE
		elif roll < 0.75: return RoomType.RESTAURANT
		elif roll < 0.85: return RoomType.BATHROOM
		else: return RoomType.CORRIDOR

# ═══════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════

func _mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _mat_emission(base: Color, emission: Color, energy: float) -> StandardMaterial3D:
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
