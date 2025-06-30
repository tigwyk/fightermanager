extends RefCounted
class_name SFFParser

## MUGEN SFF (Sprite File Format) Parser for Godot 4.4
## Handles both SFF v1.0 and v2.0 formats with PCX sprite extraction

signal sprite_loaded(group: int, image: int, texture: Texture2D)
signal parsing_complete(total_sprites: int)
signal parsing_error(message: String)

# SFF Header structure
class SFFHeader:
	var signature: String
	var version_0: int  # Major version
	var version_1: int
	var version_2: int  
	var version_3: int
	var version_lo: int  # For compatibility
	var version_hi: int  # For compatibility
	var detected_version: int  # Parsed version (1 or 2)
	var group_count: int
	var image_count: int
	var subheader_offset: int
	var subheader_length: int
	var palette_type: int
	var reserved: PackedByteArray

# SFF Sprite/Subfile structure
class SFFSprite:
	var next_offset: int
	var length: int
	var x: int
	var y: int
	var group: int
	var image: int
	var linked_index: int
	var palette_type: int
	var data: PackedByteArray
	# SFF v2 additional fields
	var width: int = 0
	var height: int = 0
	var format: int = 0
	var color_depth: int = 0
	var data_offset: int = 0
	
	func is_linked() -> bool:
		return linked_index != -1

# Palette management - Enhanced for multi-palette support
class PaletteManager:
	var palettes: Array[PackedColorArray] = []  # All loaded palettes
	var palette_assignments: Dictionary = {}    # Group → palette_index mapping
	var default_palette: PackedColorArray
	
	func _init():
		# Create default grayscale palette
		default_palette = PackedColorArray()
		for i in range(256):
			var val = float(i) / 255.0
			var alpha = 0.0 if i == 0 else 1.0  # Color 0 is transparent
			default_palette.append(Color(val, val, val, alpha))
	
	func add_palette(palette: PackedColorArray) -> int:
		"""Add a palette and return its index"""
		if palette.size() == 256:
			palettes.append(palette)
			return palettes.size() - 1
		return -1
	
	func get_palette(index: int) -> PackedColorArray:
		"""Get palette by index"""
		if index >= 0 and index < palettes.size():
			return palettes[index]
		return default_palette
	
	func assign_group_palette(group: int, palette_index: int):
		"""Assign a specific palette to a group"""
		palette_assignments[group] = palette_index
	
	func get_palette_for_group(group: int) -> PackedColorArray:
		"""Get the appropriate palette for a sprite group"""
		# Check for explicit assignment first
		if palette_assignments.has(group):
			return get_palette(palette_assignments[group])
		
		# Default: use group number as palette index (common MUGEN pattern)
		var palette_index = min(group, palettes.size() - 1)
		return get_palette(palette_index)

var palette_manager: PaletteManager
var shared_palette: PackedColorArray  # Keep for backward compatibility

# Parsing state
var file_buffer: FileAccess
var header: SFFHeader
var sprites: Array[SFFSprite] = []
var sprite_lookup: Dictionary = {} # [group][image] -> sprite_index
var sprite_textures: Dictionary = {} # Cache for SFF v2 PNG textures [group][image] -> Texture2D

func parse_sff_file(file_path: String) -> bool:
	"""Parse an SFF file and extract all sprites"""
	# Temporary debug output enabled to diagnose issues
	print("🎨 Parsing SFF file: ", file_path)
	
	file_buffer = FileAccess.open(file_path, FileAccess.READ)
	if not file_buffer:
		parsing_error.emit("Failed to open SFF file: " + file_path)
		return false
	
	# Parse header
	if not _parse_header():
		file_buffer.close()
		return false
	
	# Display essential info for debugging
	print("📊 SFF Info: v%d.%d, %d groups, %d images" % [
		header.version_hi, header.version_lo, 
		header.group_count, header.image_count
	])
	
	# Parse sprites based on version
	var success = false
	if header.detected_version == 1:
		print("🔍 Using SFF v1 parsing for file")
		success = _parse_sff_v1()
	elif header.detected_version == 2:
		print("🔍 Using SFF v2 parsing for file")
		success = _parse_sff_v2()
	else:
		parsing_error.emit("Unsupported SFF version: v%d.%d.%d.%d" % [header.version_0, header.version_1, header.version_2, header.version_3])
	
	file_buffer.close()
	
	if success:
		_build_sprite_lookup()
		parsing_complete.emit(sprites.size())
		# Only log completion for critical errors
		# print("✅ SFF parsing complete: %d sprites loaded" % sprites.size())
	
	return success

func _parse_header() -> bool:
	"""Parse SFF header using Ikemen GO reference implementation"""
	if file_buffer.get_length() < 36:  # Minimum header size
		parsing_error.emit("SFF file too small")
		return false

	header = SFFHeader.new()
	
	# Ensure we're at the beginning and using little-endian
	file_buffer.seek(0)
	file_buffer.set_big_endian(false)

	# Read signature (12 bytes: "ElecbyteSpr" + null terminator)
	var sig_bytes = file_buffer.get_buffer(12)
	header.signature = ""
	for i in range(11):  # Only first 11 bytes, ignore null terminator
		var byte = sig_bytes[i]
		if byte >= 32 and byte <= 126:  # Printable ASCII range
			header.signature += char(byte)
		else:
			header.signature += "?"  # Replace non-printable with ?

	if not header.signature.begins_with("ElecbyteSpr"):
		parsing_error.emit("Invalid SFF signature: " + header.signature + " (expected 'ElecbyteSpr')")
		return false

	# Read version bytes (Ver3, Ver2, Ver1, Ver0) - Ikemen GO style
	header.version_3 = file_buffer.get_8()
	header.version_2 = file_buffer.get_8() 
	header.version_1 = file_buffer.get_8()
	header.version_0 = file_buffer.get_8()
	
	# Skip reserved/dummy bytes (4 bytes) 
	file_buffer.get_buffer(4)
	
	# Use Ver0 for version detection like Ikemen GO
	# Ver0 = 1 means SFF v1, Ver0 = 2 means SFF v2
	header.detected_version = header.version_0
	
	# Special case: Some files have version [0,1,0,1] which should be treated as v1
	if header.version_0 == 0 and header.version_1 == 1 and header.version_2 == 0 and header.version_3 == 1:
		print("🔧 Detected version pattern [0,1,0,1] - treating as SFF v1")
		header.detected_version = 1
	
	# Temporary debug to check version detection
	print("🔍 SFF Version detection: Ver0=%d, Ver1=%d, Ver2=%d, Ver3=%d -> detected as v%d" % [
		header.version_0, header.version_1, header.version_2, header.version_3, header.detected_version
	])

	# Parse header fields based on version using Ikemen GO logic
	match header.detected_version:
		1:
			return _parse_sff_v1_header_ikemen()
		2:
			return _parse_sff_v2_header_ikemen()
		_:
			parsing_error.emit("Unsupported SFF version: %d" % header.detected_version)
			return false

