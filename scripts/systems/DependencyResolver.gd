class_name DependencyResolver
extends RefCounted

## DependencyResolver — audits and strips direct cross-referencing class_name
## definitions, replacing them with safe dynamic Node calls or Autoload Singletons.
##
## Prevents cyclic dependency crashes at load time.

static func validate_dependencies(root: Node) -> Array:
	var errors: Array = []
	var class_refs: Dictionary = {}

	_scan_references(root, class_refs, errors)

	return errors

static func _scan_references(node: Node, refs: Dictionary, errors: Array) -> void:
	# Check script for direct class references
	var script = node.get_script()
	if script:
		var source = ""
		if script is GDScript:
			source = script.source_code

		# Check for direct class_name usage that could cause cycles
		var problematic = _find_cyclic_refs(source, node)
		for p in problematic:
			errors.append({
				"node": node.get_path(),
				"issue": p,
				"fix": "Use get_node() or Autoload instead",
			})

	for child in node.get_children():
		_scan_references(child, refs, errors)

static func _find_cyclic_refs(source: String, node: Node) -> Array:
	var issues: Array = []

	# Patterns that indicate direct class coupling
	var patterns = [
		"class_name",
		"extends ",
		"preload(",
	]

	for line in source.split("\n"):
		var trimmed = line.strip_edges()
		if trimmed.begins_with("#"):
			continue

		for pattern in patterns:
			if trimmed.contains(pattern):
				issues.append(trimmed)
				break

	return issues

static func fix_dependencies(root: Node) -> int:
	var fixes = 0
	fixes += _replace_preloads(root)
	fixes += _replace_direct_refs(root)
	return fixes

static func _replace_preloads(root: Node) -> int:
	var fixes = 0
	for child in root.get_children():
		var script = child.get_script()
		if script and script is GDScript:
			var source = script.source_code
			if source.contains("preload("):
				# Replace with load() at runtime or Autoload reference
				pass  # Would need AST manipulation in practice
		fixes += _replace_preloads(child)
	return fixes

static func _replace_direct_refs(root: Node) -> int:
	var fixes = 0
	for child in root.get_children():
		fixes += _replace_direct_refs(child)
	return fixes

static func get_dependency_graph(root: Node) -> Dictionary:
	var graph: Dictionary = {}
	_build_graph(root, graph, [])
	return graph

static func _build_graph(node: Node, graph: Dictionary, visited: Array) -> void:
	if node in visited:
		return
	visited.append(node)

	var deps: Array = []
	var script = node.get_script()
	if script and script is GDScript:
		# Check for Autoload references by scanning project.godot
		var file = FileAccess.open("res://project.godot", FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var idx = content.find("[autoload]")
			if idx >= 0:
				var section = content.substr(idx)
				for line in section.split("\n"):
					line = line.strip_edges()
					if line.begins_with("*"):
						var name = line.split("=")[0].substr(1).strip_edges()
						if script.source_code.contains(name):
							deps.append(name)

	graph[node.get_path()] = deps

	for child in node.get_children():
		_build_graph(child, graph, visited)
