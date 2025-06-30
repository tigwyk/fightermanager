extends Control
class_name BattleSceneUI

## Battle Scene UI
## Handles the actual battle interface with MUGEN fighters

@onready var p1_name: Label = %P1Name
@onready var p1_health: ProgressBar = %P1Health
@onready var p2_name: Label = %P2Name
@onready var p2_health: ProgressBar = %P2Health
@onready var timer_label: Label = %Timer
@onready var round_label: Label = %Round
@onready var back_btn: Button = %BackButton
@onready var stage_bg: Sprite2D = %StageBackground
@onready var fighter1_spawn: Marker2D = %Fighter1Spawn
@onready var fighter2_spawn: Marker2D = %Fighter2Spawn

var battle_timer: float = 99.0
var current_round: int = 1
var fighter1: Node2D
var fighter2: Node2D

func _ready():
	print("⚔️ Battle Scene Ready")
	_connect_signals()
	_setup_battle()

func _connect_signals():
	"""Connect UI signals"""
	back_btn.pressed.connect(_on_back_pressed)

func _setup_battle():
	"""Setup the battle environment"""
	print("🥊 Setting up battle...")
	
	# Set fighter names (placeholder)
	p1_name.text = "Ryu"
	p2_name.text = "Chun-Li"
	
	# Reset health bars
	p1_health.value = 100
	p2_health.value = 100
	
	# Setup timer and round
	battle_timer = 99.0
	current_round = 1
	_update_timer_display()
	_update_round_display()
	
	# Load MUGEN fighters (placeholder)
	_load_fighters()

func _load_fighters():
	"""Load MUGEN fighters into the battle"""
	print("👥 Loading MUGEN fighters...")
	
	# Get MugenSystem for character loading
	var mugen_system = get_node_or_null("/root/MugenSystem")
	if not mugen_system:
		print("❌ MugenSystem not found, falling back to placeholders")
		_load_placeholder_fighters()
		return
	
	print("✅ MugenSystem found: %s" % mugen_system)
	
	var char_dirs = mugen_system.get_character_list()
	print("📂 Found %d character directories: %s" % [char_dirs.size(), char_dirs])
	
	if char_dirs.size() < 2:
		print("⚠️ Not enough characters found (%d), falling back to placeholders" % char_dirs.size())
		_load_placeholder_fighters()
		return
	
	# Select characters for battle (could be improved with character selection UI)
	var char1_path = _select_character(char_dirs, 1)
	var char2_path = _select_character(char_dirs, 2)
	
	print("🥊 Loading Fighter 1 from: %s" % char1_path.get_file())
	print("🥊 Loading Fighter 2 from: %s" % char2_path.get_file())
	
	# Create real MUGEN fighters
	fighter1 = _create_fighter(char1_path, mugen_system, 1)
	fighter2 = _create_fighter(char2_path, mugen_system, 2)
	
	if fighter1 and fighter2:
		# Position fighters
		add_child(fighter1)
		add_child(fighter2)
		fighter1.position = fighter1_spawn.position
		fighter2.position = fighter2_spawn.position
		
		# Update UI with real character names
		var char1_info = fighter1.get_character_info()
		var char2_info = fighter2.get_character_info()
		p1_name.text = char1_info.get("display_name", "Fighter 1")
		p2_name.text = char2_info.get("display_name", "Fighter 2")
		
		# Set initial animations
		if fighter1.has_method("change_animation"):
			fighter1.change_animation("stance")
		if fighter2.has_method("change_animation"):
			fighter2.change_animation("stance")
		
		print("✅ MUGEN fighters loaded successfully")
	else:
		print("❌ Failed to load MUGEN fighters, using placeholders")
		_load_placeholder_fighters()

func _select_character(char_dirs: Array, player_num: int) -> String:
	"""Select a character for the specified player"""
	# For now, use simple selection logic
	# This could be enhanced with proper character selection UI
	
	if player_num == 1:
		# Player 1 gets first character, or a specific preference
		for char_path in char_dirs:
			var char_name = char_path.get_file().to_lower()
			# Prefer common fighting game characters if available
			if "kfm" in char_name or "ryu" in char_name or "kung" in char_name:
				return char_path
		return char_dirs[0]  # Fallback to first
	else:
		# Player 2 gets second character, or different preference
		for char_path in char_dirs:
			var char_name = char_path.get_file().to_lower()
			# Prefer different characters for variety
			if "chun" in char_name or "ken" in char_name or "mai" in char_name:
				return char_path
		# Ensure different character than player 1
		return char_dirs[1] if char_dirs.size() > 1 else char_dirs[0]