func _parse_sff_v1_header_ikemen():
	"""Parse SFF v1 header using Ikemen GO reference"""
	# Ikemen GO SFF v1 header layout (from image.go:503-529):
	# After signature(12) + version(4) + reserved(4) = 20 bytes read so far
	# Position 20: First palette header offset (4 bytes) - always 0 for v1
	# Position 24: Number of palettes (4 bytes) - always 0 for v1  
	# Position 28: Number of sprites (4 bytes)
	# Position 32: First sprite header offset (4 bytes)
	# Position 36: Subheader length (4 bytes)
	
	var first_palette_offset = file_buffer.get_32()  # Should be 0 for v1
	var num_palettes = file_buffer.get_32()  # Should be 0 for v1
	header.image_count = file_buffer.get_32()  # Number of sprites
	header.subheader_offset = file_buffer.get_32()  # First sprite header offset
	header.subheader_length = file_buffer.get_32()  # Subheader length
	
	# Store palette info for offset calculation
	header.palette_type = first_palette_offset  # Reuse this field
	header.reserved = PackedByteArray()
	header.reserved.resize(4)
	header.reserved.encode_u32(0, num_palettes)  # Store num_palettes
	
	# Set sensible defaults for v1
	header.group_count = 0  # Not used in v1
	
	# Debug output to verify parsing matches Ikemen GO
	print("🔍 SFF v1 header: palette_offset=%d, num_palettes=%d, sprites=%d, header_offset=%d, length=%d" % [
		first_palette_offset, num_palettes, header.image_count, header.subheader_offset, header.subheader_length
	])
	
	print("🔧 File buffer position after header: %d, file length: %d" % [file_buffer.get_position(), file_buffer.get_length()])
	
	# Ikemen GO validation: palette fields should be 0 for v1
	if first_palette_offset != 0 or num_palettes != 0:
		print("⚠️ SFF v1 file has non-zero palette fields - might be corrupted")
		# Don't fail here - some files might have this and still work
	
	# Validate sprite count and offset
	if header.image_count <= 0 or header.image_count > 50000:
		parsing_error.emit("Invalid sprite count in SFF v1: %d" % header.image_count)
		return false
	
	# More lenient validation for sprite header offset
	if header.subheader_offset <= 0:
		print("⚠️ SFF v1 has invalid sprite header offset: %d - calculating from palette data" % header.subheader_offset)
		# For this SFF v1 file format: sprite headers come after palette data
		# We have: palette_offset=30, num_palettes=512
		var stored_palette_offset = header.palette_type  # We stored it here
		var stored_num_palettes = header.reserved.decode_u32(0)  # We stored it here
		
		# Each palette is typically 768 bytes (256 colors * 3 RGB bytes)
		var palette_size = 768 * stored_num_palettes  # 768 * 512 = 393,216 bytes
		header.subheader_offset = stored_palette_offset + palette_size
		print("🔧 Calculated sprite header offset: %d (palette_start=%d + palette_size=%d)" % [header.subheader_offset, stored_palette_offset, palette_size])
	
	if header.subheader_offset >= file_buffer.get_length():
		print("⚠️ Calculated offset beyond file - trying alternative layout")
		# Alternative: sprite headers might be at a fixed offset after main header
		header.subheader_offset = 40  # Try right after main header
		print("🔧 Using fallback offset: %d" % header.subheader_offset)
	
	print("🔧 SFF v1 validation passed - proceeding with parsing")
	return true

func _parse_sff_v2_header_ikemen():
	"""Parse SFF v2 header - TESTING byte order fix"""
	# After signature(12) + version(4) + reserved(4) = 20 bytes read so far
	# Testing theory: maybe SFF v2 uses big-endian for some fields
	
	# Skip 16 bytes of dummy/reserved data (4 x 4 bytes)
	file_buffer.get_32()
	file_buffer.get_32()
	file_buffer.get_32()
	file_buffer.get_32()
	
	# Try reading with little-endian first (current approach)
	var sprite_offset_le = file_buffer.get_32()  
	var sprite_count_le = file_buffer.get_32()
	var palette_offset_le = file_buffer.get_32()
	var palette_count_le = file_buffer.get_32()
	
	# Reset and try big-endian for the same fields
	file_buffer.seek(36)
	file_buffer.set_big_endian(true)
	var sprite_offset_be = file_buffer.get_32()  
	var sprite_count_be = file_buffer.get_32()
	var palette_offset_be = file_buffer.get_32()
	var palette_count_be = file_buffer.get_32()
	file_buffer.set_big_endian(false)  # Reset to little-endian
	
	print("🔍 SFF v2 header byte order test:")
	print("  Little-endian: offset=%d, count=%d, pal_offset=%d, pal_count=%d" % [
		sprite_offset_le, sprite_count_le, palette_offset_le, palette_count_le
	])
	print("  Big-endian:    offset=%d, count=%d, pal_offset=%d, pal_count=%d" % [
		sprite_offset_be, sprite_count_be, palette_offset_be, palette_count_be
	])
	
	# For now, use little-endian values but we know count is wrong
	header.subheader_offset = sprite_offset_le  # 3936 (correct based on our testing)
	header.image_count = sprite_count_le  # 2801 (wrong - should be ~164)
	header.group_count = palette_offset_le  # Store palette offset
	
	# Skip remaining fields for now
	file_buffer.get_32()  # lofs
	file_buffer.get_32()  # dummy
	file_buffer.get_32()  # tofs
	
	# TEMPORARY FIX: Since we know the actual sprite count should be 164 for Guile,
	# let's count sprites dynamically instead of trusting the header
	print("� Attempting to count sprites dynamically...")
	var actual_sprite_count = _count_valid_sprites(header.subheader_offset)
	
	if actual_sprite_count > 0 and actual_sprite_count != header.image_count:
		print("⚠️ Header sprite count mismatch! Header says %d, found %d" % [header.image_count, actual_sprite_count])
		print("🔧 Using actual count: %d" % actual_sprite_count)
		header.image_count = actual_sprite_count
	
	# Validation
	if header.image_count <= 0 or header.image_count > 50000:
		parsing_error.emit("Invalid sprite count in SFF v2: %d" % header.image_count)
		return false
	
	if header.subheader_offset <= 48 or header.subheader_offset >= file_buffer.get_length():
		parsing_error.emit("Invalid sprite header offset in SFF v2: %d" % header.subheader_offset)
		return false
	
	return true

func _parse_sff_v1() -> bool:
	"""Parse SFF v1 sprites with enhanced palette support"""
	print("🎨 Starting SFF v1 parsing with palette extraction...")
	
	# Initialize palette manager
	palette_manager = PaletteManager.new()
	
	# First, extract palettes from the file using prototype logic
	_extract_sff_v1_palettes()
	
	# Then parse sprites using existing logic but with enhanced fallbacks
	return _parse_sff_v1_sprites()

