extends Node

## PerformanceProfiler — monitors FPS, draw calls, memory usage.
## Helps identify performance bottlenecks in generated city.

signal performance_warning(metric: String, value: float, threshold: float)

@export var fps_warning_threshold: float = 30.0
@export var draw_call_warning: int = 500
@export var memory_warning_mb: float = 2048.0
@export var update_interval: float = 1.0

var current_fps: float = 0.0
var current_draw_calls: int = 0
var current_memory_mb: float = 0.0

var _timer: float = 0.0
var _fps_history: Array = []
var _max_history: int = 60

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_measure()

func _measure() -> void:
	# FPS
	current_fps = Engine.get_frames_per_second()
	_fps_history.append(current_fps)
	if _fps_history.size() > _max_history:
		_fps_history.pop_front()

	# Draw calls (RenderingServer)
	current_draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

	# Memory
	var mem_info = OS.get_memory_info()
	current_memory_mb = mem_info.get("physical", 0) / 1048576.0 if mem_info else 0

	# Warnings
	if current_fps < fps_warning_threshold:
		performance_warning.emit("fps", current_fps, fps_warning_threshold)

	if current_draw_calls > draw_call_warning:
		performance_warning.emit("draw_calls", current_draw_calls, draw_call_warning)

	if current_memory_mb > memory_warning_mb:
		performance_warning.emit("memory", current_memory_mb, memory_warning_mb)

func get_average_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var sum = 0.0
	for fps in _fps_history:
		sum += fps
	return sum / _fps_history.size()

func get_min_fps() -> float:
	if _fps_history.is_empty():
		return 0.0
	var min_fps = _fps_history[0]
	for fps in _fps_history:
		min_fps = minf(min_fps, fps)
	return min_fps

func get_stats() -> Dictionary:
	return {
		"fps": current_fps,
		"avg_fps": get_average_fps(),
		"min_fps": get_min_fps(),
		"draw_calls": current_draw_calls,
		"memory_mb": current_memory_mb,
	}

func get_report() -> String:
	var stats = get_stats()
	return "FPS: %d (avg: %d, min: %d) | Draws: %d | RAM: %d MB" % [
		int(stats["fps"]),
		int(stats["avg_fps"]),
		int(stats["min_fps"]),
		stats["draw_calls"],
		int(stats["memory_mb"]),
	]