func _load_placeholder_fighters():
	"""Fallback to placeholder fighters if MUGEN loading fails"""
	print("📦 Loading placeholder fighters...")
	
	# Create placeholder fighters
	fighter1 = _create_placeholder_fighter("Ryu", Color.BLUE)
	fighter2 = _create_placeholder_fighter("Chun-Li", Color.RED)
	
	# Position fighters
	add_child(fighter1)
	add_child(fighter2)
	fighter1.position = fighter1_spawn.position
	fighter2.position = fighter2_spawn.position
	
	print("✅ Placeholder fighters loaded")

func _create_placeholder_fighter(fighter_name: String, color: Color) -> Node2D:
	"""Create a placeholder fighter node"""
	var fighter = Node2D.new()
	fighter.name = fighter_name
	
	# Add visual representation
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(64, 96, false, Image.FORMAT_RGB8)
	image.fill(color)
	texture.set_image(image)
	sprite.texture = texture
	fighter.add_child(sprite)
	
	# Add a simple label
	var label = Label.new()
	label.text = fighter_name
	label.position = Vector2(-20, -60)
	var label_settings = LabelSettings.new()
	label_settings.font_size = 16
	label_settings.font_color = Color("Yellow")
	label.label_settings = label_settings
	fighter.add_child(label)
	
	return fighter

func _process(delta):
	"""Update battle state"""
	if battle_timer > 0:
		battle_timer -= delta
		_update_timer_display()
		
		# Update health bars from fighter data
		_update_health_displays()
		
		# Update fighter animations
		_update_fighter_animations(delta)
		
		# Simple battle simulation (placeholder)
		_simulate_battle_action(delta)
		
		if battle_timer <= 0:
			_end_round("Time Up!")
		
		# Check for KO
		if fighter1 and fighter1.has_method("is_defeated") and fighter1.is_defeated():
			_end_round("Player 2 Wins!")
		elif fighter2 and fighter2.has_method("is_defeated") and fighter2.is_defeated():
			_end_round("Player 1 Wins!")

func _update_fighter_animations(delta: float):
	"""Update fighter animations"""
	if fighter1 and fighter1.has_method("update_animation"):
		fighter1.update_animation(delta)
	
	if fighter2 and fighter2.has_method("update_animation"):
		fighter2.update_animation(delta)

func _update_health_displays():
	"""Update health bars based on fighter health"""
	if fighter1 and fighter1.has_method("get_current_health"):
		var health = fighter1.get_current_health()
		p1_health.value = health
	
	if fighter2 and fighter2.has_method("get_current_health"):
		var health = fighter2.get_current_health()
		p2_health.value = health

func _simulate_battle_action(delta: float):
	"""Simple battle simulation for demonstration"""
	# Every few seconds, simulate some combat
	if fmod(battle_timer, 3.0) < delta:  # Every 3 seconds
		if fighter1 and fighter2 and fighter1.has_method("take_damage") and fighter2.has_method("take_damage"):
			# Simulate random combat
			if randf() < 0.5:
				fighter2.take_damage(randi_range(5, 15))
				print("🥊 Player 1 attacks Player 2!")
			else:
				fighter1.take_damage(randi_range(5, 15))
				print("🥊 Player 2 attacks Player 1!")

func _update_timer_display():
	"""Update the timer display"""
	timer_label.text = str(max(0, int(battle_timer)))

func _update_round_display():
	"""Update the round display"""
	round_label.text = "Round %d" % current_round

func _end_round(reason: String):
	"""End the current round"""
	print("🏁 Round ended: %s" % reason)
	
	# TODO: Implement round ending logic
	# - Determine winner
	# - Update scores
	# - Start next round or end match
	
	var dialog = AcceptDialog.new()
	dialog.title = "Round Complete"
	dialog.dialog_text = "Round %d completed!\n\nReason: %s\n\n(Battle system coming soon!)" % [current_round, reason]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_back_pressed():
	"""Return to main menu"""
	print("🏠 Returning to main menu")
	var main_menu = load("res://scenes/core/main_menu.tscn")
	if main_menu:
		get_tree().change_scene_to_packed(main_menu)

func _input(event):
	"""Handle input for battle controls"""
	if event.is_action_pressed("ui_cancel"):
		_show_pause_menu()
	
	# Add test controls for battle system
	if event.is_action_pressed("ui_accept"):  # Space/Enter
		_test_attack()
	
	if event.is_action_pressed("ui_select"):  # Shift
		_test_special_move()
	
	# Debug: Show character info
	if event.is_action_pressed("ui_text_completion_query"):  # Tab key
		_show_character_debug_info()

