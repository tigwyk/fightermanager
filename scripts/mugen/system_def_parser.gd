extends RefCounted
class_name SystemDefParser

## MUGEN System.def Parser - Extracts UI layout and configuration

var config: Dictionary = {}
var fonts: Dictionary = {}
var sounds: Dictionary = {}
var lifebar_data: Dictionary = {}
var select_data: Dictionary = {}
var system_sff_parser # SFFParser for system sprites
var system_sprites_loaded: bool = false

func parse_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		print("System.def file not found: ", file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Failed to open system.def file: ", file_path)
		return false
	
	var current_section = ""
	var section_data = {}
	
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
		
		# Section headers
		if line.begins_with("[") and line.ends_with("]"):
			# Save previous section
			if current_section != "" and section_data.size() > 0:
				_store_section(current_section, section_data)
			
			current_section = line.substr(1, line.length() - 2).to_lower()
			section_data = {}
			continue
		
		# Key-value pairs
		if "=" in line:
			var parts = line.split("=", false, 1)
			if parts.size() == 2:
				var key = parts[0].strip_edges()
				var value = parts[1].strip_edges()
				
				# Remove quotes if present
				if value.begins_with("\"") and value.ends_with("\""):
					value = value.substr(1, value.length() - 2)
				
				section_data[key] = value
	
	# Store final section
	if current_section != "" and section_data.size() > 0:
		_store_section(current_section, section_data)
	
	file.close()
	
	# Load system sprites after parsing
	_load_system_sprites(file_path.get_base_dir())
	
	print("System.def parsed successfully")
	return true

func _load_system_sprites(system_dir: String):
	"""Load system.sff sprites for UI elements"""
	var files_section = config.get("files", {})
	var sff_filename = files_section.get("spr", "system.sff")
	
	# Handle res:// paths properly
	var sff_path: String
	if system_dir.begins_with("res://"):
		sff_path = system_dir.path_join(sff_filename)
	else:
		sff_path = "res://" + system_dir.path_join(sff_filename)
	
	print("🔧 Attempting to load system.sff from: ", sff_path)
	
	if not FileAccess.file_exists(sff_path):
		print("Warning: system.sff not found at: ", sff_path)
		# Try alternative path without res://
		var alt_path = system_dir.path_join(sff_filename)
		print("🔧 Trying alternative path: ", alt_path)
		if FileAccess.file_exists(alt_path):
			sff_path = alt_path
		else:
			print("❌ system.sff not found at either path")
			return
	
	system_sff_parser = preload("res://scripts/mugen/sff_parser.gd").new()
	print("🔧 Parsing SFF file: ", sff_path)
	if system_sff_parser.parse_sff_file(sff_path):
		system_sprites_loaded = true
		print("✅ System sprites loaded from: ", sff_path)
		var sprite_count = system_sff_parser.get_available_sprites().size()
		print("📊 Loaded ", sprite_count, " sprites")
	else:
		print("❌ Failed to load system sprites from: ", sff_path)

func _store_section(section: String, data: Dictionary):
	match section:
		"info":
			config["info"] = data
		"files":
			config["files"] = data
		"music":
			config["music"] = data
		"font":
			_parse_font_section(data)
		"lifebar":
			_parse_lifebar_section(data)
		"select info":
			_parse_select_info(data)
		"selectbg":
			_parse_select_bg(data)
		"vs screen":
			_parse_vs_screen(data)
		_:
			# Store unknown sections as-is
			config[section] = data

func _parse_font_section(data: Dictionary):
	# Parse font definitions
	for key in data:
		if key.begins_with("font"):
			var font_id = key.get_slice("font", 1)
			if font_id.is_valid_int():
				fonts[int(font_id)] = _parse_font_definition(data[key])

func _parse_font_definition(font_def: String) -> Dictionary:
	# Format: font1 = font/f-4x6.def
	return {
		"file": font_def,
		"type": "def"  # Could be .def or .fnt
	}

func _parse_lifebar_section(data: Dictionary):
	# Parse lifebar/HUD configuration
	lifebar_data = data.duplicate()
	
	# Convert position strings to Vector2
	for key in lifebar_data:
		if key.ends_with(".pos") or key.ends_with("pos"):
			var pos_str = lifebar_data[key]
			if "," in pos_str:
				var coords = pos_str.split(",")
				if coords.size() >= 2:
					lifebar_data[key + "_vector"] = Vector2(
						float(coords[0].strip_edges()),
						float(coords[1].strip_edges())
					)

func _parse_select_info(data: Dictionary):
	select_data["info"] = data.duplicate()

func _parse_select_bg(data: Dictionary):
	select_data["background"] = data.duplicate()

func _parse_vs_screen(data: Dictionary):
	config["vs_screen"] = data.duplicate()

# Getter methods for UI systems
func get_font_path(font_id: int) -> String:
	if fonts.has(font_id):
		return fonts[font_id].file
	return ""

func get_lifebar_config() -> Dictionary:
	return lifebar_data

func get_select_config() -> Dictionary:
	return select_data

func get_vs_screen_config() -> Dictionary:
	return config.get("vs_screen", {})

func get_music_config() -> Dictionary:
	return config.get("music", {})

func get_file_paths() -> Dictionary:
	return config.get("files", {})

func get_title_menu_config() -> Dictionary:
	"""Get title screen menu configuration"""
	var title_info = config.get("title info", {})
	
	var menu_config = {}
	
	# Menu position
	var menu_pos_str = title_info.get("menu.pos", "159,158")
	menu_config["pos"] = _parse_vector2(menu_pos_str)
	
	# Menu item spacing
	var spacing_str = title_info.get("menu.item.spacing", "0,13")
	menu_config["item_spacing"] = _parse_vector2(spacing_str)
	
	# Menu font settings
	menu_config["item_font"] = title_info.get("menu.item.font", "3,0,0")
	menu_config["active_font"] = title_info.get("menu.item.active.font", "3,5,0")
	
	# Menu items
	var items = {}
	items["arcade"] = title_info.get("menu.itemname.arcade", "ARCADE")
	items["versus"] = title_info.get("menu.itemname.versus", "VS MODE")
	items["teamarcade"] = title_info.get("menu.itemname.teamarcade", "TEAM ARCADE")
	items["teamversus"] = title_info.get("menu.itemname.teamversus", "TEAM VS")
	items["teamcoop"] = title_info.get("menu.itemname.teamcoop", "TEAM CO-OP")
	items["survival"] = title_info.get("menu.itemname.survival", "SURVIVAL")
	items["survivalcoop"] = title_info.get("menu.itemname.survivalcoop", "SURVIVAL CO-OP")
	items["training"] = title_info.get("menu.itemname.training", "TRAINING")
	items["watch"] = title_info.get("menu.itemname.watch", "WATCH")
	items["options"] = title_info.get("menu.itemname.options", "OPTIONS")
	items["exit"] = title_info.get("menu.itemname.exit", "EXIT")
	
	menu_config["items"] = items
	
	# Cursor settings
	menu_config["cursor_visible"] = title_info.get("menu.boxcursor.visible", "1") == "1"
	menu_config["cursor_coords"] = title_info.get("menu.boxcursor.coords", "-58,-10,57,2")
	
	# Window settings
	menu_config["window_margins"] = title_info.get("menu.window.margins.y", "12,8")
	menu_config["visible_items"] = int(title_info.get("menu.window.visibleitems", "5"))
	
	# Sound settings
	menu_config["cursor_move_snd"] = title_info.get("cursor.move.snd", "100,0")
	menu_config["cursor_done_snd"] = title_info.get("cursor.done.snd", "100,1")
	menu_config["cancel_snd"] = title_info.get("cancel.snd", "100,2")
	
	return menu_config

func get_title_background_config() -> Dictionary:
	"""Get title screen background configuration"""
	var bg_config = {}
	
	# Background clear color
	var titlebgdef = config.get("titlebgdef", {})
	var clearcolor_str = titlebgdef.get("bgclearcolor", "0,0,0")
	bg_config["clearcolor"] = _parse_color(clearcolor_str)
	
	# Background layers
	var layers = []
	var layer_index = 0
	
	while true:
		var layer_section = "titlebg " + str(layer_index)
		if not config.has(layer_section):
			break
		
		var layer_data = config.get(layer_section, {})
		if layer_data.size() > 0:
			layers.append(layer_data)
		
		layer_index += 1
	
	bg_config["layers"] = layers
	return bg_config

func get_title_fade_config() -> Dictionary:
	"""Get title screen fade configuration"""
	var title_info = config.get("title info", {})
	
	return {
		"fadein_time": int(title_info.get("fadein.time", "10")),
		"fadeout_time": int(title_info.get("fadeout.time", "10"))
	}

func _parse_color(color_str: String) -> Color:
	"""Parse MUGEN color string (R,G,B) to Godot Color"""
	var parts = color_str.split(",")
	if parts.size() >= 3:
		var r = float(parts[0]) / 255.0
		var g = float(parts[1]) / 255.0
		var b = float(parts[2]) / 255.0
		return Color(r, g, b)
	return Color.BLACK

func _parse_vector2(vector_str: String) -> Vector2:
	"""Parse MUGEN vector string (X,Y) to Godot Vector2"""
	var parts = vector_str.split(",")
	if parts.size() >= 2:
		var x = float(parts[0])
		var y = float(parts[1])
		return Vector2(x, y)
	return Vector2.ZERO

# Health bar specific methods
func get_health_bar_pos(player: int) -> Vector2:
	var key = "p" + str(player) + ".pos_vector"
	return lifebar_data.get(key, Vector2.ZERO)

func get_health_bar_size() -> Vector2:
	var range_str = lifebar_data.get("p1.range", "0,0")
	if "," in range_str:
		var coords = range_str.split(",")
		if coords.size() >= 2:
			return Vector2(
				float(coords[0].strip_edges()),
				float(coords[1].strip_edges())
			)
	return Vector2(160, 16)  # Default MUGEN size

func get_timer_pos() -> Vector2:
	return lifebar_data.get("timer.pos_vector", Vector2(160, 20))

func get_round_pos() -> Vector2:
	return lifebar_data.get("round.pos_vector", Vector2(160, 10))

# Debug method
func print_config():
	print("=== MUGEN System Config ===")
	print("Fonts: ", fonts.size())
	for font_id in fonts:
		print("  Font ", font_id, ": ", fonts[font_id].file)
	print("Lifebar keys: ", lifebar_data.size())
	print("Select data: ", select_data.size())
	print("VS Screen: ", config.has("vs_screen"))
	print("==============================")
func get_system_sprite(group: int, image: int) -> Texture2D:
	"""Get a sprite from system.sff"""
	if system_sff_parser and system_sprites_loaded:
		return system_sff_parser.get_sprite_texture(group, image)
	return null

func get_system_sprite_info(group: int, image: int) -> Dictionary:
	"""Get sprite info from system.sff"""
	if system_sff_parser and system_sprites_loaded:
		# Since get_sprite_info doesn't exist, return basic info
		var texture = system_sff_parser.get_sprite_texture(group, image)
		if texture:
			return {
				"group": group,
				"image": image,
				"width": texture.get_width(),
				"height": texture.get_height(),
				"exists": true
			}
	return {"exists": false}

func has_system_sprites() -> bool:
	"""Check if system sprites are loaded"""
	return system_sprites_loaded and system_sff_parser != null

func get_title_cursor_sprite() -> Texture2D:
	"""Get the title screen cursor sprite"""
	# Common MUGEN cursor sprite locations
	var cursor_sprite = get_system_sprite(0, 0)  # Try group 0, image 0
	if not cursor_sprite:
		cursor_sprite = get_system_sprite(1, 0)  # Try group 1, image 0
	return cursor_sprite

func get_title_background_sprites() -> Array:
	"""Get title background sprites from system.sff"""
	var bg_sprites = []
	var bg_config = get_title_background_config()
	
	for layer in bg_config.get("layers", []):
		var sprite_no = layer.get("spriteno", "")
		if not sprite_no.is_empty():
			var sprite_parts = sprite_no.split(",")
			if sprite_parts.size() >= 2:
				var group = int(sprite_parts[0])
				var image = int(sprite_parts[1])
				var sprite = get_system_sprite(group, image)
				if sprite:
					bg_sprites.append({
						"texture": sprite,
						"group": group,
						"image": image,
						"config": layer
					})
	
	return bg_sprites

func get_menu_box_sprites() -> Dictionary:
	"""Get menu box and UI element sprites"""
	return {
		"cursor": get_title_cursor_sprite(),
		"menu_bg": get_system_sprite(0, 1),  # Common menu background
		"select_box": get_system_sprite(0, 2),  # Selection box
		"highlight": get_system_sprite(0, 3)   # Highlight effect
	}

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
