class_name ChunkMeshMerger
extends RefCounted

## ChunkMeshMerger — combines static meshes inside a chunk using
## MultiMeshInstance3D to reduce draw calls and improve FPS.
##
## Strategy:
## 1. Collect all MeshInstance3D nodes in the chunk
## 2. Group by mesh type and material
## 3. Create MultiMeshInstance3D for each group
## 4. Remove original individual meshes

static func merge_chunk(chunk: Node3D) -> void:
	if not chunk or not chunk.is_inside_tree():
		return

	var mesh_groups: Dictionary = {}  # key = "mesh_type|material_hash" -> Array of transforms

	_collect_meshes(chunk, mesh_groups)

	for group_key in mesh_groups:
		var instances = mesh_groups[group_key]
		if instances.size() < 3:  # not worth merging for < 3 instances
			continue

		_merge_group(chunk, group_key, instances)

static func _collect_meshes(node: Node, groups: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			# Skip if already part of a MultiMesh
			if child.get_parent() is MultiMeshInstance3D:
				continue

			var key = _get_group_key(child)
			if not groups.has(key):
				groups[key] = []
			groups[key].append({
				"node": child,
				"transform": child.global_transform,
			})
		elif child is Node3D and not child is CollisionShape3D:
			_collect_meshes(child, groups)

static func _get_group_key(mi: MeshInstance3D) -> String:
	var mesh_type = mi.mesh.get_class()
	var mat_hash = 0
	if mi.get_surface_override_material(0):
		mat_hash = mi.get_surface_override_material(0).get_rid().get_id()
	elif mi.mesh.surface_get_material(0):
		mat_hash = mi.mesh.surface_get_material(0).get_rid().get_id()
	return "%s_%d" % [mesh_type, mat_hash]

static func _merge_group(chunk: Node3D, group_key: String, instances: Array) -> void:
	if instances.is_empty():
		return

	var first = instances[0]["node"]
	var template_mesh = first.mesh

	# Create MultiMesh
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = instances.size()
	multimesh.mesh = template_mesh

	# Set transforms
	for i in range(instances.size()):
		var global_t = instances[i]["transform"]
		# Convert to local space of chunk
		var local_t = chunk.global_transform.affine_inverse() * global_t
		multimesh.set_instance_transform(i, local_t)

	# Create MultiMeshInstance3D
	var mmi = MultiMeshInstance3D.new()
	mmi.name = "MergedMesh_%s" % group_key
	mmi.multimesh = multimesh

	# Copy material from first instance
	var mat = first.get_surface_override_material(0)
	if mat:
		mmi.material_override = mat

	chunk.add_child(mmi)

	# Remove original instances
	for inst in instances:
		var node = inst["node"]
		if is_instance_valid(node):
			node.queue_free()

static func estimate_savings(chunk: Node3D) -> Dictionary:
	var mesh_count = 0
	var total_instances = 0
	var groups: Dictionary = {}

	_collect_meshes_count(chunk, groups)

	for key in groups:
		total_instances += groups[key]
		if groups[key] >= 3:
			mesh_count += 1

	return {
		"total_meshes": total_instances,
		"mergeable_groups": mesh_count,
		"estimated_draw_calls_after": total_instances - mesh_count * 2,
	}

static func _collect_meshes_count(node: Node, groups: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh:
			var key = child.mesh.get_class()
			groups[key] = groups.get(key, 0) + 1
		elif child is Node3D and not child is CollisionShape3D:
			_collect_meshes_count(child, groups)
