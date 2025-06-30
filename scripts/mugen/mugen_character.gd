extends RefCounted
class_name MugenCharacter

## MUGEN Character Data Container
## Holds all character data loaded from MUGEN files

signal character_loaded
signal loading_error(message: String)

# Character metadata
var character_name: String = ""
var display_name: String = ""
var author: String = ""
var version: String = ""
var local_coord: Vector2i = Vector2i(320, 240)

# File paths (relative to character directory)
var base_directory: String = ""
var def_file_path: String = ""
var sprite_file_path: String = ""
var animation_file_path: String = ""
var command_file_path: String = ""
var constants_file_path: String = ""
var sound_file_path: String = ""
var palette_files: Array[String] = []

# Loaded data
var def_data: Dictionary = {}
var sprite_parser
var sprite_bundle: SpriteBundle
var sprite_cache: Dictionary = {}  # [group][image] -> Texture2D
var animations: Dictionary = {}
var palettes: Array[PackedColorArray] = []

# Character stats (for simulation)
var stats: Dictionary = {
	"power": 100,
	"defense": 100,
	"speed": 100,
	"technique": 100,
	"range": 100
}

# Loading state
var is_loaded: bool = false
var is_loading: bool = false

func load_from_directory(directory_path: String) -> bool:
	"""Load character from a directory containing MUGEN files"""
	if is_loading:
		loading_error.emit("Character is already loading")
		return false
	
	is_loading = true
	base_directory = directory_path
	
	print("🥊 Loading MUGEN character from: ", directory_path)
	
	# Find DEF file
	var def_file = _find_def_file(directory_path)
	if def_file.is_empty():
		loading_error.emit("No DEF file found in directory: " + directory_path)
		is_loading = false
		return false
	
	def_file_path = def_file
	
	# Parse DEF file
	if not _parse_def_file():
		is_loading = false
		return false
	
	# Load sprite file
	if not _load_sprites():
		is_loading = false
		return false
	
	# Load palettes
	_load_palettes()
	
	# Parse basic animations (optional for now)
	_parse_basic_animations()
	
	is_loaded = true
	is_loading = false
	character_loaded.emit()
	
	print("✅ Character loaded: %s by %s" % [display_name, author])
	return true

func _find_def_file(directory_path: String) -> String:
	"""Find the DEF file in the character directory"""
	var dir = DirAccess.open(directory_path)
	if not dir:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".def"):
			return directory_path.path_join(file_name)
		file_name = dir.get_next()
	
	return ""

func _parse_def_file() -> bool:
	"""Parse the character DEF file"""
	var def_parser_script = load("res://scripts/mugen/def_parser.gd")
	var parser = def_parser_script.new()
	def_data = parser.parse_def_file(def_file_path)
	
	if def_data.is_empty():
		loading_error.emit("Failed to parse DEF file: " + def_file_path)
		return false
	
	# Extract character info
	var info = parser.get_character_info()
	character_name = info.get("name", "Unknown")
	display_name = parser.get_character_name()
	author = parser.get_character_author()
	version = parser.get_character_version()
	local_coord = parser.get_localcoord()
	
	# Extract file paths
	var _files = parser.get_file_paths()
	sprite_file_path = _resolve_file_path(parser.get_sprite_file())
	animation_file_path = _resolve_file_path(parser.get_animation_file())
	command_file_path = _resolve_file_path(parser.get_command_file())
	constants_file_path = _resolve_file_path(parser.get_constants_file())
	sound_file_path = _resolve_file_path(parser.get_sound_file())
	
	# Extract palette files
	var palette_list = parser.get_palette_files()
	palette_files.clear()
	for palette_file in palette_list:
		palette_files.append(_resolve_file_path(palette_file))
	
	return true

func _resolve_file_path(relative_path: String) -> String:
	"""Resolve relative file path to absolute path, normalizing slashes (MUGEN is tolerant, Godot is not)"""
	if relative_path.is_empty():
		return ""

	# Remove quotes if present
	if relative_path.begins_with("\"") and relative_path.ends_with("\""):
		relative_path = relative_path.substr(1, relative_path.length() - 2)

	# Normalize slashes for Godot
	relative_path = relative_path.replace("\\", "/")
	return base_directory.path_join(relative_path)

func _load_sprites() -> bool:
	"""Load the character's sprite file with debug output and error propagation"""
	if sprite_file_path.is_empty():
		loading_error.emit("No sprite file specified")
		return false

	print("🗂️ Resolved sprite file path: %s" % sprite_file_path)

	if not FileAccess.file_exists(sprite_file_path):
		loading_error.emit("Sprite file not found: " + sprite_file_path)
		return false

	var sff_parser_script = load("res://scripts/mugen/sff_parser.gd")
	sprite_parser = sff_parser_script.new()
	var parse_success = sprite_parser.parse_sff_file(sprite_file_path)
	
	if not parse_success:
		print("⚠️ SFF parsing failed for: %s" % sprite_file_path)
		print("   This character may use placeholder/corrupted sprite files")
		print("   Character will load without sprites")
		
		# Create fallback sprite bundle for corrupted files
		var fallback_sprites = sprite_parser.create_fallback_sprite_bundle()
		sprite_bundle = SpriteBundle.new(fallback_sprites)
		
		print("📦 Created fallback sprite bundle with %d sprites" % sprite_bundle.get_sprite_count())
		return true  # Continue loading with fallback sprites
	
	# Create SpriteBundle from parsed sprite data
	var all_sprite_data = sprite_parser.get_all_sprite_data()
	sprite_bundle = SpriteBundle.new(all_sprite_data)

	print("📊 Loaded %d sprite groups, %d total sprites" % [sprite_parser.get_groups().size(), sprite_bundle.get_sprite_count()])
	return true

