class_name AsyncNavigationBaker
extends RefCounted

## Bakes navigation meshes. Skips regions without valid NavigationMesh.

signal all_bakes_completed()

var _pending: int = 0

func bake_all_async(root: Node) -> void:
	var regions = root.find_children("*", "NavigationRegion3D", true, false)
	_pending = 0

	for region in regions:
		if not region.navigation_mesh:
			continue
		# Must match the navigation map's cell size/height (engine default 0.25)
		# or NavigationServer3D rejects the region with a cell mismatch error.
		region.navigation_mesh.cell_size = 0.25
		region.navigation_mesh.cell_height = 0.25
		region.navigation_mesh.agent_max_climb = 0.5
		_pending += 1

	if _pending == 0:
		all_bakes_completed.emit()
		return

	for region in regions:
		if not region.navigation_mesh:
			continue
		_bake_one(region)

func _bake_one(region: NavigationRegion3D) -> void:
	if not region.is_inside_tree():
		_pending -= 1
		_check_done()
		return
	# Connect to the bake_finished signal to properly track completion
	if not region.bake_finished.is_connected(_on_bake_finished):
		region.bake_finished.connect(_on_bake_finished)
	region.bake_navigation_mesh.call_deferred()

func _on_bake_finished() -> void:
	_pending -= 1
	_check_done()

func _check_done() -> void:
	if _pending <= 0:
		all_bakes_completed.emit()