func _extract_sff_v1_palettes():
	"""Extract multiple palettes from SFF v1 file like the prototype"""
	print("🎨 Extracting palettes from SFF v1...")
	
	# Get palette info from header (stored during header parsing)
	var palette_offset = header.palette_type  # We stored first_palette_offset here
	var num_palettes = header.reserved.decode_u32(0)  # We stored num_palettes here
	
	print("🔍 Palette info: offset=%d, count=%d" % [palette_offset, num_palettes])
	
	# Validate palette data
	if palette_offset <= 0 or num_palettes <= 0:
		print("⚠️ No valid palette data found, using default palette")
		return
	
	var file_size = file_buffer.get_length()
	var total_palette_size = num_palettes * 768  # Each palette is 768 bytes (256 * 3 RGB)
	
	if palette_offset + total_palette_size > file_size:
		print("⚠️ Palette data would exceed file size, limiting palette count")
		var max_palettes: int = (file_size - palette_offset) / 768
		max_palettes = int(max_palettes)
		num_palettes = max_palettes
		print("🔧 Reduced palette count to: %d" % num_palettes)
	
	# Read palettes
	file_buffer.seek(palette_offset)
	
	for i in range(num_palettes):
		var palette = PackedColorArray()
		
		# Read 256 RGB triplets
		for j in range(256):
			if file_buffer.get_position() + 3 > file_size:
				print("⚠️ Reached end of file while reading palette %d" % i)
				break
				
			var r = file_buffer.get_8()
			var g = file_buffer.get_8() 
			var b = file_buffer.get_8()
			
			# Color 0 is transparent in MUGEN
			var alpha = 0.0 if j == 0 else 1.0
			palette.append(Color(r / 255.0, g / 255.0, b / 255.0, alpha))
		
		# Add palette if complete
		if palette.size() == 256:
			var palette_index = palette_manager.add_palette(palette)
			print("  ✅ Loaded palette %d (index %d)" % [i, palette_index])
		else:
			print("  ❌ Incomplete palette %d (only %d colors)" % [i, palette.size()])
			break
	
	print("🎨 Palette extraction complete: %d palettes loaded" % palette_manager.palettes.size())

func _parse_sff_v1_sprites() -> bool:
	"""Parse SFF v1 sprites with enhanced fallback mechanisms"""
	print("📖 Starting SFF v1 sprite parsing with enhanced logic")

	# Read shared palette if present (for backward compatibility)
	if header.palette_type == 1:
		print("🎨 Reading legacy shared palette...")
		_read_shared_palette_v1()
		print("✅ Legacy shared palette loaded")

	# Try standard sprite header parsing first
	var sprites_loaded = _try_standard_sprite_headers()
	
	# If standard parsing failed, use PCX scanning fallback
	if sprites_loaded == 0:
		print("🔧 Standard sprite headers failed, using PCX scanning fallback...")
		sprites_loaded = _try_pcx_scanning_fallback()
	
	if sprites_loaded > 0:
		print("✅ SFF v1 sprite parsing complete: %d sprites loaded" % sprites_loaded)
		return true
	else:
		parsing_error.emit("Failed to load any sprites from SFF v1 file")
		return false

func _try_standard_sprite_headers() -> int:
	"""Try to parse sprite headers using standard method"""
	print("📋 Attempting standard sprite header parsing at offset %d..." % header.subheader_offset)
	
	# Check if offset is valid before seeking
	if header.subheader_offset < 0 or header.subheader_offset >= file_buffer.get_length():
		print("⚠️ Invalid subheader offset: %d (file length: %d)" % [header.subheader_offset, file_buffer.get_length()])
		return 0
		
	file_buffer.seek(header.subheader_offset)
	var sprites_loaded = 0

	print("🔄 Parsing %d sprites using standard headers..." % header.image_count)
	for i in range(header.image_count):
		# Check if we can read the full sprite entry (32 bytes)
		if file_buffer.get_position() + 32 > file_buffer.get_length():
			print("⚠️ File truncated while reading sprite %d header" % i)
			break
			
		var sprite = SFFSprite.new()

		sprite.next_offset = file_buffer.get_32()
		sprite.length = file_buffer.get_32()
		sprite.x = file_buffer.get_16()
		sprite.y = file_buffer.get_16()
		sprite.group = file_buffer.get_16()
		sprite.image = file_buffer.get_16()
		sprite.linked_index = file_buffer.get_16()
		sprite.palette_type = file_buffer.get_8()
		file_buffer.get_buffer(13)  # reserved

		# Validate sprite data
		if not _validate_sprite_header(sprite, i):
			print("⚠️ Invalid sprite header %d, aborting standard parsing" % i)
			break

		# Handle linked sprites
		if sprite.linked_index != 0:
			sprite.linked_index = sprite.linked_index - 1
		else:
			sprite.linked_index = -1

		# Assign group-based palette
		if palette_manager and palette_manager.palettes.size() > 0:
			var palette_index = min(sprite.group, palette_manager.palettes.size() - 1)
			sprite.palette_type = palette_index  # Store palette index in palette_type

		sprites.append(sprite)
		sprites_loaded += 1

	return sprites_loaded

func _validate_sprite_header(sprite: SFFSprite, _index: int) -> bool:
	"""Validate a sprite header for reasonableness"""
	# Check for reasonable values
	if sprite.group < 0 or sprite.group > 1000:
		return false
	if sprite.image < 0 or sprite.image > 1000:
		return false
	if sprite.length < 0 or sprite.length > 1000000:  # 1MB max
		return false
	if sprite.next_offset != 0 and sprite.next_offset < header.subheader_offset:
		return false
	
	return true

func _try_pcx_scanning_fallback() -> int:
	"""Scan for PCX headers directly in the file (prototype logic)"""
	print("🔍 Scanning file for PCX headers as fallback...")
	
	var file_size = file_buffer.get_length()
	var pcx_positions: Array = []
	
	# Scan entire file for PCX manufacturer byte (0x0A)
	file_buffer.seek(0)
	var file_data = file_buffer.get_buffer(file_size)
	
	for i in range(file_size - 128):  # Need at least 128 bytes for PCX header
		if file_data[i] == 10:  # PCX manufacturer byte
			# Validate PCX header
			var pcx_info = _validate_pcx_header_at_position(file_data, i)
			if pcx_info != null:
				pcx_positions.append(pcx_info)
	
	print("🔍 Found %d potential PCX sprite locations" % pcx_positions.size())
	
	# Create sprites from PCX positions
	var sprites_loaded = 0
	var max_sprites = min(pcx_positions.size(), header.image_count)
	
	for i in range(max_sprites):
		var pcx_info = pcx_positions[i]
		var sprite = SFFSprite.new()
		
		# Assign group/image numbers based on position
		sprite.group = i / 10 as int  # Rough grouping like prototype
		sprite.image = i % 10
		sprite.x = 0
		sprite.y = 0
		sprite.next_offset = pcx_info.offset
		sprite.length = 0  # Calculate on demand
		sprite.linked_index = -1
		
		# Assign group-based palette
		if palette_manager and palette_manager.palettes.size() > 0:
			var palette_index = min(sprite.group, palette_manager.palettes.size() - 1)
			sprite.palette_type = palette_index
		
		sprites.append(sprite)
		sprites_loaded += 1
		
		print("    ✅ Created sprite [%d,%d] %dx%d from PCX at %d" % [
			sprite.group, sprite.image, pcx_info.width, pcx_info.height, pcx_info.offset
		])
	
	return sprites_loaded

