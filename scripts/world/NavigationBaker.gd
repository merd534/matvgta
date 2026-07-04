class_name NavigationBaker
extends RefCounted

## Handles asynchronous navigation mesh baking for generated chunks.

static func bake_region(region: NavigationRegion3D) -> void:
	if not region or not region.is_inside_tree():
		return
	# Use deferred call to avoid blocking main thread
	region.bake_navigation_mesh.call_deferred()

static func bake_all(root: Node) -> void:
	var regions = root.find_children("*", "NavigationRegion3D", true, false)
	for region in regions:
		bake_region(region)