func _show_character_debug_info():
	"""Show debug information about loaded characters"""
	var info_text = "🎮 BATTLE DEBUG INFO 🎮\n\n"
	
	if fighter1:
		var char1_info = fighter1.get_character_info()
		var char1_stats = fighter1.get_fighter_stats()
		info_text += "PLAYER 1:\n"
		info_text += "  Name: %s\n" % char1_info.get("display_name", "Unknown")
		info_text += "  Author: %s\n" % char1_info.get("author", "Unknown")
		info_text += "  Health: %d/%d\n" % [fighter1.get_current_health(), 100]
		info_text += "  Power: %d\n" % char1_stats.get("power", 100)
		info_text += "  Defense: %d\n" % char1_stats.get("defense", 100)
		info_text += "  Speed: %d\n\n" % char1_stats.get("speed", 100)
	
	if fighter2:
		var char2_info = fighter2.get_character_info()
		var char2_stats = fighter2.get_fighter_stats()
		info_text += "PLAYER 2:\n"
		info_text += "  Name: %s\n" % char2_info.get("display_name", "Unknown")
		info_text += "  Author: %s\n" % char2_info.get("author", "Unknown")
		info_text += "  Health: %d/%d\n" % [fighter2.get_current_health(), 100]
		info_text += "  Power: %d\n" % char2_stats.get("power", 100)
		info_text += "  Defense: %d\n" % char2_stats.get("defense", 100)
		info_text += "  Speed: %d\n\n" % char2_stats.get("speed", 100)
	
	info_text += "CONTROLS:\n"
	info_text += "  Enter/Space: Player 1 Attack\n"
	info_text += "  Shift: Player 1 Special\n"
	info_text += "  Tab: Show this info\n"
	info_text += "  Escape: Pause menu"
	
	var dialog = AcceptDialog.new()
	dialog.title = "Character Debug Info"
	dialog.dialog_text = info_text
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _test_attack():
	"""Test basic attack functionality"""
	if fighter1 and fighter2 and fighter2.has_method("take_damage"):
		fighter2.take_damage(10)
		print("🔥 Player 1 basic attack!")
		
		# Play attack animation
		if fighter1.has_method("change_animation"):
			fighter1.change_animation("attack")
		
		# Return to stance after a delay
		get_tree().create_timer(0.5).timeout.connect(func():
			if fighter1 and fighter1.has_method("change_animation"):
				fighter1.change_animation("stance")
		)

func _test_special_move():
	"""Test special move functionality"""
	if fighter1 and fighter2 and fighter2.has_method("take_damage"):
		fighter2.take_damage(20)
		print("⚡ Player 1 special attack!")
		
		# Play special animation if available
		if fighter1 and fighter1.has_method("change_animation"):
			var success = fighter1.change_animation("special")
			if not success:
				# Fallback to attack animation
				fighter1.change_animation("attack")
		
		# Return to stance after a delay
		get_tree().create_timer(1.0).timeout.connect(func():
			if fighter1 and fighter1.has_method("change_animation"):
				fighter1.change_animation("stance")
		)

func _show_pause_menu():
	"""Show battle pause menu"""
	var dialog = ConfirmationDialog.new()
	dialog.title = "Pause Menu"
	dialog.dialog_text = "Battle paused\n\nReturn to main menu?"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(_on_back_pressed)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