func _load_palettes():
	"""Load character palettes"""
	palettes.clear()
	
	# Try to load palette files
	for palette_file in palette_files:
		if FileAccess.file_exists(palette_file):
			var palette = _load_palette_file(palette_file)
			if palette.size() > 0:
				palettes.append(palette)
	
	# If no palettes loaded, try to get from sprite file
	if palettes.is_empty() and sprite_parser:
		var default_palette = sprite_parser.shared_palette
		if default_palette.size() > 0:
			palettes.append(default_palette)
	
	print("🎨 Loaded %d palettes" % palettes.size())

func _load_palette_file(file_path: String) -> PackedColorArray:
	"""Load palette from ACT file or extract from PCX"""
	var palette = PackedColorArray()
	
	if file_path.ends_with(".act"):
		# Adobe Color Table format
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			for i in range(256):
				if file.get_position() + 3 <= file.get_length():
					var r = file.get_8()
					var g = file.get_8()
					var b = file.get_8()
					palette.append(Color8(r, g, b, 255))
				else:
					break
			file.close()
	
	return palette

func _parse_basic_animations():
	"""Parse basic animations (simplified for now)"""
	# This would parse the AIR file for animation data
	# For now, we'll create basic placeholder animations
	animations["idle"] = {"group": 0, "images": [0, 1]}
	animations["walk"] = {"group": 20, "images": [0, 1, 2, 3]}
	animations["attack"] = {"group": 200, "images": [0, 1, 2]}

func get_sprite(group: int, image: int, palette_index: int = 0) -> Texture2D:
	"""Get a sprite texture with specified palette"""
	if not sprite_parser:
		return null
	
	var cache_key = "%d_%d_%d" % [group, image, palette_index]
	if sprite_cache.has(cache_key):
		return sprite_cache[cache_key]
	
	var texture = sprite_parser.get_sprite_texture(group, image)
	if texture:
		sprite_cache[cache_key] = texture
	
	return texture

func get_random_sprite() -> Texture2D:
	"""Get a random sprite for preview purposes"""
	if not sprite_parser:
		return null
	
	var groups = sprite_parser.get_groups()
	if groups.is_empty():
		return null
	
	var random_group = groups[randi() % groups.size()]
	var images = sprite_parser.get_images_in_group(random_group)
	if images.is_empty():
		return null
	
	var random_image = images[randi() % images.size()]
	return get_sprite(random_group, random_image)

func get_portrait_sprite() -> Texture2D:
	"""Get character portrait sprite (usually group 9000)"""
	# Try common portrait groups
	var portrait_groups = [9000, 9001, 9999]
	for group in portrait_groups:
		var texture = get_sprite(group, 0)
		if texture:
			return texture
	
	# Fallback to any available sprite
	return get_random_sprite()

func get_stance_sprite() -> Texture2D:
	"""Get character stance/idle sprite (usually group 0)"""
	return get_sprite(0, 0)

func get_available_groups() -> Array:
	"""Get list of available sprite groups"""
	if sprite_parser:
		return sprite_parser.get_groups()
	return []

func get_available_images(group: int) -> Array:
	"""Get list of available images in a group"""
	if sprite_parser:
		return sprite_parser.get_images_in_group(group)
	return []

func get_character_info() -> Dictionary:
	"""Get character information dictionary"""
	return {
		"name": character_name,
		"display_name": display_name,
		"author": author,
		"version": version,
		"local_coord": local_coord,
		"stats": stats,
		"sprite_groups": get_available_groups().size() if sprite_parser else 0,
		"palettes": palettes.size()
	}

func apply_random_stats():
	"""Apply randomized stats for gameplay variety"""
	var stat_names = ["power", "defense", "speed", "technique", "range"]
	for stat in stat_names:
		stats[stat] = randi_range(80, 120)  # 80-120 range for balance

func debug_print():
	"""Print character information for debugging"""
	print("🥊 Character Debug Info:")
	print("  Name: %s (%s)" % [display_name, character_name])
	print("  Author: %s" % author)
	print("  Version: %s" % version)
	print("  Local Coord: %s" % local_coord)
	print("  Sprite File: %s" % sprite_file_path)
	print("  Sprite Groups: %d" % (get_available_groups().size() if sprite_parser else 0))
	print("  Palettes: %d" % palettes.size())
	print("  Stats: %s" % stats)

func set_sff_parser(parser) -> void:
	"""Set the SFF parser for this character (called from MugenCharacterData)"""
	sprite_parser = parser
	if parser and parser.sprites.size() > 0:
		print("✅ SFF parser set for character: %d sprites available" % parser.sprites.size())
	else:
		print("⚠️ SFF parser set but no sprites loaded")

func get_sprite_bundle() -> SpriteBundle:
	"""Get the character's sprite bundle"""
	return sprite_bundle

func create_animation_sprite(animations_data: Dictionary = {}):
	"""Create a MugenAnimationSprite for this character"""
	if not sprite_bundle:
		push_error("Cannot create animation sprite - no sprite bundle loaded")
		return null
	
	var MugenAnimationSpriteClass = preload("res://scripts/mugen/mugen_animation_sprite.gd")
	return MugenAnimationSpriteClass.new(sprite_bundle, animations_data)

func get_sprite_texture(group: int, image: int) -> Texture2D:
	"""Get a single sprite as texture (backward compatibility)"""
	if sprite_parser:
		return sprite_parser.get_sprite_texture(group, image)
	return null
