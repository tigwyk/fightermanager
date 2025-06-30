extends RefCounted
class_name DEFParser

## MUGEN DEF (Definition) File Parser
## Parses character and stage definition files

signal parsing_complete(data: Dictionary)
signal parsing_error(message: String)

# DEF file sections
enum SectionType {
	INFO,
	FILES,
	ARCADE,
	VERSUS,
	PALETTES,
	UNKNOWN
}

class DEFSection:
	var type: SectionType
	var name: String
	var properties: Dictionary = {}

var sections: Array[DEFSection] = []
var parsed_data: Dictionary = {}

func parse_def_file(file_path: String) -> Dictionary:
	"""Parse a DEF file and return structured data"""
	print("📄 Parsing DEF file: ", file_path)

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		parsing_error.emit("Failed to open DEF file: " + file_path)
		return {}

	var content := ""
	var ok := false
	file.seek(0)
	var raw = file.get_buffer(file.get_length())
	file.close()

	# Try UTF-8 first
	content = raw.get_string_from_utf8()
	if _is_reasonable_text(content):
		ok = true
	else:
		# Try Windows-1252 (ANSI)
		content = raw.get_string_from_ascii() # Godot's ASCII is close to Windows-1252/ISO-8859-1 for most MUGEN files
		if _is_reasonable_text(content):
			ok = true

	if not ok:
		parsing_error.emit("Failed to decode DEF file as UTF-8 or ANSI/ASCII: " + file_path)
		return {}

	_parse_content(content)
	_build_structured_data()

	parsing_complete.emit(parsed_data)
	print("✅ DEF parsing complete: %d sections" % sections.size())

	return parsed_data

func _is_reasonable_text(text: String) -> bool:
	# Heuristic: at least 90% printable or whitespace
	if text.is_empty():
		return false
	var printable = 0
	for i in text.length():
		var c = text.unicode_at(i)
		if (c >= 32 and c <= 126) or c == 9 or c == 10 or c == 13:
			printable += 1
	return float(printable) / float(text.length()) > 0.9

func _parse_content(content: String):
	"""Parse DEF file content into sections"""
	var lines = content.split("\n")
	var current_section: DEFSection = null
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			continue
		
		# Check for section header
		if line.begins_with("[") and line.ends_with("]"):
			current_section = DEFSection.new()
			current_section.name = line.substr(1, line.length() - 2).to_lower()
			current_section.type = _get_section_type(current_section.name)
			sections.append(current_section)
			continue
		
		# Parse property line
		if current_section and "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges().to_lower()
				var value = parts[1].strip_edges()
				
				# Remove inline comments (everything after ;)
				var comment_pos = value.find(";")
				if comment_pos != -1:
					value = value.substr(0, comment_pos).strip_edges()
				
				# Remove quotes if present
				if value.begins_with("\"") and value.ends_with("\""):
					value = value.substr(1, value.length() - 2)
				
				current_section.properties[key] = value

func _get_section_type(section_name: String) -> SectionType:
	"""Determine section type from name"""
	match section_name:
		"info":
			return SectionType.INFO
		"files":
			return SectionType.FILES
		"arcade":
			return SectionType.ARCADE
		"versus":
			return SectionType.VERSUS
		"palettes":
			return SectionType.PALETTES
		_:
			return SectionType.UNKNOWN

func _build_structured_data():
	"""Build structured data dictionary from parsed sections"""
	parsed_data.clear()
	
	for section in sections:
		parsed_data[section.name] = section.properties

func get_character_info() -> Dictionary:
	"""Get character information from INFO section"""
	if parsed_data.has("info"):
		return parsed_data["info"]
	return {}

func get_file_paths() -> Dictionary:
	"""Get file paths from FILES section"""
	if parsed_data.has("files"):
		return parsed_data["files"]
	return {}

func get_sprite_file() -> String:
	"""Get sprite file path"""
	var files = get_file_paths()
	return files.get("sprite", "")

func get_animation_file() -> String:
	"""Get animation file path"""
	var files = get_file_paths()
	return files.get("anim", "")