func _create_fighter(char_path: String, mugen_system, player_num: int):
	"""Create a real MUGEN fighter from character data"""
	print("🔄 Creating fighter %d from: %s" % [player_num, char_path.get_file()])
	
	# Load character data
	var character = mugen_system.load_character(char_path)
	if not character:
		print("❌ Failed to load character data for: %s" % char_path.get_file())
		_show_loading_error("Failed to load character: %s" % char_path.get_file())
		return null
	
	print("✅ Character data loaded: %s" % character)
	
	# Verify character data integrity
	if not _validate_character_data(character):
		print("❌ Invalid character data for: %s" % char_path.get_file())
		_show_loading_error("Invalid character data: %s" % char_path.get_file())
		return null
	
	# Create fighter node with BattleFighter script
	var battle_fighter_script = load("res://scripts/ui/battle_fighter.gd")
	if not battle_fighter_script:
		print("❌ BattleFighter script not found")
		return null
	
	var fighter = battle_fighter_script.new()
	fighter.initialize(character, player_num)
	print("✅ Fighter node created: %s" % fighter)
	
	# Create visual representation using MUGEN sprites
	var sprite_component = _create_fighter_sprite(character, player_num)
	if sprite_component:
		fighter.add_child(sprite_component)
		print("✅ Loaded MUGEN sprite for: %s" % character.character_name)
	else:
		# Fallback to placeholder if sprite loading fails
		print("⚠️ Sprite loading failed, using placeholder for %s" % character.character_name)
		var fallback_sprite = _create_fallback_sprite(character, player_num)
		fighter.add_child(fallback_sprite)
	
	# Add character name label with character info
	var char_info = character.get_character_info()
	var name_label = Label.new()
	name_label.text = char_info.get("display_name", character.character_name)
	name_label.position = Vector2(-30, -80)
	var label_settings = LabelSettings.new()
	label_settings.font_size = 14
	label_settings.font_color = Color("Yellow")
	label_settings.outline_color = Color("Black")
	label_settings.outline_size = 2
	name_label.label_settings = label_settings
	fighter.add_child(name_label)
	
	# Add basic fighter stats for battle simulation
	var stats_component = _create_fighter_stats(character)
	fighter.add_child(stats_component)
	
	# Add animation component for MUGEN animations
	var animation_component = _create_fighter_animation(character)
	if animation_component:
		fighter.add_child(animation_component)
	
	# Add hitbox component for collision detection
	var hitbox_component = _create_fighter_hitbox(character, player_num)
	fighter.add_child(hitbox_component)
	
	print("✅ Created MUGEN fighter: %s (Author: %s)" % [
		char_info.get("display_name", "Unknown"),
		char_info.get("author", "Unknown")
	])
	return fighter

func _create_fighter_sprite(character, player_num: int):
	"""Create sprite component using MUGEN sprite data"""
	print("🎨 Creating sprite for: %s" % character.character_name)
	
	# Try to get a stance/idle sprite from the character
	var sprite_bundle = character.sprite_bundle
	if not sprite_bundle:
		print("❌ No sprite bundle available for: %s" % character.character_name)
		return null
	
	# Create a simple Sprite2D for now (we can upgrade to MugenAnimationSprite later)
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	
	# Try multiple stance/idle sprite possibilities
	var stance_texture = null
	var stance_candidates = [
		[0, 0],    # Standard stance
		[1, 0],    # Alternative stance
		[5, 0],    # Walking frame
		[10, 0],   # Another common stance group
		[100, 0]   # Some characters use group 100
	]
	
	for candidate in stance_candidates:
		var sprite_data = sprite_bundle.get_sprite(candidate)
		if not sprite_data.is_empty():
			stance_texture = sprite_bundle.create_texture(sprite_data)
			if stance_texture:
				print("✅ Found stance sprite at group %d, image %d" % [candidate[0], candidate[1]])
				break
	
	if stance_texture:
		sprite.texture = stance_texture
		
		# Store sprite info for animation system
		sprite.set_meta("current_group", stance_candidates[0][0])
		sprite.set_meta("current_image", stance_candidates[0][1])
		sprite.set_meta("sprite_bundle", sprite_bundle)
		
		print("✅ Loaded stance sprite for: %s" % character.character_name)
	else:
		print("⚠️ No stance sprite found for: %s, trying first available sprite" % character.character_name)
		# Try to get any available sprite
		var first_sprite = _get_first_available_sprite(sprite_bundle)
		if first_sprite:
			sprite.texture = first_sprite
			sprite.set_meta("sprite_bundle", sprite_bundle)
		else:
			print("❌ No sprites available at all for: %s" % character.character_name)
			return null
	
	# Set facing direction based on player number
	if player_num == 2:
		sprite.scale.x = -1  # Flip player 2 to face left
	
	return sprite

func _create_fallback_sprite(_character, player_num: int) -> Sprite2D:
	"""Create fallback sprite if MUGEN sprites fail to load"""
	var sprite = Sprite2D.new()
	var texture = ImageTexture.new()
	var image = Image.create(64, 96, false, Image.FORMAT_RGB8)
	
	# Use different colors for different players
	var color = Color.BLUE if player_num == 1 else Color.RED
	image.fill(color)
	texture.set_image(image)
	sprite.texture = texture
	
	# Flip player 2
	if player_num == 2:
		sprite.scale.x = -1
	
	return sprite

