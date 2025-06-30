extends RefCounted
class_name SFFLoader

## MUGEN SFF Loader Utility
## Provides a simplified interface for loading and managing SFF files
## Handles automatic version detection and provides unified access to sprites

signal sff_loaded(file_path: String, sprite_count: int)
signal sff_load_failed(file_path: String, error: String)
signal sprite_batch_loaded(file_path: String, loaded_count: int, total_count: int)

# Cache for loaded SFF parsers
static var _sff_cache: Dictionary = {}
static var _cache_enabled: bool = true

enum SFFVersion {
	UNKNOWN = 0,
	V1 = 1,
	V2 = 2
}

enum LoadResult {
	SUCCESS = 0,
	FILE_NOT_FOUND = 1,
	INVALID_FORMAT = 2,
	PARSE_ERROR = 3,
	VERSION_UNSUPPORTED = 4
}

class SFFInfo:
	var file_path: String
	var version: SFFVersion
	var sprite_count: int
	var group_count: int
	var parser: SFFParser
	var load_time: float
	var file_size: int
	
	func _init(path: String, ver: SFFVersion, sprites: int, groups: int, sff_parser: SFFParser):
		file_path = path
		version = ver
		sprite_count = sprites
		group_count = groups
		parser = sff_parser
		load_time = Time.get_ticks_msec() / 1000.0
		
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			file_size = file.get_length()
			file.close()
		else:
			file_size = 0

## Load an SFF file and return SFFInfo object
static func load_sff(file_path: String, use_cache: bool = true) -> SFFInfo:
	"""Load an SFF file with automatic version detection and caching"""
	
	# Check cache first
	if use_cache and _cache_enabled and _sff_cache.has(file_path):
		var cached_info = _sff_cache[file_path]
		print("📦 Using cached SFF: %s" % file_path)
		return cached_info
	
	print("🔄 Loading SFF file: %s" % file_path)
	
	# Validate file exists
	if not FileAccess.file_exists(file_path):
		print("❌ SFF file not found: %s" % file_path)
		return null
	
	# Detect SFF version first
	var version = detect_sff_version(file_path)
	if version == SFFVersion.UNKNOWN:
		print("❌ Unknown SFF version for file: %s" % file_path)
		return null
	
	print("🔍 Detected SFF version: %s" % _version_to_string(version))
	
	# Create parser and load
	var parser = SFFParser.new()
	var start_time = Time.get_ticks_msec()
	
	# Connect to parser signals for progress tracking
	var loader_instance = SFFLoader.new()
	parser.parsing_complete.connect(loader_instance._on_parsing_complete.bind(file_path))
	parser.parsing_error.connect(loader_instance._on_parsing_error.bind(file_path))
	parser.sprite_loaded.connect(loader_instance._on_sprite_loaded.bind(file_path))
	
	var success = parser.parse_sff_file(file_path)
	
	if not success:
		print("❌ Failed to parse SFF file: %s" % file_path)
		return null
	
	var load_time = (Time.get_ticks_msec() - start_time) / 1000.0
	print("✅ SFF loaded in %.2fs: %d sprites" % [load_time, parser.sprites.size()])
	
	# Create SFF info
	var sff_info = SFFInfo.new(
		file_path,
		version,
		parser.sprites.size(),
		parser.get_groups().size(),
		parser
	)
	
	# Cache the result
	if use_cache and _cache_enabled:
		_sff_cache[file_path] = sff_info
	
	return sff_info

## Detect SFF version without full parsing
static func detect_sff_version(file_path: String) -> SFFVersion:
	"""Detect SFF version by examining file header"""
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return SFFVersion.UNKNOWN
	
	# Check minimum file size
	if file.get_length() < 20:
		file.close()
		return SFFVersion.UNKNOWN
	
	file.set_big_endian(false)
	
	# Read signature (12 bytes)
	var signature = file.get_buffer(12)
	var sig_str = signature.get_string_from_ascii().substr(0, 11)
	
	if not sig_str.begins_with("ElecbyteSpr"):
		file.close()
		return SFFVersion.UNKNOWN
	
	# Read version bytes
	var ver3 = file.get_8()
	var ver2 = file.get_8() 
	var ver1 = file.get_8()
	var ver0 = file.get_8()
	
	file.close()
	
	# Version detection based on Ikemen GO logic
	# Ver0 contains the main version number
	match ver0:
		1:
			return SFFVersion.V1
		2:
			return SFFVersion.V2
		_:
			print("⚠️ Unknown SFF version bytes: %d.%d.%d.%d" % [ver0, ver1, ver2, ver3])
			return SFFVersion.UNKNOWN

