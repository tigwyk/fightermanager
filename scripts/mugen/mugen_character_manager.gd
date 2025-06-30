extends Node
class_name MugenCharacterManager

## MUGEN Character Manager - Handles loading and caching of character data

signal character_loaded(character_name: String, character_data)
signal character_loading_progress(character_name: String, step: String, progress: float)
signal character_loading_error(character_name: String, error: String)

# Character data cache
var loaded_characters: Dictionary = {}
var loading_queue: Array = []
var currently_loading: String = ""

# Configuration
var max_concurrent_loads: int = 1
var cache_limit: int = 20  # Maximum number of characters to keep in memory

func _ready():
	print("MUGEN Character Manager initialized")

func load_character(def_path: String):
	"""Load a character by DEF file path"""
	var character_name = def_path.get_file().get_basename()
	
	# Add SFF debugging before loading (disabled to reduce log spam)
	# debug_sff_file(character_name, def_path)
	
	# Return from cache if already loaded
	if loaded_characters.has(character_name):
		print("Character loaded from cache: ", character_name)
		return loaded_characters[character_name]
	
	# Create new character data container
	var character_data = preload("res://scripts/mugen/mugen_character_data.gd").new()
	
	# Connect signals with proper parameter mapping
	var captured_name = character_name  # Ensure proper capture
	var captured_data = character_data  # Ensure proper capture
	character_data.loading_progress.connect(func(step: String, progress: float): _on_character_loading_progress(captured_name, step, progress))
	character_data.loading_complete.connect(func(success: bool): _on_character_loading_complete(captured_name, captured_data, success))
	character_data.loading_error.connect(func(error: String): _on_character_loading_error(captured_name, error))
	
	# Start loading
	currently_loading = character_name
	character_data.load_character_async(def_path)
	
	return character_data

func load_character_from_select(character_select_data: Dictionary):
	"""Load a character from select.def character data"""
	var def_path = character_select_data.get("def_path", "")
	if def_path.is_empty():
		# Try to construct path from name
		var char_name = character_select_data.get("name", "")
		if not char_name.is_empty():
			def_path = "assets/mugen/chars/" + char_name + "/" + char_name + ".def"
	
	return load_character(def_path)

func get_character(character_name: String):
	"""Get a loaded character by name"""
	return loaded_characters.get(character_name, null)

func is_character_loaded(character_name: String) -> bool:
	"""Check if a character is loaded in cache"""
	return loaded_characters.has(character_name)

func unload_character(character_name: String):
	"""Remove a character from cache"""
	if loaded_characters.has(character_name):
		loaded_characters.erase(character_name)
		print("Character unloaded: ", character_name)

func clear_cache():
	"""Clear all loaded characters"""
	loaded_characters.clear()
	print("Character cache cleared")

func _on_character_loading_progress(character_name: String, step: String, progress: float):
	emit_signal("character_loading_progress", character_name, step, progress)

func _on_character_loading_complete(character_name: String, character_data, success: bool):
	if success:
		# Add to cache
		loaded_characters[character_name] = character_data
		
		# Enforce cache limit
		_enforce_cache_limit()
		
		print("Character loaded successfully: ", character_name)
		emit_signal("character_loaded", character_name, character_data)
	else:
		print("Character loading failed: ", character_name)
	
	currently_loading = ""

func _on_character_loading_error(character_name: String, error: String):
	print("Character loading error (", character_name, " ): ", error)
	
	# Don't completely fail for SFF errors - characters can still be functional without sprites
	if error.contains("SFF") or error.contains("sprite"):
		print("   SFF error detected - character may still be usable without sprites")
		# Consider this a warning, not a complete failure
		emit_signal("character_loading_error", character_name, "Warning: " + error)
	else:
		# Other errors are more critical
		emit_signal("character_loading_error", character_name, error)
	
	currently_loading = ""

func _enforce_cache_limit():
	"""Remove oldest characters if cache limit exceeded"""
	if loaded_characters.size() > cache_limit:
		var chars_to_remove = loaded_characters.size() - cache_limit
		var character_names = loaded_characters.keys()
		
		for i in range(chars_to_remove):
			var char_name = character_names[i]
			unload_character(char_name)

# Bulk loading operations
func load_characters_from_select_def(select_parser: SelectDefParser):
	"""Load all characters defined in a select.def file"""
	if not select_parser:
		return
	
	var characters = select_parser.get_characters()
	for character in characters:
		if character.type == "character":  # Skip random slots
			load_character_from_select(character)

func preload_common_characters():
	"""Preload commonly used characters (can be customized)"""
	var common_chars = [
		"assets/mugen/chars/kfm/kfm.def",
		"assets/mugen/chars/ryu/ryu.def",
		"assets/mugen/chars/ken/ken.def"
	]
	
	for char_path in common_chars:
		if FileAccess.file_exists(char_path):
			load_character(char_path)

