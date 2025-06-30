extends RefCounted
class_name SelectDefParser

## MUGEN Select.def Parser - Character select screen configuration

var characters: Array = []
var stages: Array = []
var config: Dictionary = {}
var grid_config: Dictionary = {}

func parse_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		print("Select.def file not found: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open select.def file: ", file_path)
		return false
	
	var current_section = ""
	var in_characters = false
	var in_stages = false
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with(";"):
			continue
		
		# Remove inline comments (everything after first ; that's not in quotes)
		var comment_pos = _find_comment_position(line)
		if comment_pos != -1:
			line = line.substr(0, comment_pos).strip_edges()
		
		# Skip if line became empty after comment removal
		if line.is_empty():
			continue
		
		# Section detection
		if line.begins_with("["):
			current_section = line.to_lower()
			in_characters = (current_section == "[characters]")
			in_stages = (current_section == "[extrastages]")
			continue
		
		# Parse based on current section
		if in_characters:
			_parse_character_line(line)
		elif in_stages:
			_parse_stage_line(line)
		elif current_section == "[select info]":
			_parse_config_line(line)
	
	file.close()
	return true

func _parse_character_line(line: String):
	# Format: kfm, stages/kfm.def, music=sound/kfm.mp3
	# Format: random  (for random select)
	# Format: kfm, stages/kfm.def, order=1
	
	if line == "random":
		characters.append({
			"name": "random",
			"type": "random",
			"def_path": "",
			"stage": "",
			"music": "",
			"order": 9999
		})
		return
	
	var parts = line.split(",")
	if parts.size() == 0:
		return
	
	var char_data = {
		"name": parts[0].strip_edges(),
		"type": "character",
		"def_path": "",
		"stage": "",
		"music": "",
		"order": characters.size()
	}
	
	# Parse additional parameters
	for i in range(1, parts.size()):
		var part = parts[i].strip_edges()
		
		if part.begins_with("stages/") or part.ends_with(".def"):
			char_data.stage = part
		elif part.begins_with("music="):
			char_data.music = part.substr(6)
		elif part.begins_with("order="):
			char_data.order = int(part.substr(6))
		elif not part.is_empty() and not part.begins_with("music") and not part.begins_with("order"):
			# Assume it's the character def path if no prefix
			char_data.def_path = part
	
	characters.append(char_data)

func _parse_stage_line(line: String):
	# Format: stages/mybg.def
	stages.append({
		"def_path": line.strip_edges(),
		"name": line.get_file().get_basename()
	})

func _parse_config_line(line: String):
	if "=" in line:
		var parts = line.split("=", false, 1)
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			config[key] = value
			
			# Parse grid configuration
			if key == "rows":
				grid_config.rows = int(value)
			elif key == "columns":
				grid_config.columns = int(value)
			elif key == "cell.size":
				var coords = value.split(",")
				if coords.size() >= 2:
					grid_config.cell_size = Vector2(
						float(coords[0].strip_edges()),
						float(coords[1].strip_edges())
					)

func _find_comment_position(line: String) -> int:
	"""Find the position of a comment (;) that's not inside quotes"""
	var in_quotes = false
	var escape_next = false
	
	for i in range(line.length()):
		var character = line[i]
		
		if escape_next:
			escape_next = false
			continue
		
		if character == "\\":
			escape_next = true
			continue
		
		if character == "\"":
			in_quotes = !in_quotes
			continue
		
		if character == ";" and not in_quotes:
			return i
	
	return -1

# Getter methods
func get_characters() -> Array:
	return characters

func get_stages() -> Array:
	return stages

func get_character_count() -> int:
	return characters.size()

func get_character_by_name(name: String) -> Dictionary:
	for character in characters:
		if character.name == name:
			return character
	return {}

func get_grid_config() -> Dictionary:
	return grid_config

func get_select_config() -> Dictionary:
	return config

func get_ordered_characters() -> Array:
	var ordered = characters.duplicate()
	ordered.sort_custom(func(a, b): return a.order < b.order)
	return ordered

func get_character_grid_positions() -> Array:
	# Calculate grid positions for character portraits
	var positions = []
	var chars = get_ordered_characters()
	var columns = grid_config.get("columns", 8)
	var cell_size = grid_config.get("cell_size", Vector2(32, 32))
	
	for i in range(chars.size()):
		var row = i / columns
		var col = i % columns
		positions.append({
			"character": chars[i],
			"grid_pos": Vector2(col, row),
			"screen_pos": Vector2(col * cell_size.x, row * cell_size.y)
		})
	
	return positions

# Debug method
func print_select_data():
	print("=== MUGEN Select Data ===")
	print("Characters: ", characters.size())
	for character in characters:
		print("  ", character.name, " (", character.type, ") - ", character.def_path)
	print("Stages: ", stages.size())
	print("Grid: ", grid_config)
	print("=========================")
