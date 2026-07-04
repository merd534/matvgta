extends Node

## AssetLoader — dual-mode asset loading system.
## Mode A: Web — HTTPRequest to stream .gltf/.glb from URLs.
## Mode B: Procedural — FastNoiseLite textures, ArrayMesh, AudioStreamGenerator.

signal asset_loaded(asset_name: String, resource: Resource)
signal asset_failed(asset_name: String, error: String)
signal all_assets_loaded()

enum LoadMode { WEB, PROCEDURAL }

var current_mode: LoadMode = LoadMode.PROCEDURAL
var _pending: int = 0
var _cache: Dictionary = {}

func _ready() -> void:
	pass

func set_mode(mode: LoadMode) -> void:
	current_mode = mode

# ── WEB MODE ──

func load_gltf_from_url(url: String, asset_name: String) -> void:
	_pending += 1
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_gltf_loaded.bind(asset_name, http))
	http.request(url)

func _on_gltf_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, asset_name: String, http: HTTPRequest) -> void:
	http.queue_free()
	_pending -= 1

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		asset_failed.emit(asset_name, "HTTP %d" % response_code)
		_check_all_loaded()
		return

	# Save to temp file and load
	var temp_path = "user://temp_%s.glb" % asset_name
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()

	var gltf = GLTFDocument.new()
	var state = GLTFState.new()
	var error = gltf.append_from_file(temp_path, state)
	if error != OK:
		asset_failed.emit(asset_name, "Parse error %d" % error)
		_check_all_loaded()
		return

	var scene = gltf.generate_scene(state)
	if scene:
		_cache[asset_name] = scene
		asset_loaded.emit(asset_name, scene)
	_check_all_loaded()

func load_audio_from_url(url: String, asset_name: String) -> void:
	_pending += 1
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_audio_loaded.bind(asset_name, http))
	http.request(url)

func _on_audio_loaded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, asset_name: String, http: HTTPRequest) -> void:
	http.queue_free()
	_pending -= 1

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		asset_failed.emit(asset_name, "HTTP %d" % response_code)
		_check_all_loaded()
		return

	var stream = AudioStreamWAV.new()
	stream.data = body
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = true
	_cache[asset_name] = stream
	asset_loaded.emit(asset_name, stream)
	_check_all_loaded()

# ── PROCEDURAL MODE ──

func generate_texture(asset_name: String, size: Vector2i = Vector2i(256, 256), color1: Color = Color.BLACK, color2: Color = Color.WHITE) -> ImageTexture:
	var noise = FastNoiseLite.new()
	noise.seed = hash(asset_name)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02

	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for x in range(size.x):
		for y in range(size.y):
			var n = noise.get_noise_2d(float(x), float(y))
			var t = (n + 1.0) / 2.0
			img.set_pixel(x, y, color1.lerp(color2, t))

	var tex = ImageTexture.create_from_image(img)
	_cache[asset_name] = tex
	asset_loaded.emit(asset_name, tex)
	return tex

func generate_mesh(asset_name: String, mesh_type: String = "box", params: Dictionary = {}) -> ArrayMesh:
	var raw = []
	match mesh_type:
		"box":
			raw = _gen_box_mesh(params.get("size", Vector3(1, 1, 1)))
		"sphere":
			raw = _gen_sphere_mesh(params.get("radius", 0.5), params.get("segments", 16))
		"cylinder":
			raw = _gen_cylinder_mesh(params.get("radius", 0.5), params.get("height", 1.0), params.get("segments", 16))
		"plane":
			raw = _gen_plane_mesh(params.get("size", Vector2(1, 1)))
		_:
			raw = _gen_box_mesh(Vector3(1, 1, 1))

	# Convert raw arrays to proper Mesh arrays format
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = raw[0]
	arrays[Mesh.ARRAY_NORMAL] = raw[1]
	if raw.size() > 4 and raw[4]:
		arrays[Mesh.ARRAY_TEX_UV] = raw[4]
	if raw.size() > 5 and raw[5]:
		arrays[Mesh.ARRAY_INDEX] = raw[5]

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[asset_name] = mesh
	asset_loaded.emit(asset_name, mesh)
	return mesh

func generate_audio(asset_name: String, frequency: float = 440.0, duration: float = 1.0, wave_type: String = "sine") -> AudioStreamWAV:
	# Generate audio buffer
	var sample_rate = 44100
	var samples = int(duration * sample_rate)
	var buf = PackedByteArray()
	buf.resize(samples * 4)  # 16-bit stereo = 4 bytes per sample

	for i in range(samples):
		var t = float(i) / sample_rate
		var sample: float
		match wave_type:
			"sine":
				sample = sin(TAU * frequency * t)
			"square":
				sample = 1.0 if sin(TAU * frequency * t) > 0 else -1.0
			"sawtooth":
				sample = fmod(t * frequency, 1.0) * 2.0 - 1.0
			"triangle":
				sample = abs(fmod(t * frequency, 1.0) * 2.0 - 1.0) * 2.0 - 1.0
			_:
				sample = sin(TAU * frequency * t)

		# Envelope
		var env = 1.0
		var attack = 0.01
		var release = 0.05
		if t < attack:
			env = t / attack
		elif t > duration - release:
			env = (duration - t) / release

		var v = int(clampf(sample * env * 0.5, -1.0, 1.0) * 16000)
		buf[i * 4] = v & 0xFF
		buf[i * 4 + 1] = (v >> 8) & 0xFF
		buf[i * 4 + 2] = v & 0xFF
		buf[i * 4 + 3] = (v >> 8) & 0xFF

	var wav = AudioStreamWAV.new()
	wav.data = buf
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = true
	_cache[asset_name] = wav
	asset_loaded.emit(asset_name, wav)
	return wav