func get_command_file() -> String:
	"""Get command file path"""
	var files = get_file_paths()
	return files.get("cmd", "")

func get_constants_file() -> String:
	"""Get constants/states file path"""
	var files = get_file_paths()
	return files.get("cns", "")

func get_sound_file() -> String:
	"""Get sound file path"""
	var files = get_file_paths()
	return files.get("sound", "")

func get_palette_files() -> Array[String]:
	"""Get list of palette files"""
	var palettes: Array[String] = []
	
	if parsed_data.has("palettes"):
		var palette_section = parsed_data["palettes"]
		for key in palette_section.keys():
			if key.begins_with("pal"):
				palettes.append(palette_section[key])
	
	return palettes

func get_character_name() -> String:
	"""Get character display name"""
	var info = get_character_info()
	return info.get("displayname", info.get("name", "Unknown"))

func get_character_author() -> String:
	"""Get character author"""
	var info = get_character_info()
	return info.get("author", "Unknown")

func get_character_version() -> String:
	"""Get character version"""
	var info = get_character_info()
	return info.get("versiondate", info.get("version", "Unknown"))

func get_character_mugen_version() -> String:
	"""Get required MUGEN version"""
	var info = get_character_info()
	return info.get("mugenversion", "Unknown")

func get_localcoord() -> Vector2i:
	"""Get character's local coordinate system"""
	var info = get_character_info()
	var localcoord = info.get("localcoord", "320,240")
	
	var parts = localcoord.split(",")
	if parts.size() >= 2:
		return Vector2i(parts[0].to_int(), parts[1].to_int())
	
	return Vector2i(320, 240)  # Default MUGEN resolution

func is_valid_character() -> bool:
	"""Check if this is a valid character DEF file"""
	var info = get_character_info()
	var files = get_file_paths()
	
	# Must have basic required sections and files
	return not info.is_empty() and not files.is_empty() and not get_sprite_file().is_empty()

func is_valid_stage() -> bool:
	"""Check if this is a valid stage DEF file"""
	# Stage DEFs have different structure
	var files = get_file_paths()
	return files.has("spr") or files.has("sprite")

func get_stage_sprite_file() -> String:
	"""Get stage sprite file path"""
	var files = get_file_paths()
	return files.get("spr", files.get("sprite", ""))

func get_stage_background_file() -> String:
	"""Get stage background definition file"""
	var files = get_file_paths()
	return files.get("bgdef", "")

func get_state_files() -> Array[String]:
	"""Get all state files (st, st1, st2, etc.)"""
	var state_files: Array[String] = []
	var files = get_file_paths()
	
	# Get common state file
	var stcommon = files.get("stcommon", "")
	if stcommon != "":
		state_files.append(stcommon)
	
	# Get numbered state files
	for key in files.keys():
		if key.begins_with("st") and key != "stcommon":
			state_files.append(files[key])
	
	return state_files

func get_all_palette_files() -> Dictionary:
	"""Get all palette files with their keys"""
	var palettes: Dictionary = {}
	var files = get_file_paths()
	
	for key in files.keys():
		if key.begins_with("pal"):
			palettes[key] = files[key]
	
	return palettes

func get_additional_cns_files() -> Array[String]:
	"""Get additional CNS files beyond the main one"""
	var cns_files: Array[String] = []
	var files = get_file_paths()
	
	# Get main CNS
	var main_cns = get_constants_file()
	if main_cns != "":
		cns_files.append(main_cns)
	
	# Get stcommon (often a CNS file)
	var stcommon = files.get("stcommon", "")
	if stcommon != "" and stcommon != main_cns:
		cns_files.append(stcommon)
	
	return cns_files

func debug_print():
	"""Print parsed data for debugging"""
	print("🔍 DEF File Contents:")
	for section_name in parsed_data.keys():
		print("  [%s]" % section_name)
		var section_data = parsed_data[section_name]
		for key in section_data.keys():
			print("    %s = %s" % [key, section_data[key]])
