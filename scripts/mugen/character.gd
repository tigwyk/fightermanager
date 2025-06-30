extends Node2D
class_name Character

## Basic MUGEN-style Character Node with AIR animation support

# State machine
enum State { IDLE, WALK, JUMP }
var state: State = State.IDLE
var facing: int = 1 # 1 = right, -1 = left
var velocity: Vector2 = Vector2.ZERO

# Animation
var sff_parser: SFFParser
var air_parser: AIRParser
var current_anim: int = 0
var current_frame: int = 0
var frame_time: float = 0.0
var sprite: Sprite2D

var input_left: String = "ui_left"
var input_right: String = "ui_right"
var input_jump: String = "ui_up"

var cmd_parser: CMDParser
var cns_parser # CNSParser - using generic type to avoid forward reference issues

var input_buffer: Array = []
var buffer_size: int = 20
var buffer_timer: float = 0.0
var buffer_time_max: float = 0.25 # seconds per input

# Hitbox and hurtbox
var hitbox_areas: Array = [] # Area2D nodes for hitboxes
var hurtbox_areas: Array = [] # Area2D nodes for hurtboxes

# AI support
var is_ai: bool = false
var ai_level: int = 4 # 0 (off) to 8 (max), like MUGEN
# AI triggers parsed from CNS (to be set by CNS parser)
var ai_triggers: Array = [] # Each entry: {state, triggers: [ {condition, action} ]}

# Character stats and status
var max_health: int = 1000
var current_health: int = 1000
var is_in_hitstun: bool = false
var hitstun_timer: float = 0.0

# Character data reference
var character_data # MugenCharacterData reference

func _ready():
	sprite = Sprite2D.new()
	add_child(sprite)
	# Placeholder: load SFF/AIR here or via method

	# Create hitbox/hurtbox containers
	for i in range(4): # Support up to 4 hitboxes/hurtboxes per frame (adjust as needed)
		var hit_area = Area2D.new()
		var hit_shape = CollisionShape2D.new()
		hit_area.add_child(hit_shape)
		hit_area.set_collision_layer_value(1, true)
		hit_area.set_collision_mask_value(1, false)
		hit_area.visible = false
		add_child(hit_area)
		hitbox_areas.append(hit_area)
		var hurt_area = Area2D.new()
		var hurt_shape = CollisionShape2D.new()
		hurt_area.add_child(hurt_shape)
		hurt_area.set_collision_layer_value(2, true)
		hurt_area.set_collision_mask_value(2, false)
		hurt_area.visible = false
		add_child(hurt_area)
		hurtbox_areas.append(hurt_area)

func set_sff_parser(parser: SFFParser):
	sff_parser = parser
	_update_sprite()

func set_air_parser(parser: AIRParser):
	air_parser = parser

func set_cmd_parser(parser: CMDParser):
	cmd_parser = parser

func set_cns_parser(parser):
	cns_parser = parser
	# Automatically set AI triggers from the CNS parser
	if parser:
		ai_triggers = parser.get_ai_triggers()

func set_ai_triggers(triggers: Array):
	ai_triggers = triggers

func play_anim(anim_no: int):
	current_anim = anim_no
	current_frame = 0
	frame_time = 0.0
	_update_sprite()

func _update_sprite():
	if sff_parser and air_parser:
		var anim = air_parser.get_animation(current_anim)
		if anim.size() > 0 and current_frame < anim.size():
			var frame = anim[current_frame]
			var tex = sff_parser.get_sprite_texture(frame.group, frame.image)
			if tex:
				sprite.texture = tex
				sprite.flip_h = facing == -1 or frame.flip
				sprite.position = frame.offset
				sprite.visible = true
			else:
				# Instead of setting to null, hide the sprite to avoid the error
				print("⚠️ No texture found for sprite %d,%d in character %s - hiding sprite" % [frame.group, frame.image, name])
				sprite.visible = false
			# Update hitboxes/hurtboxes for this frame
			_update_hitboxes(frame)
	else:
		# fallback: hide sprite instead of setting texture to null
		sprite.visible = false
		_update_hitboxes(null)