# Factory methods for Character nodes
func create_character_node(character_name: String) -> Character:
	"""Create a Character node configured with the specified character data"""
	var character_data = get_character(character_name)
	if not character_data:
		print("Character not loaded: ", character_name)
		return null
	
	var character_node = Character.new()
	character_data.setup_character_node(character_node)
	return character_node

func create_character_node_from_path(def_path: String) -> Character:
	"""Create a Character node by loading from DEF path"""
	var character_data = load_character(def_path)
	if not character_data:
		return null
	
	# Wait for loading to complete (simplified - in practice you'd use signals)
	var timeout = 5.0  # 5 second timeout
	while character_data.is_loading and timeout > 0:
		await get_tree().process_frame
		timeout -= get_process_delta_time()
	
	if not character_data.is_loaded:
		print("Character loading timed out or failed")
		return null
	
	var character_node = Character.new()
	character_data.setup_character_node(character_node)
	return character_node

# Validation and debugging
func validate_all_characters() -> Dictionary:
	"""Validate all loaded characters"""
	var results = {}
	
	for char_name in loaded_characters:
		var char_data = loaded_characters[char_name]
		results[char_name] = char_data.validate()
	
	return results

func get_character_list() -> Array:
	"""Get list of all loaded character names"""
	return loaded_characters.keys()

func get_cache_info() -> Dictionary:
	"""Get information about the character cache"""
	return {
		"loaded_count": loaded_characters.size(),
		"cache_limit": cache_limit,
		"currently_loading": currently_loading,
		"characters": loaded_characters.keys()
	}

func print_cache_summary():
	"""Print a summary of the character cache"""
	print("=== Character Manager Cache ===")
	print("Loaded Characters: ", loaded_characters.size(), "/", cache_limit)
	print("Currently Loading: ", currently_loading if currently_loading != "" else "None")
	
	for char_name in loaded_characters:
		var char_data = loaded_characters[char_name]
		var status = "✓" if char_data.is_loaded else "⚠"
		print("  ", status, " ", char_name)
	
	print("===============================")

func debug_sff_file(character_name: String, def_path: String):
	"""Debug SFF file for character - Updated with PNG fix validation"""
	print("\n=== DEBUG SFF FILE FOR ", character_name, " (PNG FIX VALIDATION) ===")
	
	# Parse DEF to find SFF path
	var def_parser = preload("res://scripts/mugen/def_parser.gd").new()
	if not def_parser.parse_def_file(def_path):
		print("Could not parse DEF file: ", def_path)
		return
	
	var sff_path = def_parser.get_sprite_file()
	if sff_path.is_empty():
		print("No SFF file found in DEF")
		return
	
	# Make relative path absolute based on DEF location
	if not sff_path.is_absolute_path():
		sff_path = def_path.get_base_dir().path_join(sff_path)
	
	print("SFF file path: ", sff_path)
	
	# Check if file exists
	if not FileAccess.file_exists(sff_path):
		print("SFF file not found: ", sff_path)
		return
	
	# Test the FIXED SFF parser
	print("\n🔧 TESTING FIXED SFF v2 PNG PARSER...")
	var sff_parser = load("res://scripts/mugen/sff_parser.gd").new()
	
	# Connect signals to monitor the fix (reduced logging)
	sff_parser.sprite_loaded.connect(func(group: int, image: int, texture: Texture2D): 
		# Only log first few sprites to reduce spam
		if group == 0 and image < 3:
			print("✅ PNG sprite loaded: Group %d, Image %d, Size %dx%d" % [group, image, texture.get_width(), texture.get_height()])
	)
	sff_parser.parsing_complete.connect(func(total_sprites: int):
		print("🏁 Parsing complete: %d sprites" % total_sprites)
	)
	sff_parser.parsing_error.connect(func(message: String):
		print("❌ Parsing error: %s" % message)
	)
	
	var parse_success = sff_parser.parse_sff_file(sff_path)
	print("📊 Parse result: %s" % ("SUCCESS" if parse_success else "FAILED"))
	
	if parse_success:
		var sprites = sff_parser.get_available_sprites()
		print("📈 Available sprites: %d" % sprites.size())
		
		if sprites.size() > 0:
			print("🎨 Testing PNG texture retrieval (the key fix)...")
			var test_count = min(3, sprites.size())
			var success_count = 0
			
			for i in range(test_count):
				var sprite_info = sprites[i]
				var group = sprite_info[0] 
				var image = sprite_info[1]
				
				var texture = sff_parser.get_sprite_texture(group, image)
				if texture:
					print("   ✅ Sprite %d,%d: %dx%d texture retrieved" % [group, image, texture.get_width(), texture.get_height()])
					success_count += 1
				else:
					print("   ❌ Sprite %d,%d: Failed to retrieve texture" % [group, image])
			
			print("\n🎯 RESULT: %d/%d sprites successfully loaded" % [success_count, test_count])
			if success_count > 0:
				print("🎉 SFF v2 PNG FIX IS WORKING! Character sprites are now loadable!")
			else:
				print("⚠️ PNG fix may need additional debugging")
		else:
			print("⚠️ No sprites found in file")
	
	print("=== END SFF DEBUG ===\n")