func _create_fighter_stats(character) -> Node:
	"""Create stats component for battle simulation"""
	var stats_node = Node.new()
	stats_node.name = "Stats"
	
	# Get character info for additional stats
	var char_info = character.get_character_info()
	
	# Copy character stats for battle use, with intelligent defaults
	var battle_stats = character.stats.duplicate()
	
	# Ensure all essential stats exist
	var default_stats = {
		"power": 100,
		"defense": 100,
		"speed": 100,
		"technique": 100,
		"range": 100,
		"life": 1000,  # Default MUGEN life value
		"attack": 100,
		"defence": 100  # MUGEN uses 'defence' spelling
	}
	
	for stat_name in default_stats:
		if not battle_stats.has(stat_name):
			battle_stats[stat_name] = default_stats[stat_name]
	
	# Calculate max health based on life stat or use default
	var max_health = battle_stats.get("life", 1000)
	if max_health > 2000:  # Cap unreasonably high health
		max_health = 1000
	elif max_health < 100:  # Ensure minimum health
		max_health = 500
	
	# Scale health for UI display (MUGEN uses 1000+, we want 0-100 for progress bars)
	var display_health = 100
	
	stats_node.set_meta("stats", battle_stats)
	stats_node.set_meta("max_health", display_health)
	stats_node.set_meta("current_health", display_health)
	stats_node.set_meta("mugen_max_life", max_health)
	stats_node.set_meta("mugen_current_life", max_health)
	
	# Store character info for reference
	stats_node.set_meta("character_info", char_info)
	
	print("📊 Fighter stats loaded:")
	print("  - Power: %d" % battle_stats.get("power", 100))
	print("  - Defense: %d" % battle_stats.get("defense", 100))
	print("  - Speed: %d" % battle_stats.get("speed", 100))
	print("  - Life: %d" % max_health)
	
	return stats_node

func _create_fighter_animation(character):
	"""Create animation component for MUGEN character animations"""
	var anim_node = Node.new()
	anim_node.name = "Animations"
	
	# Store animation data from character
	if character.animations.is_empty():
		print("⚠️ No animations available for: %s" % character.character_name)
		# Create basic animation placeholders
		var basic_animations = {
			"stance": {"group": 0, "frames": [0]},
			"walk": {"group": 5, "frames": [0, 1, 2, 3]},
			"attack": {"group": 200, "frames": [0, 1, 2]},
			"hurt": {"group": 5000, "frames": [0, 1]},
			"victory": {"group": 180, "frames": [0]}
		}
		anim_node.set_meta("animations", basic_animations)
	else:
		anim_node.set_meta("animations", character.animations)
		print("🎭 Loaded %d animations for: %s" % [character.animations.size(), character.character_name])
	
	# Store current animation state
	anim_node.set_meta("current_animation", "stance")
	anim_node.set_meta("current_frame", 0)
	anim_node.set_meta("animation_speed", 1.0)
	anim_node.set_meta("animation_timer", 0.0)
	
	return anim_node

func _validate_character_data(character) -> bool:
	"""Validate that character data is properly loaded"""
	if not character:
		return false
		
	# Check essential character data
	if character.character_name.is_empty():
		print("❌ Character has no name")
		return false
		
	# Check if we have basic stats
	if character.stats.is_empty():
		print("⚠️ Character has no stats, using defaults")
		character.stats = {
			"power": 100,
			"defense": 100,
			"speed": 100,
			"technique": 100,
			"range": 100
		}
	
	print("✅ Character data validation passed for: %s" % character.character_name)
	return true

func _show_loading_error(message: String):
	"""Show error dialog for character loading failures"""
	var dialog = AcceptDialog.new()
	dialog.title = "Character Loading Error"
	dialog.dialog_text = message + "\n\nFalling back to placeholder fighters."
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _create_fighter_hitbox(character, player_num: int) -> Area2D:
	"""Create hitbox component for collision detection"""
	var hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	
	# Create collision shape based on character size
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# Use character dimensions or default
	var char_size = Vector2(60, 90)  # Default fighter size
	if character.local_coord != Vector2i.ZERO:
		char_size = Vector2(character.local_coord) * 0.2  # Scale down for hitbox
	
	shape.size = char_size
	collision_shape.shape = shape
	hitbox.add_child(collision_shape)
	
	# Set collision layers based on player number
	hitbox.collision_layer = 1 << (player_num - 1)  # Layer 1 for P1, Layer 2 for P2
	hitbox.collision_mask = 0  # Don't detect collisions by default
	
	print("🎯 Created hitbox for player %d: %s" % [player_num, char_size])
	return hitbox

func _get_first_available_sprite(sprite_bundle):
	"""Get the first available sprite from the bundle"""
	if not sprite_bundle:
		return null
	
	# Find first sprite in any group
	for group_id in range(0, 200):  # Search first 200 groups
		for image_id in range(0, 20):  # Search first 20 images per group
			var sprite_data = sprite_bundle.get_sprite([group_id, image_id])
			if not sprite_data.is_empty():
				var texture = sprite_bundle.create_texture(sprite_data)
				if texture:
					print("🎨 Found first available sprite at group %d, image %d" % [group_id, image_id])
					return texture
	
	return null