func _physics_process(delta):
	# Input handling
	var move = 0
	if Input.is_action_pressed(input_left):
		move -= 1
	if Input.is_action_pressed(input_right):
		move += 1
	if move != 0:
		facing = move
		state = State.WALK
	else:
		state = State.IDLE
	if Input.is_action_just_pressed(input_jump):
		state = State.JUMP
		velocity.y = -200 # jump impulse

	# Basic state machine
	match state:
		State.IDLE:
			velocity.x = 0
			play_anim(0) # Placeholder: idle anim
		State.WALK:
			velocity.x = 100 * facing
			play_anim(1) # Placeholder: walk anim
		State.JUMP:
			velocity.y += 10 * delta # gravity
			play_anim(2) # Placeholder: jump anim
	# Move
	position += velocity * delta
	# AIR animation update
	if air_parser:
		var anim = air_parser.get_animation(current_anim)
		if anim.size() > 0 and current_frame < anim.size():
			var frame = anim[current_frame]
			frame_time += delta * 60.0 # MUGEN ticks
			if frame_time >= frame.duration:
				frame_time = 0.0
				current_frame += 1
				if current_frame >= anim.size():
					current_frame = 0 # loop
				_update_sprite()

	# Input buffering
	buffer_timer += delta
	if buffer_timer >= buffer_time_max:
		buffer_timer = 0.0
		var input = _get_input_state()
		if input != "":
			input_buffer.append(input)
			if input_buffer.size() > buffer_size:
				input_buffer.pop_front()
	# Command recognition
	if cmd_parser:
		for cmd in cmd_parser.get_commands():
			if _buffer_matches(cmd.input):
				# Recognized command, trigger state/animation
				var state_no = _get_state_for_command(cmd.name)
				if state_no != null:
					print("Special move triggered: ", cmd.name, " (state ", state_no, ")")
					# Set state and play corresponding animation (AIR anim number = state_no for now)
					state = state_no
					play_anim(state_no)
					input_buffer.clear()
					break

	# AI logic
	if is_ai:
		_process_ai(delta)

	# Update hitbox/hurtbox positions (centered on character for now)
	# (Obsolete: handled by _update_hitboxes now)
	# hitbox.position = Vector2.ZERO
	# hurtbox.position = Vector2.ZERO

func _update_hitboxes(frame):
	# Hide all by default
	for area in hitbox_areas:
		area.visible = false
	for area in hurtbox_areas:
		area.visible = false
	if frame == null:
		return
	# Example: frame.hitboxes and frame.hurtboxes are arrays of Rect2 (or similar)
	if frame.has("hitboxes"):
		for i in range(min(frame.hitboxes.size(), hitbox_areas.size())):
			var rect = frame.hitboxes[i]
			var area = hitbox_areas[i]
			var shape = area.get_child(0)
			if shape is CollisionShape2D:
				shape.shape = RectangleShape2D.new()
				shape.shape.extents = rect.size / 2.0
				area.position = rect.position + rect.size / 2.0
				area.visible = true
	if frame.has("hurtboxes"):
		for i in range(min(frame.hurtboxes.size(), hurtbox_areas.size())):
			var rect = frame.hurtboxes[i]
			var area = hurtbox_areas[i]
			var shape = area.get_child(0)
			if shape is CollisionShape2D:
				shape.shape = RectangleShape2D.new()
				shape.shape.extents = rect.size / 2.0
				area.position = rect.position + rect.size / 2.0
				area.visible = true

func get_current_hitboxes() -> Array:
	# Returns world-space Rect2 for each visible hitbox
	var rects = []
	for area in hitbox_areas:
		if area.visible and area.get_child_count() > 0:
			var shape = area.get_child(0)
			if shape is CollisionShape2D and shape.shape is RectangleShape2D:
				var ext = shape.shape.extents
				var pos = area.global_position - ext
				rects.append(Rect2(pos, ext * 2.0))
	return rects

func get_current_hurtboxes() -> Array:
	# Returns world-space Rect2 for each visible hurtbox
	var rects = []
	for area in hurtbox_areas:
		if area.visible and area.get_child_count() > 0:
			var shape = area.get_child(0)
			if shape is CollisionShape2D and shape.shape is RectangleShape2D:
				var ext = shape.shape.extents
				var pos = area.global_position - ext
				rects.append(Rect2(pos, ext * 2.0))
	return rects

func take_damage(damage: int, knockback: Vector2 = Vector2.ZERO):
	current_health -= damage
	current_health = max(current_health, 0)
	
	# Apply knockback
	velocity += knockback
	
	# Enter hitstun
	is_in_hitstun = true
	hitstun_timer = 0.3  # 300ms hitstun
	
	print("Character took ", damage, " damage. Health: ", current_health, "/", max_health)

func heal(amount: int):
	current_health += amount
	current_health = min(current_health, max_health)

func get_health_percent() -> float:
	return float(current_health) / float(max_health)

func is_ko() -> bool:
	return current_health <= 0

func reset_health():
	current_health = max_health

func _get_input_state() -> String:
	# Map Godot input to MUGEN directions/buttons (simplified)
	var dir = ""
	if Input.is_action_pressed(input_left):
		dir += "L"
	if Input.is_action_pressed(input_right):
		dir += "R"
	if Input.is_action_pressed(input_jump):
		dir += "U"
	# Add more directions/buttons as needed
	if Input.is_action_pressed("attack_x"):
		dir += "x"
	if Input.is_action_pressed("attack_y"):
		dir += "y"
	if Input.is_action_pressed("attack_z"):
		dir += "z"
	return dir

