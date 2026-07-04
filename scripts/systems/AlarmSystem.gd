extends Node3D

## AlarmSystem — global alarm state manager.
## Cameras report to this. When alert triggers, spawns guards and marks alarm level.

signal alarm_activated(level: int, position: Vector3)
signal alarm_cleared()
signal guard_spawn_requested(position: Vector3, threat_pos: Vector3)

enum AlarmLevel { NONE, LOW, MEDIUM, HIGH, LOCKDOWN }

var current_level: AlarmLevel = AlarmLevel.NONE
var _active_alerts: Array = []
var _alert_positions: Array = []

func register_camera(camera: Node3D) -> void:
	if camera.has_signal("player_spotted"):
		camera.player_spotted.connect(_on_camera_spotted)
	if camera.has_signal("player_lost"):
		camera.player_lost.connect(_on_camera_lost)

func _on_camera_spotted(camera: Node3D, player: Node3D) -> void:
	var pos = player.global_position
	if not _active_alerts.has(camera):
		_active_alerts.append(camera)
		_alert_positions.append(pos)

	_evaluate_alarm_level()

func _on_camera_lost(camera: Node3D) -> void:
	var idx = _active_alerts.find(camera)
	if idx >= 0:
		_active_alerts.remove_at(idx)
		_alert_positions.remove_at(idx)

	_evaluate_alarm_level()

func _evaluate_alarm_level() -> void:
	var alert_count = _active_alerts.size()

	var new_level: AlarmLevel
	match alert_count:
		0: new_level = AlarmLevel.NONE
		1: new_level = AlarmLevel.LOW
		2: new_level = AlarmLevel.MEDIUM
		3: new_level = AlarmLevel.HIGH
		_: new_level = AlarmLevel.LOCKDOWN

	if new_level != current_level:
		current_level = new_level
		if current_level == AlarmLevel.NONE:
			alarm_cleared.emit()
		else:
			var center = _get_alert_center()
			alarm_activated.emit(current_level, center)
			_request_guards(center)

func _get_alert_center() -> Vector3:
	if _alert_positions.is_empty():
		return Vector3.ZERO
	var sum = Vector3.ZERO
	for pos in _alert_positions:
		sum += pos
	return sum / _alert_positions.size()

func _request_guards(threat_pos: Vector3) -> void:
	var count = current_level  # 1-4 guards per level
	for i in range(count):
		var offset = Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		guard_spawn_requested.emit(threat_pos + offset, threat_pos)

func report_noise(noise_pos: Vector3, radius: float, noise_level: int) -> void:
	if noise_level >= 3:
		var avg = _get_alert_center()
		if noise_pos.distance_to(avg) < radius * 1.5:
			_request_guards(noise_pos)

func get_alert_count() -> int:
	return _active_alerts.size()
