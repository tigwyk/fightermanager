extends RefCounted
class_name MugenCharacterData

## Unified MUGEN Character Data Container
## Combines SFF, DEF, AIR, CMD, CNS parsers into a single character package

signal loading_progress(step: String, progress: float)
signal loading_complete(success: bool)
signal loading_error(error: String)

# Character metadata
var character_name: String = ""
var character_path: String = ""
var def_file_path: String = ""

# Parser instances
var def_parser
var sff_parser
var air_parser
var cmd_parser
var cns_parser

# Parsed data cache
var character_info: Dictionary = {}
var animations: Dictionary = {}
var commands: Array = []
var ai_triggers: Array = []
var sprites_loaded: bool = false

# Loading state
var is_loading: bool = false
var is_loaded: bool = false
var loading_steps: Array = ["DEF", "SFF", "AIR", "CMD", "CNS"]
var current_step: int = 0

func load_character_async(def_path: String) -> bool:
	"""Load a complete MUGEN character asynchronously"""
	if is_loading:
		emit_signal("loading_error", "Character is already loading")
		return false
	
	if not FileAccess.file_exists(def_path):
		emit_signal("loading_error", "DEF file not found: " + def_path)
		return false
	
	is_loading = true
	is_loaded = false
	current_step = 0
	def_file_path = def_path
	character_path = def_path.get_base_dir()
	character_name = def_path.get_file().get_basename()
	
	# Start loading process
	_load_next_step()
	return true

func _load_next_step():
	"""Load the next step in the character loading process"""
	if current_step >= loading_steps.size():
		_finalize_loading()
		return
	
	var step_name = loading_steps[current_step]
	var progress = float(current_step) / float(loading_steps.size())
	emit_signal("loading_progress", step_name, progress)
	
	match step_name:
		"DEF":
			_load_def_file()
		"SFF":
			_load_sff_file()
		"AIR":
			_load_air_file()
		"CMD":
			_load_cmd_file()
		"CNS":
			_load_cns_file()
	
	current_step += 1
	# Continue loading on next frame to prevent blocking
	call_deferred("_load_next_step")

func _load_def_file():
	"""Load character definition file"""
	def_parser = preload("res://scripts/mugen/def_parser.gd").new()
	if def_parser.parse_def_file(def_file_path):
		character_info = def_parser.get_character_info()
		print("Loaded DEF: ", character_name)
	else:
		emit_signal("loading_error", "Failed to parse DEF file")

func _load_sff_file():
	"""Load sprite file"""
	var sff_path = ""
	if def_parser:
		sff_path = _resolve_file_path(def_parser.get_sprite_file())
	
	if sff_path != "":
		print("sff_path: %s" % sff_path)
		sff_parser = preload("res://scripts/mugen/sff_parser.gd").new()
		if sff_parser.parse_sff_file(sff_path):
			sprites_loaded = true
			print("Loaded SFF: ", sff_path.get_file())
		else:
			print("⚠️ SFF parsing failed for: ", sff_path)
			print("   This character may use placeholder/corrupted sprite files")
			print("   Character will load without sprites")
			# Don't emit error - continue loading other components
			sprites_loaded = false
	else:
		print("No sprite file specified in DEF")

func _load_air_file():
	"""Load animation file"""
	var air_path = ""
	if def_parser:
		air_path = _resolve_file_path(def_parser.get_animation_file())
	
	if air_path != "":
		air_parser = preload("res://scripts/mugen/air_parser.gd").new()
		if air_parser.parse_air_file(air_path):
			animations = air_parser.get_all_animations()
			print("Loaded AIR: ", air_path.get_file(), " (", animations.size(), " animations)")
		else:
			emit_signal("loading_error", "Failed to parse AIR file: " + air_path)
	else:
		print("No animation file specified in DEF")

func _load_cmd_file():
	"""Load command file"""
	var cmd_path = ""
	if def_parser:
		cmd_path = _resolve_file_path(def_parser.get_command_file())
	
	if cmd_path != "":
		cmd_parser = preload("res://scripts/mugen/cmd_parser.gd").new()
		if cmd_parser.parse_cmd_file(cmd_path):
			commands = cmd_parser.get_commands()
			print("Loaded CMD: ", cmd_path.get_file(), " (", commands.size(), " commands)")
		else:
			emit_signal("loading_error", "Failed to parse CMD file: " + cmd_path)
	else:
		print("No command file specified in DEF")

func _load_cns_file():
	"""Load constants/state file"""
	var cns_path = ""
	if def_parser:
		cns_path = _resolve_file_path(def_parser.get_constants_file())
	
	if cns_path != "":
		cns_parser = preload("res://scripts/mugen/cns_parser.gd").new()
		if cns_parser.parse_file(cns_path):
			ai_triggers = cns_parser.get_ai_triggers()
			print("Loaded CNS: ", cns_path.get_file(), " (", ai_triggers.size(), " AI triggers)")
		else:
			emit_signal("loading_error", "Failed to parse CNS file: " + cns_path)
	else:
		print("No constants file specified in DEF")

