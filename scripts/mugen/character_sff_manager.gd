extends RefCounted
class_name CharacterSFFManager

## Character SFF Manager
## Demonstrates integration of SFFLoader with character management system
## Shows how to handle SFF loading, caching, and sprite access for characters

# Ensure SFFLoader is available
const SFFLoader = preload("res://scripts/mugen/sff_loader.gd")

var loaded_characters: Dictionary = {}
var character_sff_cache: Dictionary = {}

signal character_sff_loaded(character_name: String, sprite_count: int)
signal character_sff_failed(character_name: String, error: String)

## Load SFF for a character with full validation
func load_character_sff(character_name: String, character_path: String) -> bool:
	"""Load and validate SFF file for a character"""
	
	print("🎭 Loading SFF for character: %s" % character_name)
	
	# Check if already loaded
	if loaded_characters.has(character_name):
		print("📦 Character already loaded: %s" % character_name)
		return true
	
	# Load using SFFLoader
	var sff_info = SFFLoader.load_character_sff(character_path, character_name)
	if not sff_info:
		var error = "Failed to load SFF file for character: %s" % character_name
		print("❌ %s" % error)
		character_sff_failed.emit(character_name, error)
		return false
	
	# Validate character has required sprites
	var validation_result = validate_character_sprites(sff_info)
	if not validation_result.valid:
		var error = "Character missing required sprites: %s" % validation_result.missing_sprites
		print("❌ %s" % error)
		character_sff_failed.emit(character_name, error)
		return false
	
	# Store character data
	loaded_characters[character_name] = {
		"sff_info": sff_info,
		"sprite_count": sff_info.sprite_count,
		"validation": validation_result,
		"load_time": Time.get_ticks_msec()
	}
	
	print("✅ Character SFF loaded: %s (%d sprites)" % [character_name, sff_info.sprite_count])
	character_sff_loaded.emit(character_name, sff_info.sprite_count)
	return true

## Validate that character has required sprites
func validate_character_sprites(sff_info) -> Dictionary:
	"""Validate character has required basic sprites"""
	
	var required_sprites = [
		{"group": 0, "image": 0, "name": "Standing"},
		{"group": 5000, "image": 0, "name": "Portrait"},
		{"group": 20, "image": 0, "name": "Hit Light"}
	]
	
	var missing_sprites = []
	var found_sprites = []
	
	for sprite_req in required_sprites:
		if SFFLoader.has_sprite(sff_info, sprite_req.group, sprite_req.image):
			found_sprites.append(sprite_req.name)
		else:
			missing_sprites.append("%s (%d,%d)" % [sprite_req.name, sprite_req.group, sprite_req.image])
	
	return {
		"valid": missing_sprites.size() == 0,
		"found_sprites": found_sprites,
		"missing_sprites": missing_sprites,
		"total_required": required_sprites.size(),
		"found_count": found_sprites.size()
	}

## Get character sprite texture
func get_character_sprite(character_name: String, group: int, image: int) -> Texture2D:
	"""Get a sprite texture for a loaded character"""
	
	if not loaded_characters.has(character_name):
		print("⚠️ Character not loaded: %s" % character_name)
		return null
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	
	return SFFLoader.get_sprite_texture(sff_info, group, image)

## Get character sprite data
func get_character_sprite_data(character_name: String, group: int, image: int) -> Dictionary:
	"""Get sprite data dictionary for a loaded character"""
	
	if not loaded_characters.has(character_name):
		print("⚠️ Character not loaded: %s" % character_name)
		return {}
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	
	return SFFLoader.get_sprite_data(sff_info, group, image)

## Get all sprites for character animation system
func get_character_animation_sprites(character_name: String, group: int, frame_count: int = 10) -> Array:
	"""Get multiple sprites for animation (e.g., walking, standing)"""
	
	var sprites = []
	
	for i in range(frame_count):
		var texture = get_character_sprite(character_name, group, i)
		if texture:
			sprites.append({
				"texture": texture,
				"group": group,
				"image": i,
				"frame": i
			})
		else:
			# Stop when we can't find more frames
			break
	
	return sprites

