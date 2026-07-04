extends Light3D

## StealthLight — add to any OmniLight3D or SpotLight3D to mark it
## as a light source for the stealth system (adds to "stealth_light" group).

func _ready() -> void:
	add_to_group("stealth_light")