func _resolve_file_path(relative_path: String) -> String:
	"""Resolve relative file path based on character directory"""
	if relative_path.is_empty():
		return ""
	
	var full_path = character_path.path_join(relative_path)
	if FileAccess.file_exists(full_path):
		return full_path
	
	# Try different extensions if file not found
	var base_path = full_path.get_basename()
	var extensions = [".sff", ".air", ".cmd", ".cns", ".def"]
	
	for ext in extensions:
		var test_path = base_path + ext
		if FileAccess.file_exists(test_path):
			return test_path
	
	return ""

func _finalize_loading():
	"""Complete the loading process"""
	is_loading = false
	is_loaded = true
	emit_signal("loading_progress", "Complete", 1.0)
	emit_signal("loading_complete", true)
	print("Character loading complete: ", character_name)

# Public API methods
func get_character_name() -> String:
	return character_name

func get_character_info() -> Dictionary:
	return character_info

func get_sprite_parser() -> SFFParser:
	return sff_parser

func get_animation_parser() -> AIRParser:
	return air_parser

func get_command_parser() -> CMDParser:
	return cmd_parser

func get_cns_parser():
	return cns_parser

func get_def_parser() -> DEFParser:
	return def_parser

func get_def_file_paths() -> Dictionary:
	"""Get all file paths from the DEF parser"""
	if def_parser:
		return def_parser.get_file_paths()
	return {}

func get_def_palette_files() -> Array:
	"""Get palette files from the DEF parser"""
	if def_parser:
		return def_parser.get_palette_files()
	return []

func get_def_sound_file() -> String:
	"""Get sound file from the DEF parser"""
	if def_parser:
		return def_parser.get_sound_file()
	return ""

func get_all_state_files() -> Array:
	"""Get all state files from the DEF parser"""
	if def_parser:
		return def_parser.get_state_files()
	return []

func get_all_cns_files() -> Array:
	"""Get all CNS files from the DEF parser"""
	if def_parser:
		return def_parser.get_additional_cns_files()
	return []

func get_palette_dictionary() -> Dictionary:
	"""Get all palette files with their keys"""
	if def_parser:
		return def_parser.get_all_palette_files()
	return {}

# Convenience methods for common operations
func get_sprite_texture(group: int, image: int) -> ImageTexture:
	if sff_parser:
		return sff_parser.get_sprite_texture(group, image)
	return null

func get_animation(anim_id: int) -> Array:
	if air_parser:
		return air_parser.get_animation(anim_id)
	return []

func get_commands() -> Array:
	return commands

func get_ai_triggers() -> Array:
	return ai_triggers

func has_sprites() -> bool:
	return sprites_loaded and sff_parser != null

func has_animations() -> bool:
	return air_parser != null and animations.size() > 0

func has_commands() -> bool:
	return cmd_parser != null and commands.size() > 0

func has_ai() -> bool:
	return cns_parser != null and ai_triggers.size() > 0

# Character stats and properties
func get_health() -> int:
	return character_info.get("life", 1000)

func get_attack() -> int:
	return character_info.get("attack", 100)

func get_defense() -> int:
	return character_info.get("defence", 100)

func get_display_name() -> String:
	return character_info.get("displayname", character_name)

func get_author() -> String:
	return character_info.get("author", "Unknown")

func get_version_date() -> String:
	return character_info.get("versiondate", "")

# Setup a Character node with this data
func setup_character_node(character: Character):
	"""Configure a Character node with this character data"""
	if not is_loaded:
		print("Warning: Character data not fully loaded")
		return
	
	# Set up parsers
	if sff_parser:
		character.set_sff_parser(sff_parser)
	if air_parser:
		character.set_air_parser(air_parser)
	if cmd_parser:
		character.set_cmd_parser(cmd_parser)
	if cns_parser:
		character.set_cns_parser(cns_parser)
	
	# Set character properties
	character.max_health = get_health()
	character.current_health = character.max_health
	character.name = get_display_name()
	
	print("Character node configured: ", get_display_name())

# Debug and validation
func validate() -> Dictionary:
	"""Validate the loaded character data"""
	var validation = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	if not is_loaded:
		validation.errors.append("Character not loaded")
		validation.valid = false
	
	if not has_sprites():
		validation.errors.append("No sprites loaded")
		validation.valid = false
	
	if not has_animations():
		validation.warnings.append("No animations loaded")
	
	if not has_commands():
		validation.warnings.append("No commands loaded")
	
	if not has_ai():
		validation.warnings.append("No AI logic loaded")
	
	return validation

func print_summary():
	"""Print a summary of the loaded character data"""
	print("=== Character Data Summary ===")
	print("Name: ", get_display_name())
	print("Author: ", get_author())
	print("Path: ", character_path)
	print("Health: ", get_health())
	print("Sprites: ", "Yes" if has_sprites() else "No")
	print("Animations: ", animations.size() if has_animations() else 0)
	print("Commands: ", commands.size() if has_commands() else 0)
	print("AI Triggers: ", ai_triggers.size() if has_ai() else 0)
	print("==============================")
