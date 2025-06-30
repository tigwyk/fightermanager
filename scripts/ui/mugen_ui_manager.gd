extends Control
class_name MugenUIManager

## MUGEN-style UI Manager using system.def and select.def configurations

var system_config # SystemDefParser
var select_config # SelectDefParser
var current_screen: String = "select"

# UI Elements
var health_bar_p1: ProgressBar
var health_bar_p2: ProgressBar
var timer_label: Label
var round_label: Label

# Character select
var character_grid: GridContainer
var character_portraits: Array = []

# Portrait loading
var portrait_cache: Dictionary = {}

# System graphics
var system_sprites_loaded: bool = false

signal character_selected(character_data)
signal screen_changed(screen_name)

func _ready():
	# Initialize UI elements
	_setup_battle_hud()
	_setup_character_select()

func load_system_config(system_def_path: String) -> bool:
	system_config = SystemDefParser.new()
	if system_config.parse_file(system_def_path):
		print("Loaded MUGEN system config from: ", system_def_path)
		_apply_system_config()
		return true
	return false

func load_select_config(select_def_path: String) -> bool:
	select_config = SelectDefParser.new()
	if select_config.parse_file(select_def_path):
		print("Loaded MUGEN select config from: ", select_def_path)
		_apply_select_config()
		return true
	return false

func _setup_battle_hud():
	# Create health bars
	health_bar_p1 = ProgressBar.new()
	health_bar_p1.name = "HealthBarP1"
	health_bar_p1.min_value = 0
	health_bar_p1.max_value = 100
	health_bar_p1.value = 100
	health_bar_p1.show_percentage = false
	add_child(health_bar_p1)
	
	health_bar_p2 = ProgressBar.new()
	health_bar_p2.name = "HealthBarP2"
	health_bar_p2.min_value = 0
	health_bar_p2.max_value = 100
	health_bar_p2.value = 100
	health_bar_p2.show_percentage = false
	add_child(health_bar_p2)
	
	# Create timer
	timer_label = Label.new()
	timer_label.name = "Timer"
	timer_label.text = "99"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)
	
	# Create round indicator
	round_label = Label.new()
	round_label.name = "Round"
	round_label.text = "Round 1"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(round_label)

func _setup_character_select():
	# Create character grid
	character_grid = GridContainer.new()
	character_grid.name = "CharacterGrid"
	character_grid.columns = 8  # Default, will be overridden by config
	add_child(character_grid)
	
	# Hide by default
	character_grid.visible = false

func _apply_system_config():
	if not system_config:
		return
	
	# Check if system sprites are available
	system_sprites_loaded = system_config.has_system_sprites()
	
	var health_size = system_config.get_health_bar_size()
	
	# Position health bars using MUGEN config
	var p1_pos = system_config.get_health_bar_pos(1)
	var p2_pos = system_config.get_health_bar_pos(2)
	
	if health_bar_p1:
		health_bar_p1.position = p1_pos
		health_bar_p1.size = health_size
		_apply_health_bar_graphics(health_bar_p1, 1)
	
	if health_bar_p2:
		health_bar_p2.position = p2_pos
		health_bar_p2.size = health_size
		_apply_health_bar_graphics(health_bar_p2, 2)
	
	# Position timer and round indicator
	if timer_label:
		timer_label.position = system_config.get_timer_pos()
		_apply_timer_graphics(timer_label)
	
	if round_label:
		round_label.position = system_config.get_round_pos()
		_apply_round_graphics(round_label)
	
	print("Applied MUGEN system config to UI")

func _apply_health_bar_graphics(health_bar: ProgressBar, player_num: int):
	"""Apply system.sff graphics to health bar"""
	if not system_sprites_loaded:
		return
	
	# Try to get health bar background and fill sprites
	var bar_bg_sprite = system_config.get_system_sprite(100 + player_num, 0)  # Health bar background
	var bar_fill_sprite = system_config.get_system_sprite(100 + player_num, 1)  # Health bar fill
	
	if bar_bg_sprite:
		# Create background using system sprite
		var bg_texture_rect = TextureRect.new()
		bg_texture_rect.texture = bar_bg_sprite
		bg_texture_rect.name = "HealthBarBG"
		bg_texture_rect.z_index = -1
		health_bar.add_child(bg_texture_rect)
	
	if bar_fill_sprite:
		# Apply custom fill texture (more complex, would need custom health bar)
		# For now, just change the health bar color to match MUGEN style
		health_bar.add_theme_color_override("fill", Color.RED)

func _apply_timer_graphics(timer_display: Label):
	"""Apply system.sff graphics to timer display"""
	if not system_sprites_loaded:
		return
	
	# Try to get timer background sprite
	var timer_bg_sprite = system_config.get_system_sprite(200, 0)  # Timer background
	
	if timer_bg_sprite:
		var bg_texture_rect = TextureRect.new()
		bg_texture_rect.texture = timer_bg_sprite
		bg_texture_rect.name = "TimerBG"
		bg_texture_rect.z_index = -1
		timer_display.add_child(bg_texture_rect)

