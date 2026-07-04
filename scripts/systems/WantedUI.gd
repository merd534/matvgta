extends Control

## WantedUI — displays wanted stars and police status.

@export var police_director: NodePath

var _director: Node3D
var _stars_container: HBoxContainer
var _status_label: Label
var _stars: Array = []

func _ready() -> void:
	_setup_ui()
	if police_director:
		_director = get_node(police_director) as Node3D
		if _director:
			_director.wanted_level_changed.connect(_on_wanted_changed)

func _setup_ui() -> void:
	# Anchor top-right
	anchor_left = 0.8
	anchor_right = 1.0
	anchor_top = 0.02
	anchor_bottom = 0.1
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0

	# Stars container
	_stars_container = HBoxContainer.new()
	_stars_container.name = "Stars"
	_stars_container.position = Vector2(10, 5)
	_stars_container.add_theme_constant_override("separation", 4)
	add_child(_stars_container)

	for i in range(5):
		var star = Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 28)
		star.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		_stars_container.add_child(star)
		_stars.append(star)

	# Status label
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.position = Vector2(10, 38)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_status_label.text = ""
	add_child(_status_label)

func _on_wanted_changed(stars: int) -> void:
	for i in range(_stars.size()):
		if i < stars:
			_stars[i].add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
		else:
			_stars[i].add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

	match stars:
		0: _status_label.text = ""
		1: _status_label.text = Localization.translate("ALARM_LOW")
		2: _status_label.text = Localization.translate("ALARM_MEDIUM")
		3: _status_label.text = Localization.translate("ALARM_HIGH")
		4: _status_label.text = Localization.translate("ALARM_LOCKDOWN")
		5: _status_label.text = Localization.translate("ALARM_LOCKDOWN")