func _buffer_matches(cmd_input: Array) -> bool:
	# Check if the end of the buffer matches the command input sequence
	if cmd_input.size() == 0 or input_buffer.size() < cmd_input.size():
		return false
	for i in range(cmd_input.size()):
		if input_buffer[input_buffer.size() - cmd_input.size() + i] != cmd_input[i].strip_edges():
			return false
	return true

func _get_state_for_command(cmd_name: String):
	if cmd_parser:
		for sc in cmd_parser.get_state_cmds():
			if sc.command == cmd_name:
				return sc.state
	return null

func _process_ai(_delta):
	# Evaluate AI triggers for the current state
	for entry in ai_triggers:
		if entry.has("state") and entry.state == state:
			for trig in entry.triggers:
				if _evaluate_ai_condition(trig.condition):
					_execute_ai_action(trig.action)
					break # Only one action per frame for now
	# Placeholder: In the future, parse and evaluate AI triggers from CNS/CMD
	# For now, just a stub for CPU logic
	# Example: simulate random jump or attack
	# if randi() % 100 < ai_level * 2:
	# 	velocity.y = -200
	pass

func _evaluate_ai_condition(cond):
	# Enhanced condition evaluation supporting more MUGEN triggers
	if typeof(cond) == TYPE_STRING:
		# AILevel conditions
		if cond.find("AILevel") != -1:
			if cond.find(">") != -1:
				var val = int(cond.get_slice(">", 1).strip_edges())
				return ai_level > val
			elif cond.find(">=") != -1:
				var val = int(cond.get_slice(">=", 1).strip_edges())
				return ai_level >= val
			elif cond.find("=") != -1:
				var val = int(cond.get_slice("=", 1).strip_edges())
				return ai_level == val
		
		# Random conditions
		if cond.find("Random") != -1:
			if cond.find("<") != -1:
				var val = int(cond.get_slice("<", 1).strip_edges())
				return randi() % 1000 < val
		
		# Distance conditions (placeholder - would need opponent reference)
		if cond.find("P2Dist") != -1:
			# Simplified: assume close if no opponent data
			return true
	
	return false

func _execute_ai_action(action):
	# Enhanced action execution supporting CNS controller actions
	if action.begins_with("change_state:"):
		var new_state = int(action.get_slice(":", 1))
		# Note: In a full implementation, you'd need to handle custom states beyond the basic enum
		# For now, just play the animation
		play_anim(new_state)
	elif action.begins_with("set_vel_x:"):
		var vel_x = float(action.get_slice(":", 1))
		velocity.x = vel_x
	elif action.begins_with("set_vel_y:"):
		var vel_y = float(action.get_slice(":", 1))
		velocity.y = vel_y
	elif action == "press_jump":
		velocity.y = -200
	elif action == "press_attack_x":
		input_buffer.append("x")
	elif action == "press_attack_y":
		input_buffer.append("y")
	elif action == "press_attack_z":
		input_buffer.append("z")
	elif action.begins_with("controller:"):
		# Generic controller execution (placeholder)
		var controller_type = action.get_slice(":", 1)
		print("AI executing controller: ", controller_type)
	# Add more action types as needed

func load_from_character_data(data) -> bool:
	"""Load character from MugenCharacterData container"""
	if not data or not data.is_loaded:
		print("Error: Character data not loaded or invalid")
		return false
	
	# Store reference
	character_data = data
	
	# Setup parsers from character data
	sff_parser = data.get_sprite_parser()
	air_parser = data.get_animation_parser()
	cmd_parser = data.get_command_parser()
	cns_parser = data.get_cns_parser()
	
	# Set character properties
	max_health = data.get_health()
	current_health = max_health
	name = data.get_display_name()
	
	# Load AI triggers if available
	if data.has_ai():
		ai_triggers = data.get_ai_triggers()
		print("Loaded ", ai_triggers.size(), " AI triggers for ", name)
	
	# Initialize sprite if SFF is available
	if data.has_sprites():
		_initialize_sprite_from_data()
	
	# Set default animation if AIR is available
	if data.has_animations():
		play_anim(0)  # Default idle animation
	
	print("Character loaded from data: ", name)
	return true

func _initialize_sprite_from_data():
	"""Initialize sprite node from character data"""
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "CharacterSprite"
		add_child(sprite)
	
	# Set initial sprite (group 0, image 0)
	if sff_parser:
		var texture = sff_parser.get_sprite_texture(0, 0)
		if texture:
			sprite.texture = texture

func get_character_data():
	"""Get the character data container"""
	return character_data

func get_character_name() -> String:
	"""Get the character's display name"""
	if character_data:
		return character_data.get_display_name()
	return name

func get_character_info() -> Dictionary:
	"""Get character info from data container"""
	if character_data:
		return character_data.get_character_info()
	return {}