func _apply_round_graphics(round_display: Label):
	"""Apply system.sff graphics to round indicator"""
	if not system_sprites_loaded:
		return
	
	# Try to get round indicator sprites
	var round_bg_sprite = system_config.get_system_sprite(300, 0)  # Round background
	
	if round_bg_sprite:
		var bg_texture_rect = TextureRect.new()
		bg_texture_rect.texture = round_bg_sprite
		bg_texture_rect.name = "RoundBG"
		bg_texture_rect.z_index = -1
		round_display.add_child(bg_texture_rect)

func _apply_select_config():
	if not select_config:
		return
	
	var grid_config = select_config.get_grid_config()
	var characters = select_config.get_characters()
	
	# Configure character grid
	if character_grid:
		character_grid.columns = grid_config.get("columns", 8)
		
		# Clear existing portraits
		for child in character_grid.get_children():
			child.queue_free()
		character_portraits.clear()
		
		# Create character portraits
		for character in characters:
			var portrait_button = _create_character_portrait(character)
			character_grid.add_child(portrait_button)
			character_portraits.append(portrait_button)
	
	print("Applied MUGEN select config to UI")

func _create_character_portrait(character_data: Dictionary) -> Button:
	var characterPortraitButton = preload("res://scripts/ui/character_portrait_button.gd")
	var button = characterPortraitButton.new(character_data)
	
	# Connect selection signal
	button.character_selected.connect(_on_character_portrait_selected)
	
	return button

func _on_character_portrait_selected(character_data: Dictionary):
	"""Handle character portrait selection with visual feedback"""
	print("🎯 Character portrait selected: %s" % character_data.get("name", "Unknown"))
	
	# Clear previous selections
	for portrait in character_portraits:
		if portrait.has_method("set_selected"):
			portrait.set_selected(false)
	
	# Set the selected button
	for portrait in character_portraits:
		if portrait.character_data.get("name") == character_data.get("name"):
			portrait.set_selected(true)
			break
	
	# Emit the selection signal
	character_selected.emit(character_data)

func _load_character_portrait(button: Button, character_data: Dictionary):
	"""Load and display character portrait on button"""
	var portrait_path = character_data.get("portrait", "")
	
	# If no portrait path, try to derive from def path
	if portrait_path.is_empty():
		var def_path = character_data.get("def_path", "")
		if not def_path.is_empty():
			var char_dir = def_path.get_base_dir()
			# Common portrait file patterns
			var possible_portraits = [
				char_dir + "/portrait.pcx",
				char_dir + "/face.pcx", 
				char_dir + "/" + character_data.name.to_lower() + ".pcx"
			]
			
			for path in possible_portraits:
				if FileAccess.file_exists(path):
					portrait_path = path
					break
	
	# Load portrait if path exists
	if not portrait_path.is_empty() and FileAccess.file_exists(portrait_path):
		_load_portrait_image(button, portrait_path)
	else:
		# Fallback to text-only button
		button.text = character_data.name

func _load_portrait_image(button: Button, portrait_path: String):
	"""Load portrait image from PCX file"""
	# Check cache first
	if portrait_cache.has(portrait_path):
		var texture = portrait_cache[portrait_path]
		if texture:
			button.icon = texture
			button.text = ""  # Remove text since we have image
		return
	
	# Load PCX file using existing parser
	var pcx_parser = preload("res://scripts/mugen/pcx_parser.gd").new()
	var image_data = pcx_parser.parse_file(portrait_path)
	
	if image_data and image_data.has("image"):
		var image = image_data.image
		var texture = ImageTexture.new()
		texture.set_image(image)
		
		# Cache the texture
		portrait_cache[portrait_path] = texture
		
		# Apply to button
		button.icon = texture
		button.text = ""  # Remove text since we have image
		
		print("Loaded portrait: ", portrait_path)
	else:
		print("Failed to load portrait: ", portrait_path)

func clear_portrait_cache():
	"""Clear cached portrait textures"""
	portrait_cache.clear()
	print("Portrait cache cleared")

func _on_character_selected(character_data: Dictionary):
	print("Character selected: ", character_data.name)
	emit_signal("character_selected", character_data)

func show_screen(screen_name: String):
	# Hide all screens
	if character_grid:
		character_grid.visible = false
	if health_bar_p1:
		health_bar_p1.visible = false
	if health_bar_p2:
		health_bar_p2.visible = false
	if timer_label:
		timer_label.visible = false
	if round_label:
		round_label.visible = false
	
	# Show requested screen
	match screen_name:
		"select":
			if character_grid:
				character_grid.visible = true
		"battle":
			if health_bar_p1:
				health_bar_p1.visible = true
			if health_bar_p2:
				health_bar_p2.visible = true
			if timer_label:
				timer_label.visible = true
			if round_label:
				round_label.visible = true
	
	current_screen = screen_name
	emit_signal("screen_changed", screen_name)

func update_health_bars(p1_health: float, p2_health: float):
	if health_bar_p1:
		health_bar_p1.value = p1_health * 100
	if health_bar_p2:
		health_bar_p2.value = p2_health * 100

func update_timer(time: int):
	if timer_label:
		timer_label.text = str(time)

func update_round(round_num: int):
	if round_label:
		round_label.text = "Round " + str(round_num)

# Get MUGEN configuration data
func get_system_config():
	return system_config

func get_select_config():
	return select_config

func get_available_characters() -> Array:
	if select_config:
		return select_config.get_characters()
	return []

func get_available_stages() -> Array:
	if select_config:
		return select_config.get_stages()
	return []