func _validate_pcx_header_at_position(file_data: PackedByteArray, offset: int) -> Dictionary:
	"""Validate and extract info from a PCX header at the given position"""
	if offset + 16 >= file_data.size():
		return {}
	
	var manufacturer = file_data[offset]
	var _version = file_data[offset + 1]
	var encoding = file_data[offset + 2]
	var bpp = file_data[offset + 3]
	
	# Must be PCX with 8-bit color depth
	if manufacturer != 10 or bpp != 8:
		return {}
	
	# Extract dimensions
	var xmin = file_data[offset + 4] | (file_data[offset + 5] << 8)
	var ymin = file_data[offset + 6] | (file_data[offset + 7] << 8)
	var xmax = file_data[offset + 8] | (file_data[offset + 9] << 8)
	var ymax = file_data[offset + 10] | (file_data[offset + 11] << 8)
	
	var width = xmax - xmin + 1
	var height = ymax - ymin + 1
	
	# Check for reasonable dimensions
	if width <= 0 or height <= 0 or width > 2048 or height > 2048:
		return {}
	
	return {
		"offset": offset,
		"width": width,
		"height": height,
		"encoding": encoding
	}

func _parse_sff_v2() -> bool:
	"""Parse SFF version 2.0 with PNG sprite data using Ikemen GO approach"""
	print("🔄 Parsing SFF v2 sprites using Ikemen GO logic...")
	
	if header.image_count == 0:
		print("⚠️ No sprites to load")
		return true
	
	# Start reading sprite headers from subheader offset
	file_buffer.seek(header.subheader_offset)
	print("📍 Reading %d sprite headers from offset %d" % [header.image_count, header.subheader_offset])
	
	# Read sprite directory/headers - Ikemen GO format
	for i in range(header.image_count):
		var sprite = SFFSprite.new()
		
		# SFF v2 sprite header format (26 bytes + 2 padding = 28 bytes total per entry):
		# Based on precise analysis of Guile.sff 
		# Group (2 bytes), Number (2 bytes), Width (2 bytes), Height (2 bytes)
		# X offset (2 bytes), Y offset (2 bytes), Index link (2 bytes), Format (1 byte)  
		# Color depth (1 byte), Data offset (4 bytes), Data length (4 bytes)
		# Palette index (2 bytes), Flags (2 bytes), Padding (2 bytes)
		# TOTAL: 28 bytes per sprite header
		
		sprite.group = file_buffer.get_16()  # Little endian
		sprite.image = file_buffer.get_16()
		
		sprite.width = file_buffer.get_16()
		sprite.height = file_buffer.get_16()
		
		sprite.x = file_buffer.get_16()  # X offset
		sprite.y = file_buffer.get_16()  # Y offset
		
		var link = file_buffer.get_16()  # Index link
		sprite.format = file_buffer.get_8()  # Format: 0=raw, 2=RLE8, 3=RLE5, 4=LZ5, 10=PNG
		sprite.color_depth = file_buffer.get_8()  # Color depth
		
		sprite.data_offset = file_buffer.get_32()
		sprite.length = file_buffer.get_32()
		
		var _palette_index = file_buffer.get_16()  # Palette index
		var _flags = file_buffer.get_16()  # Flags
		var _padding = file_buffer.get_16()  # 2 bytes padding to align to 28-byte boundaries
		
		# Process link index (Ikemen GO logic)
		if link == 0:
			sprite.linked_index = -1  # Not linked
		else:
			sprite.linked_index = link - 1  # Convert to 0-based index
		
		# Debug output - reduced spam
		if i < 5 or i % 1000 == 0:
			print("🎨 Sprite %d: Group=%d, Image=%d, Size=%dx%d, Format=%d, Length=%d" % [
				i, sprite.group, sprite.image, sprite.width, sprite.height, sprite.format, sprite.length
			])
		
		# Initialize data field for SFF v2 sprites
		sprite.data = PackedByteArray()
		
		# Store sprite
		sprites.append(sprite)
		
		# Load sprite data based on format - following Ikemen GO readV2()
		if sprite.length > 0 and sprite.data_offset > 0:
			# Validate data bounds
			if sprite.data_offset >= file_buffer.get_length() or sprite.data_offset + sprite.length > file_buffer.get_length():
				print("❌ Invalid sprite data bounds for sprite %d (offset=%d, length=%d)" % [i, sprite.data_offset, sprite.length])
				continue
				
			match sprite.format:
				10:  # PNG format (SFF v2 standard)
					if not _read_png_sprite_data_v2(i, sprite.data_offset):
						print("⚠️ Failed to read PNG sprite %d" % i)
				0:   # Raw format
					if not _read_raw_sprite_data_v2(i, sprite.data_offset, sprite.width, sprite.height, sprite.color_depth):
						print("⚠️ Failed to read raw sprite %d" % i)
				2, 3, 4:  # RLE8, RLE5, LZ5 - compressed formats
					if not _read_compressed_sprite_data_v2(i, sprite.data_offset, sprite.format, sprite.width, sprite.height, sprite.color_depth):
						print("⚠️ Failed to read compressed sprite %d (format %d)" % [i, sprite.format])
				_:
					# Unsupported format - only log first few to avoid spam
					if i < 5:
						print("⚠️ Unsupported sprite format %d for sprite %d" % [sprite.format, i])
	
	print("✅ SFF v2 parsing complete: %d sprites processed" % sprites.size())
	return true

func _read_png_sprite_data_v2(sprite_index: int, data_offset: int) -> bool:
	"""Read PNG sprite data for SFF v2"""
	var sprite = sprites[sprite_index]
	
	# Validate offset and length
	if data_offset >= file_buffer.get_length() or data_offset + sprite.length > file_buffer.get_length():
		print("❌ Invalid sprite data bounds for sprite %d" % sprite_index)
		return false
	
	# Read PNG data
	file_buffer.seek(data_offset)
	var png_data = file_buffer.get_buffer(sprite.length)
	
	# Validate PNG data
	if png_data == null or png_data.size() == 0:
		print("❌ Empty or null PNG data for sprite %d" % sprite_index)
		return false
	
	# Check if data is actually PNG format by examining header
	if png_data.size() < 8:
		print("❌ Data too small to be PNG for sprite %d (size: %d)" % [sprite_index, png_data.size()])
		return false
	
	# PNG files start with signature: 89 50 4E 47 0D 0A 1A 0A
	var png_signature = PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
	var is_png = true
	for i in range(min(8, png_data.size())):
		if png_data[i] != png_signature[i]:
			is_png = false
			break
	
	if not is_png:
		print("❌ Data is not PNG format for sprite %d (format claimed: %d)" % [sprite_index, sprite.format])
		
		# Show first 8 bytes for debugging
		var actual_bytes = ""
		var expected_bytes = ""
		for i in range(min(8, png_data.size())):
			actual_bytes += "%02X " % png_data[i]
		for i in range(8):
			expected_bytes += "%02X " % png_signature[i]
		
		print("   First 8 bytes: %s" % actual_bytes.strip())
		print("   Expected PNG:  %s" % expected_bytes.strip())
		
		# This might be a misidentified compressed format - try RLE8 instead
		print("   Attempting to parse as RLE8 instead...")
		return _try_parse_as_compressed(sprite_index, data_offset, 2)  # Try RLE8
	
	# Create texture from PNG data using Godot's built-in PNG loader
	var image = Image.new()
	var error = image.load_png_from_buffer(png_data)
	
	if error != OK:
		print("❌ Failed to load PNG data for sprite %d (error %d)" % [sprite_index, error])
		# Try as compressed format as fallback
		print("   Attempting to parse as compressed format instead...")
		return _try_parse_as_compressed(sprite_index, data_offset, 2)  # Try RLE8
	
	# Validate image
	if image == null:
		print("❌ Failed to create image for sprite %d" % sprite_index)
		return false
	
	# Create texture
	var texture = ImageTexture.create_from_image(image)
	
	# Validate texture
	if texture == null:
		print("❌ Failed to create texture for sprite %d" % sprite_index)
		return false
	
	# Cache the texture for later retrieval
	if not sprite_textures.has(sprite.group):
		sprite_textures[sprite.group] = {}
	sprite_textures[sprite.group][sprite.image] = texture
	
	# Emit sprite loaded signal
	sprite_loaded.emit(sprite.group, sprite.image, texture)
	
	# No debug output for individual sprite loading to prevent log spam
	
	return true