# ── Mesh generation helpers ──

func _gen_box_mesh(size: Vector3) -> Array:
	var s = size / 2.0
	var verts = PackedVector3Array([
		# Front
		Vector3(-s.x, -s.y, s.z), Vector3(s.x, -s.y, s.z), Vector3(s.x, s.y, s.z),
		Vector3(-s.x, -s.y, s.z), Vector3(s.x, s.y, s.z), Vector3(-s.x, s.y, s.z),
		# Back
		Vector3(s.x, -s.y, -s.z), Vector3(-s.x, -s.y, -s.z), Vector3(-s.x, s.y, -s.z),
		Vector3(s.x, -s.y, -s.z), Vector3(-s.x, s.y, -s.z), Vector3(s.x, s.y, -s.z),
		# Top
		Vector3(-s.x, s.y, s.z), Vector3(s.x, s.y, s.z), Vector3(s.x, s.y, -s.z),
		Vector3(-s.x, s.y, s.z), Vector3(s.x, s.y, -s.z), Vector3(-s.x, s.y, -s.z),
		# Bottom
		Vector3(-s.x, -s.y, -s.z), Vector3(s.x, -s.y, -s.z), Vector3(s.x, -s.y, s.z),
		Vector3(-s.x, -s.y, -s.z), Vector3(s.x, -s.y, s.z), Vector3(-s.x, -s.y, s.z),
		# Right
		Vector3(s.x, -s.y, s.z), Vector3(s.x, -s.y, -s.z), Vector3(s.x, s.y, -s.z),
		Vector3(s.x, -s.y, s.z), Vector3(s.x, s.y, -s.z), Vector3(s.x, s.y, s.z),
		# Left
		Vector3(-s.x, -s.y, -s.z), Vector3(-s.x, -s.y, s.z), Vector3(-s.x, s.y, s.z),
		Vector3(-s.x, -s.y, -s.z), Vector3(-s.x, s.y, s.z), Vector3(-s.x, s.y, -s.z),
	])
	var normals = PackedVector3Array()
	for i in range(6):
		for j in range(6):
			normals.append(Vector3(0, 0, 0))  # flat shading
	var uvs = PackedVector2Array()
	for i in range(6):
		uvs.append(Vector2(0, 0)); uvs.append(Vector2(1, 0)); uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 0)); uvs.append(Vector2(1, 1)); uvs.append(Vector2(0, 1))
	return [verts, normals, null, null, uvs]

func _gen_sphere_mesh(radius: float, segments: int) -> Array:
	var verts = PackedVector3Array()
	var rings: int = segments / 2  # intentional int — used in range()
	for i in range(rings + 1):
		var phi = PI * i / rings
		for j in range(segments + 1):
			var theta = TAU * j / segments
			var x = radius * sin(phi) * cos(theta)
			var y = radius * cos(phi)
			var z = radius * sin(phi) * sin(theta)
			verts.append(Vector3(x, y, z))
	var indices = PackedInt32Array()
	for i in range(rings):
		for j in range(segments):
			var a = i * (segments + 1) + j
			var b = a + segments + 1
			indices.append(a); indices.append(b); indices.append(a + 1)
			indices.append(a + 1); indices.append(b); indices.append(b + 1)
	var normals = PackedVector3Array()
	for v in verts:
		normals.append(v.normalized())
	return [verts, normals, null, null, PackedVector2Array(), indices]

func _gen_cylinder_mesh(radius: float, height: float, segments: int) -> Array:
	var verts = PackedVector3Array()
	var half_h = height / 2.0
	for i in range(segments + 1):
		var angle = TAU * i / segments
		var x = radius * cos(angle)
		var z = radius * sin(angle)
		verts.append(Vector3(x, half_h, z))
		verts.append(Vector3(x, -half_h, z))
	var indices = PackedInt32Array()
	for i in range(segments):
		var a = i * 2
		indices.append(a); indices.append(a + 1); indices.append(a + 2)
		indices.append(a + 1); indices.append(a + 3); indices.append(a + 2)
	var normals = PackedVector3Array()
	for i in range(segments + 1):
		var angle = TAU * i / segments
		var n = Vector3(cos(angle), 0, sin(angle))
		normals.append(n); normals.append(n)
	return [verts, normals, null, null, PackedVector2Array(), indices]

func _gen_plane_mesh(size: Vector2) -> Array:
	var hs = size / 2.0
	var verts = PackedVector3Array([
		Vector3(-hs.x, 0, -hs.y), Vector3(hs.x, 0, -hs.y), Vector3(hs.x, 0, hs.y),
		Vector3(-hs.x, 0, -hs.y), Vector3(hs.x, 0, hs.y), Vector3(-hs.x, 0, hs.y),
	])
	var normals = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP
	])
	var uvs = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)])
	return [verts, normals, null, null, uvs]

# ── Cache ──

func get_cached(asset_name: String) -> Resource:
	return _cache.get(asset_name)

func has_cached(asset_name: String) -> bool:
	return _cache.has(asset_name)

func clear_cache() -> void:
	_cache.clear()

func _check_all_loaded() -> void:
	if _pending <= 0:
		all_assets_loaded.emit()
