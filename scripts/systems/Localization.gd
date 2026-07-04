extends Node

## Autoload singleton for runtime language switching.
## Default language: Russian (ru).
## Uses translate() instead of tr() to avoid overriding built-in Object.tr().

var current_language: String = "ru"

func _ready() -> void:
	_apply_language(current_language)

func set_language(lang: String) -> void:
	current_language = lang
	_apply_language(lang)

func _apply_language(lang: String) -> void:
	TranslationServer.set_locale(lang)

func translate(key: String) -> String:
	return TranslationServer.tr(key)