func _read_shared_palette_v1():
	"""Read shared palette for SFF v1.0"""
	var palette_offset = 36  # After header
	file_buffer.seek(palette_offset)
	
	shared_palette = PackedColorArray()
	for i in range(256):
		var r = file_buffer.get_8()
		var g = file_buffer.get_8() 
		var b = file_buffer.get_8()
		shared_palette.append(Color8(r, g, b, 255))

func _read_sprite_data_v1(sprite_index: int, data_offset: int) -> bool:
	"""Read sprite data for SFF v1.0"""
	var sprite = sprites[sprite_index]
	
	# Skip sprites with zero length (they are likely linked or empty)
	if sprite.length == 0:
		# print("  ⏭️ Skipping sprite with zero length")
		return true
	
	# Minimal debug output - only for critical issues
	# print("  📍 Seeking to offset %d for sprite length %d (file size: %d)" % [data_offset, sprite.length, file_buffer.get_length()])
	
	# Validate sprite length is reasonable (max 1MB per sprite)
	if sprite.length > 1048576:
		parsing_error.emit("Sprite length %d seems unreasonable (>1MB), possible parsing error" % sprite.length)
		return false
	
	if data_offset >= file_buffer.get_length():
		parsing_error.emit("Data offset %d exceeds file size %d" % [data_offset, file_buffer.get_length()])
		return false
	
	if data_offset + sprite.length > file_buffer.get_length():
		parsing_error.emit("Sprite data would exceed file bounds: offset %d + length %d > file size %d" % [data_offset, sprite.length, file_buffer.get_length()])
		return false
	
	file_buffer.seek(data_offset)
	sprite.data = file_buffer.get_buffer(sprite.length)
	
	if sprite.data == null:
		parsing_error.emit("Failed to read sprite data for %d,%d (buffer returned null)" % [sprite.group, sprite.image])
		return false
	
	if sprite.data.size() != sprite.length:
		parsing_error.emit("Failed to read sprite data for %d,%d (expected %d bytes, got %d)" % [sprite.group, sprite.image, sprite.length, sprite.data.size()])
		return false

	return true

func _build_sprite_lookup():
	"""Build lookup table for quick sprite access"""
	sprite_lookup.clear()
	
	for i in range(sprites.size()):
		var sprite = sprites[i]
		if not sprite_lookup.has(sprite.group):
			sprite_lookup[sprite.group] = {}
		sprite_lookup[sprite.group][sprite.image] = i

func get_sprite_texture(group: int, image: int) -> Texture2D:
	"""Get a sprite as a Godot Texture2D (supports both SFF v1 PCX and SFF v2 PNG)"""
	if not sprite_lookup.has(group) or not sprite_lookup[group].has(image):
		print("⚠️ Sprite not found: %d,%d" % [group, image])
		return null

	# For SFF v2, check if we have a cached PNG texture
	if sprite_textures.has(group) and sprite_textures[group].has(image):
		var cached_texture = sprite_textures[group][image]
		# Reduced debug output to prevent log spam
		# print("🎯 Retrieved cached PNG texture for sprite %d,%d: %dx%d" % [
		# 	group, image, cached_texture.get_width(), cached_texture.get_height()
		# ])
		return cached_texture

	var sprite_index = sprite_lookup[group][image]
	var sprite = sprites[sprite_index]

	# Handle linked sprites
	if sprite.is_linked():
		if sprite.linked_index >= 0 and sprite.linked_index < sprites.size():
			sprite = sprites[sprite.linked_index]
			# Also check if the linked sprite has a cached texture
			if sprite_textures.has(sprite.group) and sprite_textures[sprite.group].has(sprite.image):
				return sprite_textures[sprite.group][sprite.image]
		else:
			print("⚠️ Invalid linked sprite index: %d" % sprite.linked_index)
			return null

	# For SFF v1 sprites with PCX data
	if sprite.data != null and sprite.data.size() > 0:
		# Parse PCX data and create texture (SFF v1 logic)
		var pcx_parser = PCXParser.new()
		var image_data = pcx_parser.parse_pcx_data(sprite.data)

		if not image_data:
			print("⚠️ Failed to parse PCX data for sprite %d,%d" % [group, image])
			return null

		# Apply palette (Ikemen GO: fallback to PCX VGA palette if SFF/linked palette is missing)
		var palette = _get_palette_for_sprite(sprite)
		if palette.size() == 0:
			# Try to extract VGA palette from PCX data
			palette = pcx_parser.extract_vga_palette(sprite.data)
			if palette.size() > 0:
				print("🎨 Using VGA palette from PCX for sprite %d,%d" % [group, image])
			else:
				print("⚠️ No palette found for sprite %d,%d, using grayscale fallback" % [group, image])
		if palette.size() > 0:
			image_data = _apply_palette(image_data, palette)

		# Create texture
		var texture = ImageTexture.new()
		if texture == null:
			print("⚠️ Failed to create ImageTexture for sprite %d,%d" % [group, image])
			return null
		
		if image_data == null:
			print("⚠️ Image data is null for sprite %d,%d" % [group, image])
			return null
			
		texture.set_image(image_data)

		sprite_loaded.emit(group, image, texture)
		return texture
	else:
		print("⚠️ No sprite data available for %d,%d (may be SFF v2 PNG that failed to load)" % [group, image])
		return null

func _get_palette_for_sprite(sprite: SFFSprite) -> PackedColorArray:
	"""Get the appropriate palette for a sprite using enhanced palette manager"""
	# Initialize palette manager if needed
	if not palette_manager:
		palette_manager = PaletteManager.new()
	
	# Priority 1: Use shared palette for backward compatibility
	if sprite.palette_type == 1 and shared_palette.size() > 0:
		return shared_palette
	
	# Priority 2: Use group-based palette assignment
	return palette_manager.get_palette_for_group(sprite.group)