## Create sprite bundle for character
func create_character_sprite_bundle(character_name: String) -> Dictionary:
	"""Create a complete sprite bundle for a character"""
	
	if not loaded_characters.has(character_name):
		print("⚠️ Character not loaded: %s" % character_name)
		return {}
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	
	return SFFLoader.create_sprite_bundle_from_sff(sff_info)

## Preload multiple characters
func preload_characters(character_list: Array) -> Dictionary:
	"""Preload multiple characters and return success status"""
	
	var results = {}
	
	print("🔄 Preloading %d characters..." % character_list.size())
	
	for character_info in character_list:
		var name = character_info.get("name", "Unknown")
		var path = character_info.get("path", "")
		
		var success = load_character_sff(name, path)
		results[name] = success
		
		if success:
			print("  ✅ %s" % name)
		else:
			print("  ❌ %s" % name)
	
	var successful = results.values().filter(func(x): return x).size()
	print("✅ Preloading complete: %d/%d characters loaded" % [successful, character_list.size()])
	
	return results

## Get character info summary
func get_character_info(character_name: String) -> Dictionary:
	"""Get summary information about a loaded character"""
	
	if not loaded_characters.has(character_name):
		return {}
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	var sff_summary = SFFLoader.get_sff_info_summary(sff_info)
	
	return {
		"name": character_name,
		"sprite_count": character_data.sprite_count,
		"sff_version": sff_summary.version,
		"file_size_mb": sff_summary.file_size_mb,
		"load_time_sec": sff_summary.load_time_sec,
		"validation": character_data.validation,
		"groups": SFFLoader.get_sprite_groups(sff_info).size()
	}

## Get all loaded characters info
func get_all_characters_info() -> Array:
	"""Get info for all loaded characters"""
	
	var characters_info = []
	
	for character_name in loaded_characters.keys():
		characters_info.append(get_character_info(character_name))
	
	return characters_info

## Check if character sprite exists
func has_character_sprite(character_name: String, group: int, image: int) -> bool:
	"""Check if a character has a specific sprite"""
	
	if not loaded_characters.has(character_name):
		return false
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	
	return SFFLoader.has_sprite(sff_info, group, image)

## Get character sprite groups
func get_character_sprite_groups(character_name: String) -> Array:
	"""Get all sprite groups for a character"""
	
	if not loaded_characters.has(character_name):
		return []
	
	var character_data = loaded_characters[character_name]
	var sff_info = character_data.sff_info
	
	return SFFLoader.get_sprite_groups(sff_info)

## Unload character SFF
func unload_character(character_name: String) -> bool:
	"""Unload a character's SFF data"""
	
	if not loaded_characters.has(character_name):
		print("⚠️ Character not loaded: %s" % character_name)
		return false
	
	loaded_characters.erase(character_name)
	print("🗑️ Character unloaded: %s" % character_name)
	return true

## Get memory usage statistics
func get_memory_stats() -> Dictionary:
	"""Get memory usage statistics for loaded characters"""
	
	var total_sprites = 0
	var total_size_mb = 0.0
	
	for character_data in loaded_characters.values():
		total_sprites += character_data.sprite_count
		var sff_summary = SFFLoader.get_sff_info_summary(character_data.sff_info)
		total_size_mb += sff_summary.file_size_mb
	
	return {
		"loaded_characters": loaded_characters.size(),
		"total_sprites": total_sprites,
		"total_size_mb": total_size_mb,
		"cache_stats": SFFLoader.get_cache_stats()
	}

## Clear all loaded characters
func clear_all_characters():
	"""Clear all loaded character data"""
	
	var count = loaded_characters.size()
	loaded_characters.clear()
	print("🧹 Cleared %d loaded characters" % count)

## Example usage for character selection screen
func prepare_character_selection_data() -> Array:
	"""Prepare data for character selection screen"""
	
	var selection_data = []
	
	for character_name in loaded_characters.keys():
		var character_info = get_character_info(character_name)
		
		# Get portrait sprite
		var portrait_texture = get_character_sprite(character_name, 5000, 0)
		
		# Get standing sprite for preview
		var standing_texture = get_character_sprite(character_name, 0, 0)
		
		selection_data.append({
			"name": character_name,
			"portrait": portrait_texture,
			"standing": standing_texture,
			"sprite_count": character_info.sprite_count,
			"has_required_sprites": character_info.validation.valid
		})
	
	return selection_data