## Get sprite texture from loaded SFF
static func get_sprite_texture(sff_info: SFFInfo, group: int, image: int) -> Texture2D:
	"""Get a sprite texture from a loaded SFF file"""
	if not sff_info or not sff_info.parser:
		return null
	
	return sff_info.parser.get_sprite_texture(group, image)

## Get sprite data dictionary from loaded SFF
static func get_sprite_data(sff_info: SFFInfo, group: int, image: int) -> Dictionary:
	"""Get sprite data dictionary from a loaded SFF file"""
	if not sff_info or not sff_info.parser:
		return {}
	
	return sff_info.parser.get_sprite_data(group, image)

## Get all available sprites from loaded SFF
static func get_available_sprites(sff_info: SFFInfo) -> Array:
	"""Get list of all available sprites as [group, image] pairs"""
	if not sff_info or not sff_info.parser:
		return []
	
	return sff_info.parser.get_available_sprites()

## Get all sprite groups from loaded SFF
static func get_sprite_groups(sff_info: SFFInfo) -> Array:
	"""Get list of all sprite groups"""
	if not sff_info or not sff_info.parser:
		return []
	
	return sff_info.parser.get_groups()

## Check if specific sprite exists
static func has_sprite(sff_info: SFFInfo, group: int, image: int) -> bool:
	"""Check if a specific sprite exists in the SFF file"""
	if not sff_info or not sff_info.parser:
		return false
	
	var sprite_index = sff_info.parser.get_sprite_index(group, image)
	return sprite_index != -1

## Preload multiple SFF files
static func preload_sff_files(file_paths: Array[String]) -> Dictionary:
	"""Preload multiple SFF files and return dictionary of SFFInfo objects"""
	var loaded_sffs = {}
	var total_files = file_paths.size()
	
	print("🔄 Preloading %d SFF files..." % total_files)
	
	for i in range(total_files):
		var file_path = file_paths[i]
		print("📦 Loading %d/%d: %s" % [i + 1, total_files, file_path])
		
		var sff_info = load_sff(file_path, true)
		if sff_info:
			loaded_sffs[file_path] = sff_info
			print("✅ Loaded: %d sprites" % sff_info.sprite_count)
		else:
			print("❌ Failed: %s" % file_path)
	
	print("✅ Preloading complete: %d/%d files loaded" % [loaded_sffs.size(), total_files])
	return loaded_sffs

## Batch load sprites for better performance
static func batch_load_sprites(sff_info: SFFInfo, sprite_list: Array) -> Dictionary:
	"""Load multiple sprites at once for better performance"""
	var loaded_sprites = {}
	
	if not sff_info or not sff_info.parser:
		return loaded_sprites
	
	print("🎯 Batch loading %d sprites..." % sprite_list.size())
	
	for sprite_def in sprite_list:
		if sprite_def.size() < 2:
			continue
			
		var group = sprite_def[0]
		var image = sprite_def[1]
		var key = "%d,%d" % [group, image]
		
		var texture = sff_info.parser.get_sprite_texture(group, image)
		if texture:
			loaded_sprites[key] = texture
	
	print("✅ Batch loaded %d textures" % loaded_sprites.size())
	return loaded_sprites

## Get SFF file information
static func get_sff_info_summary(sff_info: SFFInfo) -> Dictionary:
	"""Get summary information about a loaded SFF file"""
	if not sff_info:
		return {}
	
	return {
		"file_path": sff_info.file_path,
		"version": _version_to_string(sff_info.version),
		"sprite_count": sff_info.sprite_count,
		"group_count": sff_info.group_count,
		"file_size_mb": sff_info.file_size / (1024.0 * 1024.0),
		"load_time_sec": sff_info.load_time
	}