func _apply_palette(image: Image, palette: PackedColorArray) -> Image:
	"""Apply palette to indexed image"""
	if image == null:
		print("⚠️ Cannot apply palette to null image")
		return null
		
	if palette == null or palette.size() == 0:
		print("⚠️ Cannot apply null or empty palette")
		return image
		
	if image.get_format() != Image.FORMAT_L8:
		return image  # Already has color
	
	var width = image.get_width()
	var height = image.get_height()
	var colored_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	for y in range(height):
		for x in range(width):
			var index = image.get_pixel(x, y).r8
			if index < palette.size():
				colored_image.set_pixel(x, y, palette[index])
			else:
				colored_image.set_pixel(x, y, Color.MAGENTA)  # Error color
	
	return colored_image

func get_available_sprites() -> Array:
	"""Get list of all available sprites as [group, image] pairs"""
	var sprite_list = []
	for group in sprite_lookup.keys():
		for image in sprite_lookup[group].keys():
			sprite_list.append([group, image])
	return sprite_list

func get_groups() -> Array:
	"""Get list of all sprite groups"""
	return sprite_lookup.keys()

func get_images_in_group(group: int) -> Array:
	"""Get list of all images in a specific group"""
	if sprite_lookup.has(group):
		return sprite_lookup[group].keys()
	return []

func _debug_hex_dump(start_pos: int, length: int):
	"""Debug function to show hex dump of file data"""
	var saved_pos = file_buffer.get_position()
	file_buffer.seek(start_pos)
	var data = file_buffer.get_buffer(length)
	file_buffer.seek(saved_pos)
	
	var hex_str = ""
	for i in range(min(length, data.size())):
		hex_str += "%02X " % data[i]
		if (i + 1) % 16 == 0:
			hex_str += "\n"
	
	print("🔍 Hex dump at offset %d (%d bytes):\n%s" % [start_pos, length, hex_str])

func _read_raw_sprite_data_v2(sprite_index: int, data_offset: int, width: int, height: int, color_depth: int) -> bool:
	"""Read raw (uncompressed) sprite data for SFF v2"""
	var sprite = sprites[sprite_index]
	
	file_buffer.seek(data_offset)
	var raw_data = file_buffer.get_buffer(sprite.length)
	
	if raw_data == null or raw_data.size() == 0:
		print("❌ Failed to read raw sprite data for sprite %d" % sprite_index)
		return false
	
	# Create image from raw data based on color depth
	var image = Image.new()
	
	match color_depth:
		8:  # 8-bit indexed color
			# For now, just create a placeholder texture since we need palette data
			print("⚠️ 8-bit raw sprites not fully supported yet for sprite %d" % sprite_index)
			return false
		24:  # 24-bit RGB
			image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, raw_data)
		32:  # 32-bit RGBA
			image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, raw_data)
		_:
			print("❌ Unsupported color depth %d for raw sprite %d" % [color_depth, sprite_index])
			return false
	
	var texture = ImageTexture.create_from_image(image)
	if texture == null:
		print("❌ Failed to create texture from raw sprite %d" % sprite_index)
		return false
	
	# Cache the texture
	if not sprite_textures.has(sprite.group):
		sprite_textures[sprite.group] = {}
	sprite_textures[sprite.group][sprite.image] = texture
	
	sprite_loaded.emit(sprite.group, sprite.image, texture)
	return true

func _read_compressed_sprite_data_v2(sprite_index: int, data_offset: int, format: int, width: int, height: int, color_depth: int) -> bool:
	"""Read compressed sprite data for SFF v2 (RLE8, RLE5, LZ5)"""
	
	match format:
		2:  # RLE8
			return _read_rle8_sprite_data_v2(sprite_index, data_offset, width, height, color_depth)
		3:  # RLE5
			return _read_rle5_sprite_data_v2(sprite_index, data_offset, width, height, color_depth)
		4:  # LZ5
			return _read_lz5_sprite_data_v2(sprite_index, data_offset, width, height, color_depth)
		_:
			# Unknown compressed format
			if sprite_index < 5:  # Only log first few to avoid spam
				print("⚠️ Unknown compressed format %d for sprite %d" % [format, sprite_index])
			return false

func _read_rle8_sprite_data_v2(sprite_index: int, data_offset: int, width: int, height: int, color_depth: int) -> bool:
	"""Read and decompress RLE8 sprite data for SFF v2"""
	var sprite = sprites[sprite_index]
	
	# Validate parameters
	if width <= 0 or height <= 0 or color_depth != 8:
		print("❌ Invalid sprite parameters for RLE8 decompression: %dx%d, depth=%d" % [width, height, color_depth])
		return false
	
	# Read compressed data
	file_buffer.seek(data_offset)
	var compressed_data = file_buffer.get_buffer(sprite.length)
	
	if compressed_data == null or compressed_data.size() == 0:
		print("❌ Failed to read RLE8 compressed data for sprite %d" % sprite_index)
		return false
	
	# Decompress RLE8 data
	var decompressed_data = _decompress_rle8(compressed_data, width * height)
	
	if decompressed_data == null or decompressed_data.size() != width * height:
		print("❌ RLE8 decompression failed for sprite %d" % sprite_index)
		return false
	
	# Create image from decompressed palette indices
	# For now, create a grayscale image from the palette indices
	var image = Image.create(width, height, false, Image.FORMAT_L8)
	image.set_data(width, height, false, Image.FORMAT_L8, decompressed_data)
	
	# Convert to RGBA for better compatibility
	image.convert(Image.FORMAT_RGBA8)
	
	# Create texture
	var texture = ImageTexture.create_from_image(image)
	
	if texture == null:
		print("❌ Failed to create texture from RLE8 sprite %d" % sprite_index)
		return false
	
	# Cache the texture
	if not sprite_textures.has(sprite.group):
		sprite_textures[sprite.group] = {}
	sprite_textures[sprite.group][sprite.image] = texture
	
	sprite_loaded.emit(sprite.group, sprite.image, texture)
	
	return true

func _decompress_rle8(compressed_data: PackedByteArray, expected_size: int) -> PackedByteArray:
	"""Decompress RLE8 encoded data (MUGEN SFF v2 format)"""
	var decompressed = PackedByteArray()
	var i = 0
	
	while i < compressed_data.size() and decompressed.size() < expected_size:
		var control_byte = compressed_data[i]
		i += 1
		
		if i >= compressed_data.size():
			break
		
		if control_byte == 0:
			# Literal run: next byte is count, followed by that many literal bytes
			var count = compressed_data[i]
			i += 1
			
			for j in range(count):
				if i >= compressed_data.size() or decompressed.size() >= expected_size:
					break
				decompressed.append(compressed_data[i])
				i += 1
		else:
			# RLE run: control_byte is count, next byte is the value to repeat
			var value = compressed_data[i]
			i += 1
			
			for j in range(control_byte):
				if decompressed.size() >= expected_size:
					break
				decompressed.append(value)
	
	return decompressed
