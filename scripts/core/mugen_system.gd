extends Node

## MUGEN System Manager - Autoload script for handling MUGEN assets
## Provides centralized access to MUGEN parsers and character management

signal character_loaded(character)
signal character_loading_error(path: String, error: String)

# Loaded characters cache
var loaded_characters: Dictionary = {}  # path -> MugenCharacter
var character_directories: Array[String] = []

func _ready():
	print("🎮 MUGEN System initialized")
	# Use call_deferred to ensure file system is ready
	call_deferred("_discover_characters")

func _discover_characters():
	"""Discover all available character directories"""
	character_directories.clear()
	var chars_path = "res://assets/mugen/chars"
	
	if not DirAccess.dir_exists_absolute(chars_path):
		print("📁 Characters directory not found: ", chars_path)
		return
	
	var dir = DirAccess.open(chars_path)
	if not dir:
		print("❌ Failed to open characters directory")
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var char_path = chars_path.path_join(folder_name)
			character_directories.append(char_path)
			print("📂 Found character directory: ", folder_name)
		folder_name = dir.get_next()
	
	print("🔍 Discovered %d character directories" % character_directories.size())

func load_character(directory_path: String):
	"""Load a character from directory, with caching"""
	if loaded_characters.has(directory_path):
		return loaded_characters[directory_path]
	
	# Load the MugenCharacter class dynamically
	var mugen_character_script = load("res://scripts/mugen/mugen_character.gd")
	var character = mugen_character_script.new()
	character.loading_error.connect(_on_character_loading_error.bind(directory_path))
	
	if character.load_from_directory(directory_path):
		loaded_characters[directory_path] = character
		character_loaded.emit(character)
		return character
	else:
		return null

func load_character_async(directory_path: String):
	"""Load character asynchronously"""
	# For now, just call synchronous version
	# Could be improved with threading later
	load_character(directory_path)

func get_character_list() -> Array[String]:
	"""Get list of available character directories"""
	return character_directories.duplicate()

func get_loaded_characters() -> Array:
	"""Get all currently loaded characters"""
	var characters = []
	for character in loaded_characters.values():
		characters.append(character)
	return characters

func unload_character(directory_path: String):
	"""Unload a character to free memory"""
	if loaded_characters.has(directory_path):
		loaded_characters.erase(directory_path)
		print("🗑️ Unloaded character: ", directory_path)

func clear_cache():
	"""Clear all loaded characters"""
	loaded_characters.clear()
	print("🗑️ Cleared character cache")

func _on_character_loading_error(path: String, error: String):
	"""Handle character loading errors"""
	print("❌ Character loading error [%s]: %s" % [path, error])
	character_loading_error.emit(path, error)

func get_random_character():
	"""Get a random character (loads if necessary)"""
	if character_directories.is_empty():
		return null
	
	var random_dir = character_directories[randi() % character_directories.size()]
	return load_character(random_dir)

func create_character_preview(character) -> Dictionary:
	"""Create a preview data structure for UI"""
	if not character:
		return {}
	
	var info = character.get_character_info()
	return {
		"name": info.get("display_name", "Unknown"),
		"author": info.get("author", "Unknown"),
		"version": info.get("version", "Unknown"),
		"portrait": character.get_portrait_sprite(),
		"stance": character.get_stance_sprite(),
		"stats": info.get("stats", {}),
		"sprite_groups": info.get("sprite_groups", 0)
	}