## Validate SFF file integrity
static func validate_sff_file(file_path: String) -> Dictionary:
	"""Validate SFF file integrity and return status information"""
	var result = {
		"valid": false,
		"version": SFFVersion.UNKNOWN,
		"error": "",
		"sprite_count": 0,
		"file_size": 0
	}
	
	# Check file exists
	if not FileAccess.file_exists(file_path):
		result.error = "File not found"
		return result
	
	# Get file size
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		result.error = "Cannot open file"
		return result
	
	result.file_size = file.get_length()
	file.close()
	
	# Detect version
	result.version = detect_sff_version(file_path)
	if result.version == SFFVersion.UNKNOWN:
		result.error = "Unknown or invalid SFF format"
		return result
	
	# Try to parse header only
	var parser = SFFParser.new()
	var temp_file = FileAccess.open(file_path, FileAccess.READ)
	if not temp_file:
		result.error = "Cannot read file for validation"
		return result
	
	parser.file_buffer = temp_file
	var header_valid = parser._parse_header()
	
	if header_valid:
		result.sprite_count = parser.header.image_count
		result.valid = true
	else:
		result.error = "Invalid header format"
	
	temp_file.close()
	return result

## Clear SFF cache
static func clear_cache():
	"""Clear the SFF file cache"""
	_sff_cache.clear()
	print("🧹 SFF cache cleared")

## Get cache statistics
static func get_cache_stats() -> Dictionary:
	"""Get cache statistics"""
	var total_sprites = 0
	var total_size = 0
	
	for sff_info in _sff_cache.values():
		total_sprites += sff_info.sprite_count
		total_size += sff_info.file_size
	
	return {
		"cached_files": _sff_cache.size(),
		"total_sprites": total_sprites,
		"total_size_mb": total_size / (1024.0 * 1024.0),
		"cache_enabled": _cache_enabled
	}

## Enable/disable caching
static func set_cache_enabled(enabled: bool):
	"""Enable or disable SFF file caching"""
	_cache_enabled = enabled
	if not enabled:
		clear_cache()

## Helper function to convert version enum to string
static func _version_to_string(version: SFFVersion) -> String:
	match version:
		SFFVersion.V1:
			return "v1.0"
		SFFVersion.V2:
			return "v2.0"
		_:
			return "unknown"

# Signal handlers for progress tracking
func _on_parsing_complete(file_path: String, total_sprites: int):
	sff_loaded.emit(file_path, total_sprites)

func _on_parsing_error(file_path: String, error: String):
	sff_load_failed.emit(file_path, error)

func _on_sprite_loaded(_file_path: String, _group: int, _image: int, _texture: Texture2D):
	# Could emit batch progress here if needed
	pass

## Create a simple sprite bundle from SFF
static func create_sprite_bundle_from_sff(sff_info: SFFInfo) -> Dictionary:
	"""Create a sprite bundle dictionary compatible with the existing sprite system"""
	if not sff_info or not sff_info.parser:
		return {}
	
	return sff_info.parser.get_all_sprite_data()

## Load character SFF with common validation
static func load_character_sff(character_path: String, character_name: String = "") -> SFFInfo:
	"""Load SFF file for a character with common validation patterns"""
	
	# Try different common SFF file patterns
	var sff_patterns = [
		character_path,  # Direct path
		character_path + "/" + character_name + ".sff",
		character_path + "/" + character_name.to_lower() + ".sff",
		character_path + "/" + character_name.to_upper() + ".sff",
		character_path + "/sprite.sff",
		character_path + "/sprites.sff"
	]
	
	for pattern in sff_patterns:
		if FileAccess.file_exists(pattern):
			print("🎭 Found character SFF: %s" % pattern)
			var sff_info = load_sff(pattern)
			
			if sff_info:
				# Validate character has basic sprites
				var has_basic_sprites = (
					has_sprite(sff_info, 0, 0) or  # Standing
					has_sprite(sff_info, 5000, 0)  # Portrait
				)
				
				if has_basic_sprites:
					print("✅ Character SFF validated: %d sprites" % sff_info.sprite_count)
					return sff_info
				else:
					print("⚠️ Character SFF missing basic sprites")
			
			break
	
	print("❌ No valid character SFF found for: %s" % character_name)
	return null

## Quick sprite existence check
static func quick_sprite_check(file_path: String, group: int, image: int) -> bool:
	"""Quickly check if a sprite exists without full loading (uses cache if available)"""
	
	if _cache_enabled and _sff_cache.has(file_path):
		var cached_sff_info = _sff_cache[file_path]
		return has_sprite(cached_sff_info, group, image)
	
	# If not cached, we'd need to load it
	var sff_info = load_sff(file_path)
	if sff_info:
		return has_sprite(sff_info, group, image)
	
	return false