func get_sprite_data(group: int, image: int) -> Dictionary:
	"""Get sprite data as Dictionary for SpriteBundle compatibility"""
	var sprite_index = get_sprite_index(group, image)
	if sprite_index == -1:
		return {}
	
	var sprite = sprites[sprite_index]
	
	# Handle linked sprites
	if sprite.is_linked():
		if sprite.linked_index >= 0 and sprite.linked_index < sprites.size():
			sprite = sprites[sprite.linked_index]
		else:
			print("⚠️ Invalid linked sprite index: %d" % sprite.linked_index)
			return {}
	
	# Try to get cached texture first (for SFF v2 PNG sprites)
	if sprite_textures.has(sprite.group) and sprite_textures[sprite.group].has(sprite.image):
		var texture = sprite_textures[sprite.group][sprite.image]
		var image_data = texture.get_image()
		
		return {
			"image": image_data,
			"x": sprite.x,
			"y": sprite.y,
			"offset_x": sprite.x,
			"offset_y": sprite.y,
			"group": sprite.group,
			"image_num": sprite.image,
			"width": image_data.get_width(),
			"height": image_data.get_height()
		}
	
	# For SFF v1 PCX sprites, create image from data
	if sprite.data != null and sprite.data.size() > 0:
		var pcx_parser = PCXParser.new()
		var image_data = pcx_parser.parse_pcx_data(sprite.data)
		
		if image_data == null:
			print("⚠️ Failed to parse PCX data for sprite %d,%d" % [group, image])
			return {}
		
		# Apply palette
		var palette = _get_palette_for_sprite(sprite)
		if palette.size() == 0:
			palette = pcx_parser.extract_vga_palette(sprite.data)
		
		if palette.size() > 0:
			image_data = _apply_palette(image_data, palette)
		
		return {
			"image": image_data,
			"x": sprite.x,
			"y": sprite.y,
			"offset_x": sprite.x,
			"offset_y": sprite.y,
			"group": sprite.group,
			"image_num": sprite.image,
			"width": image_data.get_width(),
			"height": image_data.get_height()
		}
	
	return {}

func get_sprite_data_safe(group: int, image: int) -> Dictionary:
	"""Safely get sprite data with fallback for corrupted files"""
	var sprite_data = get_sprite_data(group, image)
	
	if sprite_data.is_empty():
		# Create a fallback sprite data
		var fallback_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		fallback_image.fill(Color(0.5, 0.5, 0.5, 1.0))  # Gray placeholder
		
		return {
			"image": fallback_image,
			"x": 0,
			"y": 0,
			"offset_x": 0,
			"offset_y": 0,
			"group": group,
			"image_num": image,
			"width": 64,
			"height": 64
		}
	
	return sprite_data

func create_fallback_sprite_bundle() -> Dictionary:
	"""Create a minimal sprite bundle for characters with corrupted SFF files"""
	var fallback_sprites = {}
	
	# Create basic sprites that most characters need
	var basic_sprites = [
		[0, 0],  # Standing
		[0, 1],  # Standing frame 2
		[5, 0],  # Turning
		[20, 0], # Hit light
		[5000, 0], # Portrait
	]
	
	for sprite_def in basic_sprites:
		var group = sprite_def[0]
		var image = sprite_def[1]
		var key = "%s-%s" % [group, image]
		
		var fallback_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		# Create a colored square based on sprite type
		var color = Color.GRAY
		if group == 0:
			color = Color.BLUE  # Standing sprites
		elif group == 5:
			color = Color.YELLOW  # Action sprites
		elif group == 20:
			color = Color.RED  # Hit sprites
		elif group == 5000:
			color = Color.GREEN  # Portrait
		
		fallback_image.fill(color)
		
		fallback_sprites[key] = {
			"image": fallback_image,
			"x": 0,
			"y": 0,
			"offset_x": 0,
			"offset_y": 0,
			"group": group,
			"image_num": image,
			"width": 64,
			"height": 64
		}
	
	return fallback_sprites

func get_sprite_index(group: int, image: int) -> int:
	"""Get sprite index in the sprites array"""
	if not sprite_lookup.has(group) or not sprite_lookup[group].has(image):
		return -1
	return sprite_lookup[group][image]

func get_all_sprite_data() -> Dictionary:
	"""Get all sprites as Dictionary for SpriteBundle initialization"""
	var all_sprites = {}
	
	for group in sprite_lookup.keys():
		for image_num in sprite_lookup[group].keys():
			var sprite_data = get_sprite_data(group, image_num)
			if not sprite_data.is_empty():
				var key = "%s-%s" % [group, image_num]
				all_sprites[key] = sprite_data
	
	return all_sprites

func _read_rle5_sprite_data_v2(sprite_index: int, data_offset: int, width: int, height: int, _color_depth: int) -> bool:
	"""Read and decompress RLE5 sprite data for SFF v2"""
	var sprite = sprites[sprite_index]
	
	# Validate parameters
	if width <= 0 or height <= 0:
		print("❌ Invalid sprite parameters for RLE5 decompression: %dx%d" % [width, height])
		return false
	
	# Read compressed data
	file_buffer.seek(data_offset)
	var compressed_data = file_buffer.get_buffer(sprite.length)
	
	if compressed_data == null or compressed_data.size() == 0:
		print("❌ Failed to read RLE5 compressed data for sprite %d" % sprite_index)
		return false
	
	# Decompress RLE5 data
	var decompressed_data = _decompress_rle5(compressed_data, width * height)
	
	if decompressed_data == null or decompressed_data.size() != width * height:
		print("❌ RLE5 decompression failed for sprite %d" % sprite_index)
		return false
	
	# Create image from decompressed palette indices
	var image = Image.create(width, height, false, Image.FORMAT_L8)
	image.set_data(width, height, false, Image.FORMAT_L8, decompressed_data)
	
	# Convert to RGBA for better compatibility
	image.convert(Image.FORMAT_RGBA8)
	
	# Create texture
	var texture = ImageTexture.create_from_image(image)
	if texture == null:
		print("❌ Failed to create texture for RLE5 sprite %d" % sprite_index)
		return false
	
	# Store in lookup table
	if not sprite_lookup.has(sprite.group):
		sprite_lookup[sprite.group] = {}
	sprite_lookup[sprite.group][sprite.image] = sprite_index
	
	# Cache texture for quick access
	sprite_textures["%d,%d" % [sprite.group, sprite.image]] = texture
	
	return true

func _decompress_rle5(compressed_data: PackedByteArray, expected_size: int) -> PackedByteArray:
	"""Decompress RLE5 encoded data (MUGEN SFF v2 format)
	
	RLE5 operates on 5-bit control bytes and variable-length runs.
	Format is more complex than RLE8 as it uses bit-packed data.
	"""
	var decompressed = PackedByteArray()
	var i = 0
	
	while i < compressed_data.size() and decompressed.size() < expected_size:
		var control_byte = compressed_data[i]
		i += 1
		
		if i >= compressed_data.size():
			break
		
		# RLE5 format: control byte format is CCCCCXXX where:
		# CCCCC = 5-bit count (0-31)
		# XXX = 3-bit extension or type flag
		
		var count = (control_byte >> 3) & 0x1F  # Extract upper 5 bits
		var type_flag = control_byte & 0x07     # Extract lower 3 bits
		
		if count == 0:
			# Extended count: next byte contains additional count
			if i >= compressed_data.size():
				break
			count = compressed_data[i] + 32  # Add base offset
			i += 1
		
		if type_flag == 0:
			# Literal run: copy next 'count' bytes directly
			for j in range(count):
				if i >= compressed_data.size() or decompressed.size() >= expected_size:
					break
				decompressed.append(compressed_data[i])
				i += 1
		else:
			# RLE run: repeat next byte 'count' times
			if i >= compressed_data.size():
				break
			var value = compressed_data[i]
			i += 1
			
			for j in range(count):
				if decompressed.size() >= expected_size:
					break
				decompressed.append(value)
	
	return decompressed

