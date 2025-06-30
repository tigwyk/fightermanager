extends Node2D
class_name BattleFighter

## Battle Fighter Node
## Represents a MUGEN character in battle with stats and interaction methods

var character_data
var player_number: int = 1

func initialize(char_data, player_num: int):
	"""Initialize the fighter with character data"""
	character_data = char_data
	player_number = player_num
	
	if character_data:
		name = "Fighter%d_%s" % [player_num, character_data.character_name]
	else:
		name = "Fighter%d_Placeholder" % player_num

func get_character_info() -> Dictionary:
	"""Get character information"""
	if character_data and character_data.has_method("get_character_info"):
		return character_data.get_character_info()
	else:
		# Return placeholder info
		var display_name = name
		if "_" in name:
			var parts = name.split("_")
			display_name = parts[-1]
		
		return {
			"display_name": display_name,
			"character_name": name,
			"author": "Unknown"
		}

func get_fighter_stats() -> Dictionary:
	"""Get fighter battle stats"""
	var stats_node = get_node_or_null("Stats")
	if stats_node:
		return stats_node.get_meta("stats", {})
	return {}

func take_damage(damage: int) -> int:
	"""Apply damage to fighter and return new health"""
	var stats_node = get_node_or_null("Stats")
	if stats_node:
		var current_health = stats_node.get_meta("current_health", 100)
		var defense = stats_node.get_meta("stats", {}).get("defense", 100)
		
		# Apply defense calculation (simple damage reduction)
		var damage_reduction = defense / 200.0  # Convert 100 defense = 50% reduction
		var actual_damage = max(1, damage * (1.0 - damage_reduction))
		
		var new_health = max(0, current_health - actual_damage)
		stats_node.set_meta("current_health", new_health)
		
		# Also update MUGEN life value
		var mugen_current_life = stats_node.get_meta("mugen_current_life", 1000)
		var mugen_max_life = stats_node.get_meta("mugen_max_life", 1000)
		var mugen_damage = (actual_damage / 100.0) * mugen_max_life
		var new_mugen_life = max(0, mugen_current_life - mugen_damage)
		stats_node.set_meta("mugen_current_life", new_mugen_life)
		
		print("💥 %s took %d damage (Defense: %d, Health: %d%%)" % [name, int(actual_damage), defense, new_health])
		return new_health
	return 100

func get_current_health() -> int:
	"""Get current health"""
	var stats_node = get_node_or_null("Stats")
	if stats_node:
		return stats_node.get_meta("current_health", 100)
	return 100

func is_defeated() -> bool:
	"""Check if fighter is defeated"""
	return get_current_health() <= 0

func play_animation(animation_name: String):
	"""Play a specific animation"""
	var anim_node = get_node_or_null("Animations")
	if anim_node:
		var animations = anim_node.get_meta("animations", {})
		if animation_name in animations:
			print("🎭 Playing animation: %s for %s" % [animation_name, name])
			# TODO: Implement actual animation playback
		else:
			print("⚠️ Animation not found: %s" % animation_name)

func set_facing_direction(facing_left: bool):
	"""Set fighter facing direction"""
	var sprite = get_child(0)  # First child should be sprite
	if sprite and sprite is Node2D:
		sprite.scale.x = -1 if facing_left else 1

func get_mugen_character():
	"""Get the underlying MUGEN character data"""
	return character_data

func get_sprite_component():
	"""Get the sprite component for direct manipulation"""
	return get_node_or_null("Sprite")

func change_animation(animation_name: String, force: bool = false):
	"""Change to a specific animation"""
	var anim_node = get_node_or_null("Animations")
	var sprite_node = get_sprite_component()
	
	if not anim_node or not sprite_node:
		return false
	
	var animations = anim_node.get_meta("animations", {})
	if not animation_name in animations:
		print("⚠️ Animation '%s' not found for %s" % [animation_name, name])
		return false
	
	var current_anim = anim_node.get_meta("current_animation", "")
	if current_anim == animation_name and not force:
		return true  # Already playing this animation
	
	# Set new animation
	anim_node.set_meta("current_animation", animation_name)
	anim_node.set_meta("current_frame", 0)
	anim_node.set_meta("animation_timer", 0.0)
	
	# Update sprite if possible
	_update_animation_sprite()
	
	print("🎭 %s changed to animation: %s" % [name, animation_name])
	return true

func _update_animation_sprite():
	"""Update sprite based on current animation frame"""
	var anim_node = get_node_or_null("Animations")
	var sprite_node = get_sprite_component()
	
	if not anim_node or not sprite_node:
		return
	
	var animations = anim_node.get_meta("animations", {})
	var current_anim = anim_node.get_meta("current_animation", "stance")
	var current_frame = anim_node.get_meta("current_frame", 0)
	var sprite_bundle = sprite_node.get_meta("sprite_bundle", null)
	
	if not current_anim in animations or not sprite_bundle:
		return
	
	var anim_data = animations[current_anim]
	var frames = anim_data.get("frames", [0])
	var group = anim_data.get("group", 0)
	
	if current_frame < frames.size():
		var image_id = frames[current_frame]
		var sprite_data = sprite_bundle.get_sprite([group, image_id])
		if not sprite_data.is_empty():
			var new_texture = sprite_bundle.create_texture(sprite_data)
			if new_texture:
				sprite_node.texture = new_texture

func update_animation(delta: float):
	"""Update animation state (call from _process)"""
	var anim_node = get_node_or_null("Animations")
	if not anim_node:
		return
	
	var anim_speed = anim_node.get_meta("animation_speed", 1.0)
	var anim_timer = anim_node.get_meta("animation_timer", 0.0)
	var current_anim = anim_node.get_meta("current_animation", "stance")
	var current_frame = anim_node.get_meta("current_frame", 0)
	
	# Update timer
	anim_timer += delta * anim_speed
	
	# Check if we should advance frame (rough timing)
	var frame_duration = 0.1  # 10 FPS default
	if anim_timer >= frame_duration:
		anim_timer = 0.0
		
		var animations = anim_node.get_meta("animations", {})
		if current_anim in animations:
			var frames = animations[current_anim].get("frames", [0])
			current_frame = (current_frame + 1) % frames.size()
			anim_node.set_meta("current_frame", current_frame)
			_update_animation_sprite()
	
	anim_node.set_meta("animation_timer", anim_timer)
