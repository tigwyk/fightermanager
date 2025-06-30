extends RefCounted
class_name AIRParser

## MUGEN AIR (Animation) File Parser
## Parses animation definitions for characters and stages

# Animation frame structure
class AIRFrame:
	var group: int
	var image: int
	var duration: int
	var offset: Vector2 = Vector2.ZERO
	var flip: bool = false

# Animation data: { anim_no: [AIRFrame, ...] }
var animations: Dictionary = {}

func parse_air_file(file_path: String) -> bool:
	animations.clear()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open AIR file: %s" % file_path)
		return false
	var content = file.get_buffer(file.get_length()).get_string_from_utf8()
	file.close()
	_parse_content(content)
	return true

func parse_file(file_path: String) -> bool:
	"""Alias for parse_air_file for consistency"""
	return parse_air_file(file_path)

func _parse_content(content: String):
	var lines = content.split("\n")
	var current_anim = null
	for line in lines:
		line = line.strip_edges()
		
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
		
		if line.begins_with("[Begin Action"):
			var anim_no = int(line.get_slice(" ", 2).replace("]", ""))
			current_anim = []
			animations[anim_no] = current_anim
			continue
		if current_anim != null:
			var parts = line.split(",")
			if parts.size() >= 3:
				var frame = AIRFrame.new()
				frame.group = int(parts[0].strip_edges())
				frame.image = int(parts[1].strip_edges())
				frame.duration = int(parts[2].strip_edges())
				if parts.size() >= 5:
					frame.offset = Vector2(parts[3].to_float(), parts[4].to_float())
				if parts.size() >= 6:
					frame.flip = parts[5].strip_edges() == "H"
				current_anim.append(frame)

func get_animation(anim_no: int) -> Array:
	return animations.get(anim_no, [])

func get_all_animations() -> Dictionary:
	"""Get all animations as a dictionary {anim_no: [AIRFrame, ...]}"""
	return animations

func get_animation_count() -> int:
	"""Get the number of animations loaded"""
	return animations.size()

func has_animation(anim_no: int) -> bool:
	"""Check if a specific animation exists"""
	return animations.has(anim_no)

func get_animation_numbers() -> Array:
	"""Get all animation numbers"""
	return animations.keys()

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