func _read_lz5_sprite_data_v2(sprite_index: int, data_offset: int, width: int, height: int, _color_depth: int) -> bool:
	"""Read and decompress LZ5 sprite data for SFF v2"""
	var sprite = sprites[sprite_index]
	
	# Validate parameters
	if width <= 0 or height <= 0:
		print("❌ Invalid sprite parameters for LZ5 decompression: %dx%d" % [width, height])
		return false
	
	# Read compressed data
	file_buffer.seek(data_offset)
	var compressed_data = file_buffer.get_buffer(sprite.length)
	
	if compressed_data == null or compressed_data.size() == 0:
		print("❌ Failed to read LZ5 compressed data for sprite %d" % sprite_index)
		return false
	
	# Decompress LZ5 data
	var decompressed_data = _decompress_lz5(compressed_data, width * height)
	
	if decompressed_data == null or decompressed_data.size() != width * height:
		print("❌ LZ5 decompression failed for sprite %d" % sprite_index)
		return false
	
	# Create image from decompressed palette indices
	var image = Image.create(width, height, false, Image.FORMAT_L8)
	image.set_data(width, height, false, Image.FORMAT_L8, decompressed_data)
	
	# Convert to RGBA for better compatibility
	image.convert(Image.FORMAT_RGBA8)
	
	# Create texture
	var texture = ImageTexture.create_from_image(image)
	if texture == null:
		print("❌ Failed to create texture for LZ5 sprite %d" % sprite_index)
		return false
	
	# Store in lookup table
	if not sprite_lookup.has(sprite.group):
		sprite_lookup[sprite.group] = {}
	sprite_lookup[sprite.group][sprite.image] = sprite_index
	
	# Cache texture for quick access
	sprite_textures["%d,%d" % [sprite.group, sprite.image]] = texture
	
	return true

func _decompress_lz5(compressed_data: PackedByteArray, expected_size: int) -> PackedByteArray:
	"""Decompress LZ5 encoded data (MUGEN SFF v2 format)
	
	LZ5 is a simplified LZ77-style compression using 5-bit lengths.
	Format uses control bytes to indicate literal vs back-reference.
	"""
	var decompressed = PackedByteArray()
	var i = 0
	
	while i < compressed_data.size() and decompressed.size() < expected_size:
		var control_byte = compressed_data[i]
		i += 1
		
		if i >= compressed_data.size():
			break
		
		# LZ5 format: control byte format is LLLLLMMM where:
		# LLLLL = 5-bit length (0-31)
		# MMM = 3-bit mode/type
		
		var length = (control_byte >> 3) & 0x1F  # Extract upper 5 bits
		var mode = control_byte & 0x07           # Extract lower 3 bits
		
		if mode == 0:
			# Literal mode: copy next 'length' bytes directly
			if length == 0:
				# Extended length: next byte contains additional length
				if i >= compressed_data.size():
					break
				length = compressed_data[i] + 32
				i += 1
			for j in range(length):
				if i >= compressed_data.size() or decompressed.size() >= expected_size:
					break
				decompressed.append(compressed_data[i])
				i += 1
		else:
			# Back-reference mode: copy from earlier in the output
			if i >= compressed_data.size():
				break
			
			var offset_byte = compressed_data[i]
			i += 1
			
			# Calculate back-reference offset
			var offset = offset_byte + (mode * 256)
			
			if length == 0:
				# Extended length for back-reference
				if i >= compressed_data.size():
					break
				length = compressed_data[i] + 32
				i += 1
			else:
				length += 3  # Minimum match length
			
			# Copy from back-reference
			var start_pos = decompressed.size() - offset
			if start_pos < 0:
				# Invalid back-reference, treat as literal
				print("⚠️ Invalid LZ5 back-reference: offset=%d, pos=%d" % [offset, decompressed.size()])
				continue
			
			for j in range(length):
				if decompressed.size() >= expected_size:
					break
				var ref_pos = start_pos + (j % offset)  # Handle overlapping copies
				if ref_pos < decompressed.size():
					decompressed.append(decompressed[ref_pos])
				else:
					break
	
	return decompressed

func _try_parse_as_compressed(sprite_index: int, data_offset: int, fallback_format: int) -> bool:
	"""Try to parse sprite data as a compressed format when PNG parsing fails"""
	var sprite = sprites[sprite_index]
	
	# Temporarily override the format for parsing
	var original_format = sprite.format
	sprite.format = fallback_format
	
	var success = false
	match fallback_format:
		2:  # RLE8
			success = _read_rle8_sprite_data_v2(sprite_index, data_offset, sprite.width, sprite.height, sprite.color_depth)
		3:  # RLE5
			success = _read_rle5_sprite_data_v2(sprite_index, data_offset, sprite.width, sprite.height, sprite.color_depth)
		4:  # LZ5
			success = _read_lz5_sprite_data_v2(sprite_index, data_offset, sprite.width, sprite.height, sprite.color_depth)
		0:  # Raw
			success = _read_raw_sprite_data_v2(sprite_index, data_offset, sprite.width, sprite.height, sprite.color_depth)
	
	if success:
		print("✅ Successfully parsed sprite %d as format %d instead of PNG" % [sprite_index, fallback_format])
	else:
		# Restore original format
		sprite.format = original_format
		print("❌ Failed to parse sprite %d as fallback format %d" % [sprite_index, fallback_format])
	
	return success

func _count_valid_sprites(sprite_offset: int) -> int:
	"""Count the actual number of valid sprites by parsing headers until we hit invalid data"""
	var saved_pos = file_buffer.get_position()
	var count = 0
	
	file_buffer.seek(sprite_offset)
	
	# Try to parse sprite headers until we hit invalid data
	while count < 10000:  # Safety limit
		var pos = file_buffer.get_position()
		
		# Check if we have enough bytes for a sprite header
		if pos + 28 > file_buffer.get_length():
			break
		
		# Read sprite header (26 bytes + 2 padding)
		var group = file_buffer.get_16()
		var image = file_buffer.get_16()
		var _x = file_buffer.get_16()
		var _y = file_buffer.get_16()
		var width = file_buffer.get_16()
		var height = file_buffer.get_16()
		var _linked_index = file_buffer.get_16()
		var format_val = file_buffer.get_8()
		var _color_depth = file_buffer.get_8()
		var data_offset = file_buffer.get_32()
		var length = file_buffer.get_32()
		file_buffer.get_16()  # Skip 2 bytes padding
		
		# Validate sprite header values
		if (group >= 0 and group <= 9999 and 
			image >= 0 and image <= 9999 and
			width >= 1 and width <= 2048 and
			height >= 1 and height <= 2048 and
			format_val >= 0 and format_val <= 12 and
			data_offset > 0 and data_offset < file_buffer.get_length() and
			length > 0):
			count += 1
		else:
			# Hit invalid sprite header, stop counting
			break
	
	file_buffer.seek(saved_pos)
	return count
